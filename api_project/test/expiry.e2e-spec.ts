import type { AuthSession } from '../src/auth/auth.service.js';
import { ExpiryJob } from '../src/jobs/expiry.job.js';
import { createOnline, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

const day = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString().slice(0, 10);

describe('Expiration automatique des annonces', () => {
  let t: TestApp;
  let job: ExpiryJob;
  let phone = 709_900_000;
  const nextPhone = () => `0${++phone}`;

  beforeAll(async () => {
    t = await bootTestApp();
    job = t.app.get(ExpiryJob);
  });
  afterAll(async () => {
    await t.app.close();
  });

  const setUntil = (id: string, until: string) => t.ds.query(`UPDATE listings SET published_until = $2 WHERE id = $1`, [id, until]);
  const notifs = async (s: AuthSession) =>
    (await t.http().get('/v1/me/notifications').set(bearer(s)).expect(200)).body.data.map((n: { type: string }) => n.type);
  const statusOf = async (s: AuthSession, id: string) => (await t.http().get(`/v1/me/listings/${id}`).set(bearer(s)).expect(200)).body.status;

  it('expires a listing past its end date, once, and refuses its pending requests', async () => {
    const seller = await sellerSession(t, nextPhone());
    const id = await createOnline(t, seller);
    const buyer = await loginAs(t, nextPhone());
    const req = (await t.http().post('/v1/requests').set(bearer(buyer)).send({ listingId: id, offerType: 'monthly' }).expect(201)).body;
    await setUntil(id, day(-1));

    await job.run();
    expect(await statusOf(seller, id)).toBe('expired');
    expect((await notifs(seller)).filter((n: string) => n === 'listing_expired')).toHaveLength(1);
    const mine = (await t.http().get('/v1/me/requests').set(bearer(buyer)).expect(200)).body.data;
    expect(mine.find((r: { id: string }) => r.id === req.id)).toMatchObject({ status: 'refused', refusalReason: 'listing_unavailable' });

    await job.run();
    expect((await notifs(seller)).filter((n: string) => n === 'listing_expired')).toHaveLength(1);
  });

  it('keeps a listing online through its last day', async () => {
    const seller = await sellerSession(t, nextPhone());
    const id = await createOnline(t, seller);
    await setUntil(id, day(0));
    await job.run();
    expect(await statusOf(seller, id)).toBe('online');
  });

  it('reminds the seller once, three days before the end', async () => {
    const seller = await sellerSession(t, nextPhone());
    const id = await createOnline(t, seller);
    await setUntil(id, day(2));
    await job.run();
    await job.run();
    expect((await notifs(seller)).filter((n: string) => n === 'listing_expiring_soon')).toHaveLength(1);
    expect(await statusOf(seller, id)).toBe('online');
  });

  it('never expires a permanent listing', async () => {
    const seller = await sellerSession(t, nextPhone());
    const id = await createOnline(t, seller);
    await job.run();
    expect(await statusOf(seller, id)).toBe('online');
    expect(await notifs(seller)).toEqual([]);
  });

  it('notifies exactly once when two runs overlap', async () => {
    const seller = await sellerSession(t, nextPhone());
    const id = await createOnline(t, seller);
    await setUntil(id, day(-3));
    const results = await Promise.all([job.run(), job.run()]);
    expect(results.reduce((sum, r) => sum + r.expired, 0)).toBe(1);
    expect((await notifs(seller)).filter((n: string) => n === 'listing_expired')).toHaveLength(1);
  });

  it('reminds again after the seller reactivates the listing', async () => {
    const seller = await sellerSession(t, nextPhone());
    const id = await createOnline(t, seller);
    await setUntil(id, day(1));
    await job.run();
    await setUntil(id, day(-1));
    await job.run();
    expect(await statusOf(seller, id)).toBe('expired');
    await t.http().post(`/v1/listings/${id}/reactivate`).set(bearer(seller)).send({ until: day(2) }).expect(200);
    await job.run();
    expect((await notifs(seller)).filter((n: string) => n === 'listing_expiring_soon')).toHaveLength(2);
  });
});

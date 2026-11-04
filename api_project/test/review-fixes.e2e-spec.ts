import sharp from 'sharp';
import { ExpiryJob } from '../src/jobs/expiry.job.js';
import { createOnline, listingBody, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

const day = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString().slice(0, 10);

/** Corrections issues de la relecture finale de la branche. */
describe('Corrections de la relecture', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('caps parallel code guesses at 5 attempts per challenge', async () => {
    await t.http().post('/v1/auth/otp/request').send({ phone: '0711000001' }).expect(202);
    const code = t.otp.lastCodeFor('+2250711000001');
    const wrong = code === '000000' ? '111111' : '000000';
    const results = await Promise.all(
      Array.from({ length: 8 }, () => t.http().post('/v1/auth/otp/verify').send({ phone: '0711000001', code: wrong, name: 'Pirate' })),
    );
    expect(results.filter((r) => r.status === 401).length).toBeLessThanOrEqual(5);
    // Le défi est épuisé : même le bon code est refusé.
    await t.http().post('/v1/auth/otp/verify').send({ phone: '0711000001', code, name: 'Pirate' }).expect(429);
  });

  it('lets one code open only one session', async () => {
    await t.http().post('/v1/auth/otp/request').send({ phone: '0711000002' }).expect(202);
    const code = t.otp.lastCodeFor('+2250711000002');
    const results = await Promise.all(
      [1, 2, 3].map(() => t.http().post('/v1/auth/otp/verify').send({ phone: '0711000002', code, name: 'Awa' })),
    );
    expect(results.filter((r) => r.status === 200)).toHaveLength(1);
  });

  it('keeps a buyer’s cancellation when it races with the seller’s acceptance', async () => {
    const seller = await sellerSession(t, '0711000003');
    const listing = await createOnline(t, seller, { offers: { nightly: { price: 20000 } } });
    for (let i = 0; i < 4; i++) {
      const buyer = await loginAs(t, `07110001${String(i).padStart(2, '0')}`);
      const stay = { listingId: listing, offerType: 'nightly', checkIn: day(100 + i * 5), checkOut: day(102 + i * 5) };
      const req = (await t.http().post('/v1/requests').set(bearer(buyer)).send(stay).expect(201)).body;
      const [acc, can] = await Promise.all([
        t.http().post(`/v1/requests/${req.id}/accept`).set(bearer(seller)).send({}),
        t.http().post(`/v1/requests/${req.id}/cancel`).set(bearer(buyer)),
      ]);
      const [row] = await t.ds.query(`SELECT status FROM listing_requests WHERE id = $1`, [req.id]);
      const [{ blocked }] = await t.ds.query(`SELECT count(*)::int AS blocked FROM blocked_stays WHERE request_id = $1`, [req.id]);
      if (can.status === 200) {
        expect(row.status).toBe('cancelled');
        expect(blocked).toBe(0);
      } else {
        expect(acc.status).toBe(200);
        expect(row.status).toBe('accepted');
      }
    }
  });

  it('extends an online listing without taking it offline', async () => {
    const seller = await sellerSession(t, '0711000004');
    const listing = await createOnline(t, seller);
    await t.http().post(`/v1/listings/${listing}/extend`).set(bearer(seller)).send({ until: day(2) }).expect(200);
    const job = t.app.get(ExpiryJob);
    await job.run();
    const res = await t.http().post(`/v1/listings/${listing}/extend`).set(bearer(seller)).send({ until: day(30) }).expect(200);
    expect(res.body).toMatchObject({ status: 'online', publishedUntil: day(30) });
    const [row] = await t.ds.query(`SELECT expiry_reminder_sent_at FROM listings WHERE id = $1`, [listing]);
    expect(row.expiry_reminder_sent_at).toBeNull();
    const permanent = await t.http().post(`/v1/listings/${listing}/extend`).set(bearer(seller)).send({}).expect(200);
    expect(permanent.body.publishedUntil).toBeNull();
  });

  it('trusts the configured proxy for client IPs', () => {
    expect(t.app.getHttpAdapter().getInstance().get('trust proxy')).toBe(1);
  });

  it('accepts sale prices above 2.1 billion FCFA', async () => {
    const seller = await sellerSession(t, '0711000005');
    const res = await t
      .http()
      .post('/v1/listings')
      .set(bearer(seller))
      .send(listingBody({ offers: { sale: { price: 3_500_000_000 } } }))
      .expect(201);
    expect(res.body.offers.sale.price).toBe(3_500_000_000);
  });

  it('rejects oversized images before decoding them', async () => {
    const seller = await sellerSession(t, '0711000006');
    const id = (await t.http().post('/v1/listings').set(bearer(seller)).send(listingBody()).expect(201)).body.id;
    const huge = await sharp({ create: { width: 9000, height: 9000, channels: 3, background: '#eeeeee' } }).png().toBuffer();
    const res = await t.http().post(`/v1/listings/${id}/photos`).set(bearer(seller)).attach('photos', huge, 'huge.png').expect(400);
    expect(res.body.error.code).toBe('IMAGE_TOO_LARGE');
  });

  it('tolerates a refresh retried right after a lost response', async () => {
    const s = await loginAs(t, '0711000007', 'Réseau instable');
    const first = await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(200);
    // La réponse s'est perdue : l'app renvoie l'ancien jeton quelques secondes après.
    const retry = await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(200);
    expect(retry.body.user.id).toBe(s.user.id);
    // La session n'a pas été révoquée : le jeton issu du premier renouvellement fonctionne encore.
    await t.http().post('/v1/auth/refresh').send({ refreshToken: first.body.refreshToken }).expect(200);
  });
});

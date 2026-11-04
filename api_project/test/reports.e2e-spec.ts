import { createOnline, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

const PHONE_A = '11111111-1111-4111-8111-111111111111';
const PHONE_B = '22222222-2222-4222-8222-222222222222';
const PHONE_C = '33333333-3333-4333-8333-333333333333';

describe('Signalements', () => {
  let t: TestApp;
  let seller: Awaited<ReturnType<typeof sellerSession>>;

  beforeAll(async () => {
    t = await bootTestApp();
    seller = await sellerSession(t, '0708000001');
  });
  afterAll(async () => {
    await t.app.close();
  });

  const visibleIn = async (installation: string, id: string, headers: Record<string, string> = {}) => {
    const list = await t.http().get('/v1/listings').set({ 'X-Installation-Id': installation, ...headers }).expect(200);
    return list.body.data.some((l: { id: string }) => l.id === id);
  };

  it('hides a reported listing only for the phone that reported it', async () => {
    const id = await createOnline(t, seller, { title: 'Annonce suspecte' });
    await t
      .http()
      .post(`/v1/listings/${id}/reports`)
      .set('X-Installation-Id', PHONE_A)
      .send({ reason: 'scam', comment: 'Demande un paiement avant visite' })
      .expect(201);

    expect(await visibleIn(PHONE_A, id)).toBe(false);
    await t.http().get(`/v1/listings/${id}`).set('X-Installation-Id', PHONE_A).expect(404);

    expect(await visibleIn(PHONE_B, id)).toBe(true);
    await t.http().get(`/v1/listings/${id}`).set('X-Installation-Id', PHONE_B).expect(200);
  });

  it('follows a signed-in user to another phone', async () => {
    const id = await createOnline(t, seller, { title: 'Prix trompeur' });
    const buyer = await loginAs(t, '0708000002', 'Awa');
    await t
      .http()
      .post(`/v1/listings/${id}/reports`)
      .set({ ...bearer(buyer), 'X-Installation-Id': PHONE_A })
      .send({ reason: 'misleading_price' })
      .expect(201);
    expect(await visibleIn(PHONE_C, id, bearer(buyer))).toBe(false);
    expect(await visibleIn(PHONE_C, id)).toBe(true);
  });

  it('requires an installation id when not signed in', async () => {
    const id = await createOnline(t, seller, { title: 'Sans identifiant' });
    const res = await t.http().post(`/v1/listings/${id}/reports`).send({ reason: 'other' }).expect(400);
    expect(res.body.error.code).toBe('INSTALLATION_ID_REQUIRED');
  });

  it('does not let a seller report their own listing', async () => {
    const id = await createOnline(t, seller, { title: 'La mienne' });
    const res = await t.http().post(`/v1/listings/${id}/reports`).set(bearer(seller)).send({ reason: 'scam' }).expect(422);
    expect(res.body.error.code).toBe('CANNOT_REPORT_OWN_LISTING');
  });

  it('records a repeated report only once', async () => {
    const id = await createOnline(t, seller, { title: 'Doublon' });
    for (let i = 0; i < 2; i++) {
      await t.http().post(`/v1/listings/${id}/reports`).set('X-Installation-Id', PHONE_B).send({ reason: 'unavailable' }).expect(201);
    }
    const [{ count }] = await t.ds.query(`SELECT count(*)::int AS count FROM reports WHERE listing_id = $1`, [id]);
    expect(count).toBe(1);
  });
});

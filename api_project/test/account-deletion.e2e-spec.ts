import { createOnline, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

const day = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString().slice(0, 10);

describe('Suppression de compte', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('removes a seller’s listings, refuses their pending requests and frees the phone number', async () => {
    const seller = await sellerSession(t, '0710000001', 'Vendeur Parti');
    const listing = await createOnline(t, seller);
    const buyer = await loginAs(t, '0710000002', 'Acheteur');
    const req = (await t.http().post('/v1/requests').set(bearer(buyer)).send({ listingId: listing, offerType: 'monthly' }).expect(201)).body;

    await t.http().delete('/v1/me').set(bearer(seller)).expect(204);

    await t.http().get(`/v1/listings/${listing}`).expect(404);
    const mine = (await t.http().get('/v1/me/requests').set(bearer(buyer)).expect(200)).body.data;
    expect(mine.find((r: { id: string }) => r.id === req.id)).toMatchObject({ status: 'refused', refusalReason: 'listing_unavailable' });

    const refresh = await t.http().post('/v1/auth/refresh').send({ refreshToken: seller.refreshToken }).expect(401);
    expect(refresh.body.error.code).toBe('REFRESH_INVALID');

    const again = await t.http().post('/v1/auth/otp/request').send({ phone: '0710000001' }).expect(202);
    expect(again.body.isNewUser).toBe(true);
    const fresh = await t
      .http()
      .post('/v1/auth/otp/verify')
      .send({ phone: '0710000001', code: t.otp.lastCodeFor('+2250710000001'), name: 'Nouveau Compte' })
      .expect(200);
    expect(fresh.body.user.id).not.toBe(seller.user.id);
  });

  it('anonymises the account', async () => {
    const user = await loginAs(t, '0710000003', 'Awa Koné');
    await t.http().delete('/v1/me').set(bearer(user)).expect(204);
    const [row] = await t.ds.query(`SELECT name, phone, whatsapp_phone, avatar_url, deleted_at FROM users WHERE id = $1`, [user.user.id]);
    expect(row).toMatchObject({ name: 'Utilisateur supprimé', phone: null, whatsapp_phone: null, avatar_url: null });
    expect(row.deleted_at).not.toBeNull();
  });

  it('cancels a buyer’s accepted stay and frees the nights', async () => {
    const seller = await sellerSession(t, '0710000004');
    const listing = await createOnline(t, seller, { offers: { nightly: { price: 25000 } } });
    const leaving = await loginAs(t, '0710000005', 'Acheteur Parti');
    const other = await loginAs(t, '0710000006', 'Autre');
    const stay = { listingId: listing, offerType: 'nightly', checkIn: day(15), checkOut: day(17) };
    const req = (await t.http().post('/v1/requests').set(bearer(leaving)).send(stay).expect(201)).body;
    await t.http().post(`/v1/requests/${req.id}/accept`).set(bearer(seller)).send({}).expect(200);
    await t.http().post('/v1/requests').set(bearer(other)).send(stay).expect(409);

    await t.http().delete('/v1/me').set(bearer(leaving)).expect(204);

    await t.http().post('/v1/requests').set(bearer(other)).send(stay).expect(201);
    const notifs = (await t.http().get('/v1/me/notifications').set(bearer(seller)).expect(200)).body.data.map((n: { type: string }) => n.type);
    expect(notifs).toContain('request_cancelled');
  });
});

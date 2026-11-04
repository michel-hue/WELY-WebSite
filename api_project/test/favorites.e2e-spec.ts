import { createOnline, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

describe('Favoris', () => {
  let t: TestApp;
  let seller: Awaited<ReturnType<typeof sellerSession>>;
  let a: string;
  let b: string;

  beforeAll(async () => {
    t = await bootTestApp();
    seller = await sellerSession(t, '0707000001');
    a = await createOnline(t, seller, { title: 'Annonce A' });
    b = await createOnline(t, seller, { title: 'Annonce B' });
  });
  afterAll(async () => {
    await t.app.close();
  });

  const favorites = async (s: { accessToken: string }) =>
    (await t.http().get('/v1/me/favorites').set(bearer(s as never)).expect(200)).body.data.map((l: { title: string }) => l.title);

  it('adds a favourite only once', async () => {
    const buyer = await loginAs(t, '0707000002', 'Awa');
    await t.http().put(`/v1/me/favorites/${a}`).set(bearer(buyer)).expect(204);
    await t.http().put(`/v1/me/favorites/${a}`).set(bearer(buyer)).expect(204);
    expect(await favorites(buyer)).toEqual(['Annonce A']);
    await t.http().delete(`/v1/me/favorites/${a}`).set(bearer(buyer)).expect(204);
    expect(await favorites(buyer)).toEqual([]);
  });

  it('merges favourites kept on the phone, ignoring unknown ids', async () => {
    const buyer = await loginAs(t, '0707000003', 'Yao');
    await t
      .http()
      .post('/v1/me/favorites/merge')
      .set(bearer(buyer))
      .send({ listingIds: [a, b, '00000000-0000-4000-8000-000000000000'] })
      .expect(204);
    expect((await favorites(buyer)).sort()).toEqual(['Annonce A', 'Annonce B']);
  });

  it('hides favourites that are no longer online', async () => {
    const buyer = await loginAs(t, '0707000004', 'Koffi');
    const c = await createOnline(t, seller, { title: 'Annonce C' });
    await t.http().put(`/v1/me/favorites/${c}`).set(bearer(buyer)).expect(204);
    await t.http().post(`/v1/listings/${c}/close`).set(bearer(seller)).send({ reason: 'rented' }).expect(200);
    expect(await favorites(buyer)).toEqual([]);
  });

  it('refuses an unknown listing', async () => {
    const buyer = await loginAs(t, '0707000005', 'Fatou');
    const res = await t.http().put('/v1/me/favorites/00000000-0000-4000-8000-000000000000').set(bearer(buyer)).expect(404);
    expect(res.body.error.code).toBe('LISTING_NOT_FOUND');
  });
});

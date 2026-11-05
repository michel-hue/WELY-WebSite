import { createOnline, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

const day = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString().slice(0, 10);
const metres = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const h =
    Math.sin(toRad(b.lat - a.lat) / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(toRad(b.lng - a.lng) / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(h));
};

describe('Ajouts pour l’app mobile', () => {
  let t: TestApp;
  let phone = 7095_00000;
  const nextPhone = () => `0${++phone}`;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('gives list cards an approximate position, never the exact point', async () => {
    const seller = await sellerSession(t, nextPhone());
    const real = { lat: 5.2101, lng: -3.7402 };
    const id = await createOnline(t, seller, { location: real, district: 'Assinie' });

    const res = await t.http().get('/v1/listings').query({ lat: real.lat, lng: real.lng, radiusKm: 2 }).expect(200);
    const card = res.body.data.find((c: { id: string }) => c.id === id);
    expect(card).toBeDefined();
    expect(card.location).toBeUndefined();
    expect(card.approxLocation).not.toEqual(real);
    expect(metres(real, card.approxLocation)).toBeLessThanOrEqual(600);

    const again = await t.http().get('/v1/listings').query({ lat: real.lat, lng: real.lng, radiusKm: 2 }).expect(200);
    expect(again.body.data.find((c: { id: string }) => c.id === id).approxLocation).toEqual(card.approxLocation);
  });

  it('gives the buyer the seller’s contact, even once the listing is closed', async () => {
    const seller = await sellerSession(t, nextPhone(), 'Koffi Vendeur');
    const listing = await createOnline(t, seller);
    const buyer = await loginAs(t, nextPhone(), 'Awa Acheteuse');

    const created = await t
      .http()
      .post('/v1/requests')
      .set(bearer(buyer))
      .send({ listingId: listing, offerType: 'monthly', moveInDate: day(20), wantsVisit: false })
      .expect(201);
    expect(created.body.seller).toMatchObject({ name: 'Koffi Vendeur', phone: seller.user.phone, whatsappPhone: seller.user.phone });

    await t.http().post(`/v1/listings/${listing}/close`).set(bearer(seller)).send({ reason: 'rented' }).expect(200);

    const mine = (await t.http().get('/v1/me/requests').set(bearer(buyer)).expect(200)).body.data;
    expect(mine.find((r: { id: string }) => r.id === created.body.id).seller).toMatchObject({ phone: seller.user.phone });

    const received = (await t.http().get('/v1/me/received-requests').set(bearer(seller)).expect(200)).body.data;
    expect(received.find((r: { id: string }) => r.id === created.body.id).seller).toBeUndefined();
  });
});

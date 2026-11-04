import type { AuthSession } from '../src/auth/auth.service.js';
import { createOnline, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

/** Date à J+n (AAAA-MM-JJ). */
const day = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString().slice(0, 10);

describe('Demandes', () => {
  let t: TestApp;
  let phone = 7090_00000;
  const nextPhone = () => `0${++phone}`;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  const request = (s: AuthSession, body: Record<string, unknown>) => t.http().post('/v1/requests').set(bearer(s)).send(body);
  const notifTypes = async (s: AuthSession) =>
    (await t.http().get('/v1/me/notifications').set(bearer(s)).expect(200)).body.data.map(
      (n: { type: string; reason: string | null }) => `${n.type}${n.reason ? `:${n.reason}` : ''}`,
    );
  const received = async (s: AuthSession) => (await t.http().get('/v1/me/received-requests').set(bearer(s)).expect(200)).body.data;
  const statusOf = async (s: AuthSession, id: string) =>
    (await t.http().get('/v1/me/requests').set(bearer(s)).expect(200)).body.data.find((r: { id: string }) => r.id === id);

  describe('location au mois', () => {
    it('sends a request and shares the buyer’s contact with the seller only', async () => {
      const seller = await sellerSession(t, nextPhone(), 'Vendeur');
      const listing = await createOnline(t, seller);
      const buyer = await loginAs(t, nextPhone(), 'Awa Koné');

      const res = await request(buyer, { listingId: listing, offerType: 'monthly', moveInDate: day(30), wantsVisit: true, message: 'Bonjour' }).expect(201);
      expect(res.body).toMatchObject({ status: 'pending', offerType: 'monthly', wantsVisit: true, listing: { id: listing } });
      expect(res.body.buyer).toBeUndefined();

      const [r] = await received(seller);
      expect(r).toMatchObject({ id: res.body.id, buyer: { name: 'Awa Koné', phone: buyer.user.phone } });
      expect(await notifTypes(seller)).toEqual(['request_received']);

      const mine = await t.http().get(`/v1/me/listings/${listing}`).set(bearer(seller)).expect(200);
      expect(mine.body.stats.requests).toBe(1);
    });

    it('refuses a second pending request on the same listing', async () => {
      const seller = await sellerSession(t, nextPhone());
      const listing = await createOnline(t, seller);
      const buyer = await loginAs(t, nextPhone());
      await request(buyer, { listingId: listing, offerType: 'monthly' }).expect(201);
      const res = await request(buyer, { listingId: listing, offerType: 'monthly' }).expect(409);
      expect(res.body.error.code).toBe('REQUEST_ALREADY_PENDING');
    });

    it('refuses a request on one’s own listing, a missing offer, or an offline listing', async () => {
      const seller = await sellerSession(t, nextPhone());
      const listing = await createOnline(t, seller);
      expect((await request(seller, { listingId: listing, offerType: 'monthly' }).expect(422)).body.error.code).toBe(
        'CANNOT_REQUEST_OWN_LISTING',
      );
      const buyer = await loginAs(t, nextPhone());
      expect((await request(buyer, { listingId: listing, offerType: 'sale' }).expect(422)).body.error.code).toBe('OFFER_NOT_AVAILABLE');
      await t.http().post(`/v1/listings/${listing}/deactivate`).set(bearer(seller)).send({}).expect(200);
      expect((await request(buyer, { listingId: listing, offerType: 'monthly' }).expect(422)).body.error.code).toBe(
        'LISTING_NOT_AVAILABLE',
      );
    });

    it('lets the seller refuse with a message', async () => {
      const seller = await sellerSession(t, nextPhone());
      const listing = await createOnline(t, seller);
      const buyer = await loginAs(t, nextPhone());
      const { body } = await request(buyer, { listingId: listing, offerType: 'monthly' }).expect(201);
      await t.http().post(`/v1/requests/${body.id}/refuse`).set(bearer(seller)).send({ message: 'Déjà loué, désolé' }).expect(200);
      expect(await statusOf(buyer, body.id)).toMatchObject({ status: 'refused', refusalReason: 'seller', sellerMessage: 'Déjà loué, désolé' });
      expect(await notifTypes(buyer)).toEqual(['request_refused:seller']);
    });

    it('hides a request from third parties', async () => {
      const seller = await sellerSession(t, nextPhone());
      const listing = await createOnline(t, seller);
      const buyer = await loginAs(t, nextPhone());
      const stranger = await sellerSession(t, nextPhone());
      const { body } = await request(buyer, { listingId: listing, offerType: 'monthly' }).expect(201);
      const res = await t.http().post(`/v1/requests/${body.id}/accept`).set(bearer(stranger)).send({}).expect(404);
      expect(res.body.error.code).toBe('REQUEST_NOT_FOUND');
      await t.http().post(`/v1/requests/${body.id}/cancel`).set(bearer(stranger)).expect(404);
    });
  });

  describe('séjours à la nuit', () => {
    let seller: AuthSession;
    let listing: string;

    beforeAll(async () => {
      seller = await sellerSession(t, nextPhone());
      listing = await createOnline(t, seller, {
        offers: { monthly: { rent: 350000 }, nightly: { price: 30000, minNights: 1 } },
      });
    });

    it('requires stay dates', async () => {
      const buyer = await loginAs(t, nextPhone());
      const res = await request(buyer, { listingId: listing, offerType: 'nightly' }).expect(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('blocks accepted nights and refuses overlapping requests', async () => {
      const a = await loginAs(t, nextPhone(), 'Acheteur A');
      const b = await loginAs(t, nextPhone(), 'Acheteur B');
      const c = await loginAs(t, nextPhone(), 'Acheteur C');
      const ra = (await request(a, { listingId: listing, offerType: 'nightly', checkIn: day(40), checkOut: day(43) }).expect(201)).body;
      const rb = (await request(b, { listingId: listing, offerType: 'nightly', checkIn: day(42), checkOut: day(44) }).expect(201)).body;

      await t.http().post(`/v1/requests/${ra.id}/accept`).set(bearer(seller)).send({ message: 'Bienvenue !' }).expect(200);
      expect(await statusOf(a, ra.id)).toMatchObject({ status: 'accepted', sellerMessage: 'Bienvenue !' });
      expect(await statusOf(b, rb.id)).toMatchObject({ status: 'refused', refusalReason: 'dates_unavailable' });
      expect(await notifTypes(a)).toEqual(['request_accepted']);
      expect(await notifTypes(b)).toEqual(['request_refused:dates_unavailable']);

      const blocked = await request(c, { listingId: listing, offerType: 'nightly', checkIn: day(41), checkOut: day(42) }).expect(409);
      expect(blocked.body.error.code).toBe('STAY_DATES_UNAVAILABLE');

      const search = await t
        .http()
        .get('/v1/listings')
        .query({ offerType: 'nightly', checkIn: day(41), checkOut: day(42) })
        .expect(200);
      expect(search.body.data.map((l: { id: string }) => l.id)).not.toContain(listing);
      // Les nuits libres restent proposées : le départ de A (J+43) est une arrivée possible.
      const free = await t.http().get('/v1/listings').query({ offerType: 'nightly', checkIn: day(43), checkOut: day(45) }).expect(200);
      expect(free.body.data.map((l: { id: string }) => l.id)).toContain(listing);

      await t.http().post(`/v1/requests/${ra.id}/cancel`).set(bearer(a)).expect(200);
      expect(await notifTypes(seller)).toContain('request_cancelled');
      await request(c, { listingId: listing, offerType: 'nightly', checkIn: day(41), checkOut: day(42) }).expect(201);
    });

    it('lets only one of two simultaneous overlapping acceptances succeed', async () => {
      const a = await loginAs(t, nextPhone());
      const b = await loginAs(t, nextPhone());
      const ra = (await request(a, { listingId: listing, offerType: 'nightly', checkIn: day(60), checkOut: day(63) }).expect(201)).body;
      const rb = (await request(b, { listingId: listing, offerType: 'nightly', checkIn: day(61), checkOut: day(64) }).expect(201)).body;

      const results = await Promise.all(
        [ra.id, rb.id].map((id) => t.http().post(`/v1/requests/${id}/accept`).set(bearer(seller)).send({})),
      );
      expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
      const statuses = [await statusOf(a, ra.id), await statusOf(b, rb.id)].map((r) => r.status).sort();
      expect(statuses).toEqual(['accepted', 'refused']);
    });

    it('cannot accept a request that is no longer pending', async () => {
      const a = await loginAs(t, nextPhone());
      const ra = (await request(a, { listingId: listing, offerType: 'nightly', checkIn: day(80), checkOut: day(81) }).expect(201)).body;
      await t.http().post(`/v1/requests/${ra.id}/cancel`).set(bearer(a)).expect(200);
      const res = await t.http().post(`/v1/requests/${ra.id}/accept`).set(bearer(seller)).send({}).expect(422);
      expect(res.body.error.code).toBe('REQUEST_NOT_PENDING');
    });
  });

  describe('annonce qui quitte le marché', () => {
    it('refuses pending requests but keeps accepted ones', async () => {
      const seller = await sellerSession(t, nextPhone());
      const listing = await createOnline(t, seller, { offers: { monthly: { rent: 200000 }, nightly: { price: 20000 } } });
      const a = await loginAs(t, nextPhone());
      const b = await loginAs(t, nextPhone());
      const accepted = (await request(a, { listingId: listing, offerType: 'nightly', checkIn: day(20), checkOut: day(22) }).expect(201)).body;
      await t.http().post(`/v1/requests/${accepted.id}/accept`).set(bearer(seller)).send({}).expect(200);
      const pending = (await request(b, { listingId: listing, offerType: 'monthly' }).expect(201)).body;

      await t.http().post(`/v1/listings/${listing}/deactivate`).set(bearer(seller)).send({}).expect(200);
      expect(await statusOf(b, pending.id)).toMatchObject({ status: 'refused', refusalReason: 'listing_unavailable' });
      expect(await statusOf(a, accepted.id)).toMatchObject({ status: 'accepted' });
    });

    it('refuses only the requests of a removed offer', async () => {
      const seller = await sellerSession(t, nextPhone());
      const listing = await createOnline(t, seller, { offers: { monthly: { rent: 200000 }, nightly: { price: 20000 } } });
      const a = await loginAs(t, nextPhone());
      const b = await loginAs(t, nextPhone());
      const nightly = (await request(a, { listingId: listing, offerType: 'nightly', checkIn: day(20), checkOut: day(22) }).expect(201)).body;
      const monthly = (await request(b, { listingId: listing, offerType: 'monthly' }).expect(201)).body;

      await t.http().patch(`/v1/listings/${listing}`).set(bearer(seller)).send({ offers: { nightly: null } }).expect(200);
      expect(await statusOf(a, nightly.id)).toMatchObject({ status: 'refused', refusalReason: 'listing_unavailable' });
      expect(await statusOf(b, monthly.id)).toMatchObject({ status: 'pending' });
    });
  });
});

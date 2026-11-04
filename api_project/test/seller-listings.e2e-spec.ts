import { EventEmitter2 } from '@nestjs/event-emitter';
import { LISTING_UNAVAILABLE, type ListingUnavailableEvent } from '../src/common/events/domain-events.js';
import { createDraft, listingBody, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

const tomorrow = () => new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);
const yesterday = () => new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);

describe('Annonces côté vendeur', () => {
  let t: TestApp;
  const events: ListingUnavailableEvent[] = [];

  beforeAll(async () => {
    t = await bootTestApp();
    t.app.get(EventEmitter2).on(LISTING_UNAVAILABLE, (e: ListingUnavailableEvent) => {
      events.push(e);
    });
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('requires seller mode to create a listing', async () => {
    const buyer = await loginAs(t, '0704000001', 'Acheteur');
    const res = await t.http().post('/v1/listings').set(bearer(buyer)).send(listingBody()).expect(403);
    expect(res.body.error).toEqual({ code: 'SELLER_MODE_REQUIRED', message: 'Activez le mode vendeur pour publier.' });
  });

  it('creates a draft with its offers', async () => {
    const s = await sellerSession(t, '0704000002');
    const res = await t.http().post('/v1/listings').set(bearer(s)).send(listingBody()).expect(201);
    expect(res.body).toMatchObject({
      status: 'draft',
      title: 'Villa contemporaine',
      offers: { monthly: { rent: 650000, terms: '3 mois de caution' } },
      location: { lat: 5.3599, lng: -3.9873 },
      photos: [],
      stats: { views: 0, contactClicks: 0, requests: 0 },
    });
    const mine = await t.http().get('/v1/me/listings').set(bearer(s)).expect(200);
    expect(mine.body.data.map((l: { id: string }) => l.id)).toEqual([res.body.id]);
  });

  it('refuses to publish a listing without location', async () => {
    const s = await sellerSession(t, '0704000003');
    const id = await createDraft(t, s, { location: undefined });
    const res = await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({}).expect(422);
    expect(res.body.error.code).toBe('LISTING_INCOMPLETE');
    expect(res.body.error.details).toEqual(expect.arrayContaining([expect.objectContaining({ field: 'location' })]));
  });

  it('refuses to publish without any offer', async () => {
    const s = await sellerSession(t, '0704000004');
    const id = await createDraft(t, s, { offers: {} });
    const res = await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({}).expect(422);
    expect(res.body.error.details).toEqual(expect.arrayContaining([expect.objectContaining({ field: 'offers' })]));
  });

  it('forbids editing someone else’s listing', async () => {
    const owner = await sellerSession(t, '0704000005');
    const other = await sellerSession(t, '0704000006');
    const id = await createDraft(t, owner);
    const res = await t.http().patch(`/v1/listings/${id}`).set(bearer(other)).send({ title: 'Piratée' }).expect(403);
    expect(res.body.error.code).toBe('NOT_LISTING_OWNER');
  });

  it('runs the publish → close → reactivate lifecycle', async () => {
    const s = await sellerSession(t, '0704000007');
    const id = await createDraft(t, s);
    const online = await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({ until: tomorrow() }).expect(200);
    expect(online.body).toMatchObject({ status: 'online', publishedUntil: tomorrow() });

    const closed = await t.http().post(`/v1/listings/${id}/close`).set(bearer(s)).send({ reason: 'rented' }).expect(200);
    expect(closed.body).toMatchObject({ status: 'closed', closedReason: 'rented' });

    const bad = await t.http().post(`/v1/listings/${id}/reactivate`).set(bearer(s)).send({ until: yesterday() }).expect(422);
    expect(bad.body.error.code).toBe('INVALID_PUBLICATION_DATE');

    const again = await t.http().post(`/v1/listings/${id}/reactivate`).set(bearer(s)).send({}).expect(200);
    expect(again.body).toMatchObject({ status: 'online', closedReason: null, publishedUntil: null });
  });

  it('refuses an impossible transition', async () => {
    const s = await sellerSession(t, '0704000008');
    const id = await createDraft(t, s);
    const res = await t.http().post(`/v1/listings/${id}/close`).set(bearer(s)).send({ reason: 'sold' }).expect(422);
    expect(res.body.error.code).toBe('INVALID_LISTING_TRANSITION');
  });

  it('announces a listing that leaves the market, or loses an offer', async () => {
    const s = await sellerSession(t, '0704000009');
    const id = await createDraft(t, s, {
      offers: { monthly: { rent: 350000 }, nightly: { price: 30000, minNights: 2 } },
    });
    await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({}).expect(200);

    events.length = 0;
    await t.http().patch(`/v1/listings/${id}`).set(bearer(s)).send({ offers: { nightly: null } }).expect(200);
    expect(events).toEqual([{ listingId: id, offerTypes: ['nightly'] }]);

    events.length = 0;
    await t.http().post(`/v1/listings/${id}/deactivate`).set(bearer(s)).send({}).expect(200);
    expect(events).toEqual([{ listingId: id }]);
  });

  it('lets a former seller still manage an existing listing', async () => {
    const s = await sellerSession(t, '0704000012');
    const id = await createDraft(t, s);
    await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({}).expect(200);
    await t.http().put('/v1/me/seller-mode').set(bearer(s)).send({ enabled: false }).expect(200);
    await t.http().post(`/v1/listings/${id}/deactivate`).set(bearer(s)).send({}).expect(200);
    const res = await t.http().post(`/v1/listings/${id}/reactivate`).set(bearer(s)).send({}).expect(403);
    expect(res.body.error.code).toBe('SELLER_MODE_REQUIRED');
  });

  it('soft-deletes a listing', async () => {
    const s = await sellerSession(t, '0704000010');
    const id = await createDraft(t, s);
    await t.http().delete(`/v1/listings/${id}`).set(bearer(s)).expect(204);
    const res = await t.http().get(`/v1/me/listings/${id}`).set(bearer(s)).expect(404);
    expect(res.body.error.code).toBe('LISTING_NOT_FOUND');
  });

  it('validates prices as positive integers', async () => {
    const s = await sellerSession(t, '0704000011');
    const res = await t
      .http()
      .post('/v1/listings')
      .set(bearer(s))
      .send(listingBody({ offers: { monthly: { rent: -5 } } }))
      .expect(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});

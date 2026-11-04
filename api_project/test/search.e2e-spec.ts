import { createDraft, createOnline, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, type TestApp } from './utils/test-app.js';

const COCODY = { lat: 5.3599, lng: -3.9873 };

describe('Recherche et fiche publique', () => {
  let t: TestApp;
  let seller: Awaited<ReturnType<typeof sellerSession>>;
  const ids: Record<'cocody' | 'riviera' | 'assinie' | 'draft', string> = { cocody: '', riviera: '', assinie: '', draft: '' };

  beforeAll(async () => {
    t = await bootTestApp();
    seller = await sellerSession(t, '0706000001', 'Kouamé Immobilier');
    ids.cocody = await createOnline(t, seller, {
      title: 'Villa contemporaine',
      city: 'Abidjan',
      district: 'Cocody, Angré',
      location: COCODY,
      offers: { monthly: { rent: 650000 } },
    });
    ids.riviera = await createOnline(t, seller, {
      title: 'Appartement lumineux',
      propertyType: 'apartment',
      city: 'Abidjan',
      district: 'Riviera Palmeraie',
      location: { lat: 5.3667, lng: -3.95 },
      offers: { monthly: { rent: 350000 }, nightly: { price: 30000 } },
    });
    ids.assinie = await createOnline(t, seller, {
      title: 'Maison de vacances',
      propertyType: 'house',
      city: 'Assinie',
      district: 'Assinie-Mafia',
      location: { lat: 5.1333, lng: -3.4667 },
      offers: { nightly: { price: 90000 } },
    });
    ids.draft = await createDraft(t, seller, { title: 'Brouillon caché', location: COCODY });
  });
  afterAll(async () => {
    await t.app.close();
  });

  const search = (query: Record<string, unknown>) => t.http().get('/v1/listings').query(query);
  const titles = (body: { data: { title: string }[] }) => body.data.map((l) => l.title);

  it('finds listings around me, nearest first', async () => {
    const res = await search({ ...COCODY, radiusKm: 10 }).expect(200);
    expect(titles(res.body)).toEqual(['Villa contemporaine', 'Appartement lumineux']);
    const [first, second] = res.body.data;
    expect(first.distanceMeters).toBeLessThan(second.distanceMeters);
    expect(first.distanceMeters).toBeLessThan(5);
  });

  it('filters by offer type', async () => {
    const res = await search({ offerType: 'nightly', sort: 'price_asc' }).expect(200);
    expect(titles(res.body)).toEqual(['Appartement lumineux', 'Maison de vacances']);
  });

  it('filters the price of the chosen offer', async () => {
    const res = await search({ offerType: 'monthly', priceMax: 400000 }).expect(200);
    expect(titles(res.body)).toEqual(['Appartement lumineux']);
  });

  it('rejects a price filter without offer type', async () => {
    const res = await search({ priceMin: 1000 }).expect(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details).toEqual([expect.objectContaining({ field: 'offerType' })]);
  });

  it.each(['cocody', 'COCODY', 'côcody'])('searches text ignoring case and accents (%s)', async (q) => {
    const res = await search({ q }).expect(200);
    expect(titles(res.body)).toEqual(['Villa contemporaine']);
  });

  it('never shows drafts', async () => {
    const res = await search({}).expect(200);
    expect(titles(res.body)).not.toContain('Brouillon caché');
    await t.http().get(`/v1/listings/${ids.draft}`).expect(404);
  });

  it('paginates without duplicates', async () => {
    const seen: string[] = [];
    let cursor: string | null = null;
    do {
      const res = await search({ limit: 1, ...(cursor ? { cursor } : {}) }).expect(200);
      seen.push(...titles(res.body));
      cursor = res.body.nextCursor;
    } while (cursor);
    expect(seen.sort()).toEqual(['Appartement lumineux', 'Maison de vacances', 'Villa contemporaine']);
  });

  it('paginates by distance without duplicates', async () => {
    const seen: string[] = [];
    let cursor: string | null = null;
    do {
      const res = await search({ ...COCODY, radiusKm: 100, limit: 1, ...(cursor ? { cursor } : {}) }).expect(200);
      seen.push(...titles(res.body));
      cursor = res.body.nextCursor;
    } while (cursor);
    expect(seen).toEqual(['Villa contemporaine', 'Appartement lumineux', 'Maison de vacances']);
  });

  it('keeps exact coordinates for the detail page only', async () => {
    const list = await search({ q: 'cocody' }).expect(200);
    expect(list.body.data[0].location).toBeUndefined();
    expect(list.body.data[0].coverThumbUrl).toMatch(/thumb\.webp$/);

    const detail = await t.http().get(`/v1/listings/${ids.cocody}`).expect(200);
    expect(detail.body).toMatchObject({
      location: COCODY,
      offers: { monthly: { rent: 650000 } },
      seller: { name: 'Kouamé Immobilier', phone: '+2250706000001', whatsappPhone: '+2250706000001', onlineListingsCount: 3 },
    });
    expect(detail.body.photos).toHaveLength(1);
    expect(detail.body.stats).toBeUndefined();
  });

  it('counts contact clicks and views for the seller', async () => {
    await t.http().post(`/v1/listings/${ids.riviera}/contact-clicks`).send({ channel: 'whatsapp' }).expect(204);
    await t.http().get(`/v1/listings/${ids.riviera}`).expect(200);
    const mine = await t.http().get(`/v1/me/listings/${ids.riviera}`).set(bearer(seller)).expect(200);
    expect(mine.body.stats.contactClicks).toBe(1);
    expect(mine.body.stats.views).toBeGreaterThanOrEqual(1);
  });

  it('lists cities and districts with listings online', async () => {
    const res = await t.http().get('/v1/locations').expect(200);
    expect(res.body).toEqual({
      cities: [
        { city: 'Abidjan', districts: ['Cocody, Angré', 'Riviera Palmeraie'] },
        { city: 'Assinie', districts: ['Assinie-Mafia'] },
      ],
    });
  });
});

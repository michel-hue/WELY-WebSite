import { join } from 'node:path';
import { createDraft, sellerSession } from './utils/fixtures.js';
import { bearer, bootTestApp, type TestApp } from './utils/test-app.js';

const HOUSE = join(import.meta.dirname, 'fixtures', 'house.jpg');
const NOTE = join(import.meta.dirname, 'fixtures', 'note.txt');

describe('Photos d’annonces', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  const upload = (s: { accessToken: string }, id: string, count = 1) => {
    let req = t.http().post(`/v1/listings/${id}/photos`).set(bearer(s as never));
    for (let i = 0; i < count; i++) req = req.attach('photos', HOUSE);
    return req;
  };

  it('stores a photo in two webp sizes', async () => {
    const s = await sellerSession(t, '0705000001');
    const id = await createDraft(t, s, {}, { photo: false });
    const res = await upload(s, id).expect(201);
    expect(res.body).toHaveLength(1);
    const [photo] = res.body;
    expect(photo).toMatchObject({ position: 0, width: 400 });
    const thumb = await t.http().get(photo.thumbUrl).expect(200);
    expect(thumb.headers['content-type']).toBe('image/webp');
    await t.http().get(photo.largeUrl).expect(200);

    const listing = await t.http().get(`/v1/me/listings/${id}`).set(bearer(s)).expect(200);
    expect(listing.body.photos).toEqual([photo]);
  });

  it('rejects a file that is not an image', async () => {
    const s = await sellerSession(t, '0705000002');
    const id = await createDraft(t, s, {}, { photo: false });
    const res = await t.http().post(`/v1/listings/${id}/photos`).set(bearer(s)).attach('photos', NOTE).expect(400);
    expect(res.body.error.code).toBe('UNSUPPORTED_IMAGE');
  });

  it('limits a listing to 15 photos', async () => {
    const s = await sellerSession(t, '0705000003');
    const id = await createDraft(t, s, {}, { photo: false });
    await upload(s, id, 10).expect(201);
    await upload(s, id, 5).expect(201);
    const res = await upload(s, id, 1).expect(422);
    expect(res.body.error.code).toBe('TOO_MANY_PHOTOS');
  });

  it('reorders photos', async () => {
    const s = await sellerSession(t, '0705000004');
    const id = await createDraft(t, s, {}, { photo: false });
    const [a, b] = (await upload(s, id, 2).expect(201)).body;
    await t.http().put(`/v1/listings/${id}/photos/order`).set(bearer(s)).send({ photoIds: [b.id, a.id] }).expect(204);
    const listing = await t.http().get(`/v1/me/listings/${id}`).set(bearer(s)).expect(200);
    expect(listing.body.photos.map((p: { id: string }) => p.id)).toEqual([b.id, a.id]);
    expect(listing.body.photos[0].position).toBe(0);

    const bad = await t.http().put(`/v1/listings/${id}/photos/order`).set(bearer(s)).send({ photoIds: [a.id] }).expect(400);
    expect(bad.body.error.code).toBe('INVALID_PHOTO_ORDER');
  });

  it('requires a photo to publish', async () => {
    const s = await sellerSession(t, '0705000005');
    const id = await createDraft(t, s, {}, { photo: false });
    const res = await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({}).expect(422);
    expect(res.body.error.code).toBe('LISTING_INCOMPLETE');
    expect(res.body.error.details).toEqual([expect.objectContaining({ field: 'photos' })]);
  });

  it('keeps at least one photo on an online listing', async () => {
    const s = await sellerSession(t, '0705000006');
    const id = await createDraft(t, s, {}, { photo: false });
    const [photo] = (await upload(s, id).expect(201)).body;
    await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({}).expect(200);
    const res = await t.http().delete(`/v1/listings/${id}/photos/${photo.id}`).set(bearer(s)).expect(422);
    expect(res.body.error.code).toBe('LAST_PHOTO_OF_ONLINE_LISTING');
  });

  it('deletes a photo and its files', async () => {
    const s = await sellerSession(t, '0705000007');
    const id = await createDraft(t, s, {}, { photo: false });
    const [a, b] = (await upload(s, id, 2).expect(201)).body;
    await t.http().delete(`/v1/listings/${id}/photos/${a.id}`).set(bearer(s)).expect(204);
    await t.http().get(a.thumbUrl).expect(404);
    const listing = await t.http().get(`/v1/me/listings/${id}`).set(bearer(s)).expect(200);
    expect(listing.body.photos).toEqual([expect.objectContaining({ id: b.id, position: 0 })]);
  });

  it('forbids uploading to someone else’s listing', async () => {
    const owner = await sellerSession(t, '0705000008');
    const other = await sellerSession(t, '0705000009');
    const id = await createDraft(t, owner, {}, { photo: false });
    const res = await upload(other, id).expect(403);
    expect(res.body.error.code).toBe('NOT_LISTING_OWNER');
  });
});

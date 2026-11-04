import type { AuthSession } from '../../src/auth/auth.service.js';
import { join } from 'node:path';
import { bearer, loginAs, type TestApp } from './test-app.js';

export const HOUSE_PHOTO = join(import.meta.dirname, '..', 'fixtures', 'house.jpg');

/** Corps d'annonce complet et publiable (hors photos). */
export const listingBody = (overrides: Record<string, unknown> = {}) => ({
  title: 'Villa contemporaine',
  description: 'Belle villa lumineuse avec jardin.',
  propertyType: 'villa',
  rooms: 5,
  bedrooms: 4,
  bathrooms: 3,
  amenities: ['parking', 'garden'],
  city: 'Abidjan',
  district: 'Cocody, Angré',
  location: { lat: 5.3599, lng: -3.9873 },
  offers: { monthly: { rent: 650000, terms: '3 mois de caution' } },
  ...overrides,
});

/** Connecte un utilisateur et active son mode vendeur. */
export async function sellerSession(t: TestApp, phone: string, name = 'Vendeur Test'): Promise<AuthSession> {
  const s = await loginAs(t, phone, name);
  await t.http().put('/v1/me/seller-mode').set(bearer(s)).send({ enabled: true }).expect(200);
  return s;
}

/** Crée un brouillon (avec une photo par défaut, pour pouvoir le publier) et renvoie son id. */
export async function createDraft(
  t: TestApp,
  s: AuthSession,
  overrides: Record<string, unknown> = {},
  opts: { photo?: boolean } = {},
): Promise<string> {
  const res = await t.http().post('/v1/listings').set(bearer(s)).send(listingBody(overrides)).expect(201);
  const id = res.body.id as string;
  if (opts.photo !== false) {
    await t.http().post(`/v1/listings/${id}/photos`).set(bearer(s)).attach('photos', HOUSE_PHOTO).expect(201);
  }
  return id;
}

/** Crée une annonce en ligne (permanente) et renvoie son id. */
export async function createOnline(t: TestApp, s: AuthSession, overrides: Record<string, unknown> = {}): Promise<string> {
  const id = await createDraft(t, s, overrides);
  await t.http().post(`/v1/listings/${id}/publish`).set(bearer(s)).send({}).expect(200);
  return id;
}

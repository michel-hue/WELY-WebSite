import type { AuthSession } from '../../src/auth/auth.service.js';
import { bearer, loginAs, type TestApp } from './test-app.js';

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

/** Crée un brouillon et renvoie son id. */
export async function createDraft(t: TestApp, s: AuthSession, overrides: Record<string, unknown> = {}): Promise<string> {
  const res = await t.http().post('/v1/listings').set(bearer(s)).send(listingBody(overrides)).expect(201);
  return res.body.id as string;
}

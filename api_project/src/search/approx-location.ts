import { createHash } from 'node:crypto';

const EARTH_RADIUS_M = 6_371_000;
const MIN_OFFSET_M = 180;
const MAX_OFFSET_M = 480;
const round4 = (n: number) => Math.round(n * 10_000) / 10_000;

/**
 * Position approximative d'une annonce pour les cartes et listes : le point réel est
 * décalé de 180 à 480 m dans une direction tirée de l'identifiant (toujours la même pour
 * une annonce, pour que la pastille ne saute pas d'un appel à l'autre). Le point exact
 * n'est donné que sur la fiche.
 */
export function approxLocation(id: string, p: { lat: number; lng: number } | null): { lat: number; lng: number } | null {
  if (!p) return null;
  const h = createHash('sha256').update(id).digest();
  const angle = (h.readUInt16BE(0) / 0xffff) * 2 * Math.PI;
  const distance = MIN_OFFSET_M + (h.readUInt16BE(2) / 0xffff) * (MAX_OFFSET_M - MIN_OFFSET_M);
  const dLat = ((distance * Math.cos(angle)) / EARTH_RADIUS_M) * (180 / Math.PI);
  const dLng = ((distance * Math.sin(angle)) / (EARTH_RADIUS_M * Math.cos((p.lat * Math.PI) / 180))) * (180 / Math.PI);
  return { lat: round4(p.lat + dLat), lng: round4(p.lng + dLng) };
}

import { badRequest, unprocessable } from '../common/errors/app-error.js';

const isRealDate = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s) && new Date(`${s}T00:00:00Z`).toISOString().slice(0, 10) === s;

const nightsBetween = (checkIn: string, checkOut: string) =>
  Math.round((Date.parse(`${checkOut}T00:00:00Z`) - Date.parse(`${checkIn}T00:00:00Z`)) / 86_400_000);

/** Vérifie un séjour : dates réelles, arrivée aujourd'hui ou après, départ après l'arrivée, nuits minimum. */
export function validateStay(checkIn: string, checkOut: string, minNights: number | null, today: string): void {
  if (!isRealDate(checkIn) || !isRealDate(checkOut) || checkOut <= checkIn || checkIn < today) {
    throw badRequest('INVALID_STAY_DATES', 'Dates de séjour invalides : l’arrivée doit être à venir et précéder le départ.');
  }
  if (minNights && nightsBetween(checkIn, checkOut) < minNights) {
    throw unprocessable('MIN_NIGHTS_NOT_MET', `Ce logement demande au moins ${minNights} nuits.`);
  }
}

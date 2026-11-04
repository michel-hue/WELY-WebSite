import { parsePhoneNumberWithError } from 'libphonenumber-js';
import { badRequest } from '../common/errors/app-error.js';

/** Normalise un numéro au format E.164 (Côte d'Ivoire par défaut). */
export function normalizePhone(input: string): string {
  try {
    const parsed = parsePhoneNumberWithError(String(input ?? ''), 'CI');
    if (parsed.isValid()) return parsed.number;
  } catch {
    // numéro illisible : même erreur que numéro invalide
  }
  throw badRequest('INVALID_PHONE', 'Numéro de téléphone invalide.');
}

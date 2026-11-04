import { badRequest } from '../errors/app-error.js';

export type CursorValues = Record<string, string | number>;

/** Curseur opaque de pagination (keyset) : JSON encodé en base64url. */
export function encodeCursor(values: CursorValues): string {
  return Buffer.from(JSON.stringify(values), 'utf8').toString('base64url');
}

export function decodeCursor(cursor: string): CursorValues {
  try {
    const parsed: unknown = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('not an object');
    return parsed as CursorValues;
  } catch {
    throw badRequest('INVALID_CURSOR', 'Curseur de pagination invalide.');
  }
}

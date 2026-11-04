import { decodeCursor, encodeCursor } from './cursor.js';
import { AppError } from '../errors/app-error.js';

describe('cursor', () => {
  it('round-trips values through encode/decode', () => {
    const values = { publishedAt: '2026-11-04T10:00:00.000Z', id: 'abc', distance: 1234.5 };
    expect(decodeCursor(encodeCursor(values))).toEqual(values);
  });

  it('rejects a malformed cursor with INVALID_CURSOR', () => {
    try {
      decodeCursor('pas-du-base64');
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(AppError);
      expect((e as AppError).code).toBe('INVALID_CURSOR');
      expect((e as AppError).getStatus()).toBe(400);
    }
  });
});

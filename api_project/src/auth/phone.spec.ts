import { normalizePhone } from './phone.js';
import { AppError } from '../common/errors/app-error.js';

describe('normalizePhone', () => {
  it.each(['07 07 07 07 07', '0707070707', '+225 07 07 07 07 07', '+2250707070707'])(
    'normalizes %s to E.164 (Côte d’Ivoire by default)',
    (input) => {
      expect(normalizePhone(input)).toBe('+2250707070707');
    },
  );

  it.each(['123', '', 'abc', '+225 12'])('rejects %s with INVALID_PHONE', (input) => {
    try {
      normalizePhone(input);
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(AppError);
      expect((e as AppError).code).toBe('INVALID_PHONE');
      expect((e as AppError).getStatus()).toBe(400);
    }
  });
});

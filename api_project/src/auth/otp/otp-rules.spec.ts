import { evaluateOtpAttempt, hashOtp, OTP_MAX_ATTEMPTS, OTP_TTL_MS } from './otp-rules.js';

const SECRET = 'test-secret';
const now = new Date('2026-11-04T10:00:00Z');

function challenge(overrides: Partial<{ attempts: number; expiresAt: Date; consumedAt: Date | null }> = {}) {
  return {
    codeHash: hashOtp('123456', SECRET),
    attempts: 0,
    expiresAt: new Date(now.getTime() + OTP_TTL_MS),
    consumedAt: null,
    ...overrides,
  };
}

describe('evaluateOtpAttempt', () => {
  it('accepts the right code within validity', () => {
    expect(evaluateOtpAttempt(challenge(), '123456', now, SECRET)).toBe('ok');
  });

  it('rejects a wrong code as invalid', () => {
    expect(evaluateOtpAttempt(challenge(), '000000', now, SECRET)).toBe('invalid');
  });

  it('treats an expired code as invalid even if correct', () => {
    expect(evaluateOtpAttempt(challenge({ expiresAt: new Date(now.getTime() - 1) }), '123456', now, SECRET)).toBe(
      'invalid',
    );
  });

  it('treats an already used code as invalid', () => {
    expect(evaluateOtpAttempt(challenge({ consumedAt: now }), '123456', now, SECRET)).toBe('invalid');
  });

  it(`blocks the ${OTP_MAX_ATTEMPTS + 1}th attempt even with the right code`, () => {
    expect(OTP_MAX_ATTEMPTS).toBe(5);
    expect(evaluateOtpAttempt(challenge({ attempts: 5 }), '123456', now, SECRET)).toBe('too_many');
  });

  it('valid for 5 minutes', () => {
    expect(OTP_TTL_MS).toBe(5 * 60 * 1000);
  });
});

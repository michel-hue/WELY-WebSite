import { createHash, randomInt, timingSafeEqual } from 'node:crypto';

export const OTP_TTL_MS = 5 * 60 * 1000;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
export const OTP_MAX_SENDS_PER_HOUR = 5;

export const generateOtp = (): string => String(randomInt(0, 1_000_000)).padStart(6, '0');

export const hashOtp = (code: string, secret: string): string =>
  createHash('sha256').update(`${secret}:${code}`).digest('hex');

export interface ChallengeState {
  codeHash: string;
  attempts: number;
  expiresAt: Date;
  consumedAt: Date | null;
}

/** Décide de l'issue d'une saisie de code. */
export function evaluateOtpAttempt(
  challenge: ChallengeState,
  code: string,
  now: Date,
  secret: string,
): 'ok' | 'invalid' | 'too_many' {
  if (challenge.attempts >= OTP_MAX_ATTEMPTS) return 'too_many';
  if (challenge.consumedAt || challenge.expiresAt.getTime() <= now.getTime()) return 'invalid';
  const expected = Buffer.from(challenge.codeHash, 'hex');
  const actual = Buffer.from(hashOtp(code, secret), 'hex');
  return expected.length === actual.length && timingSafeEqual(expected, actual) ? 'ok' : 'invalid';
}

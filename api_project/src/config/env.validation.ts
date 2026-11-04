/**
 * Validation des variables d'environnement au démarrage.
 * Voir .env.example pour la description de chaque variable.
 */
export interface Env {
  NODE_ENV: 'development' | 'production' | 'test';
  PORT: number;
  DATABASE_URL: string;
  DATABASE_SSL: boolean;
  DATABASE_SCHEMA: string;
  JWT_SECRET: string;
  JWT_ACCESS_TTL: string;
  REFRESH_TTL_DAYS: number;
  CORS_ORIGIN?: string;
  OTP_PROVIDER: 'console' | 'twilio';
  TWILIO_ACCOUNT_SID?: string;
  TWILIO_AUTH_TOKEN?: string;
  TWILIO_SMS_FROM?: string;
  TWILIO_WHATSAPP_FROM?: string;
  PUSH_PROVIDER: 'log' | 'fcm';
  FCM_SERVICE_ACCOUNT_JSON?: string;
  STORAGE_DRIVER: 'local' | 's3';
  MEDIA_DIR: string;
  PUBLIC_MEDIA_BASE_URL?: string;
  S3_ENDPOINT?: string;
  S3_REGION?: string;
  S3_BUCKET?: string;
  S3_ACCESS_KEY_ID?: string;
  S3_SECRET_ACCESS_KEY?: string;
}

const oneOf = <T extends string>(value: string | undefined, allowed: readonly T[], fallback: T, name: string): T => {
  const v = (value ?? fallback) as T;
  if (!allowed.includes(v)) throw new Error(`${name} doit valoir ${allowed.join(' | ')} (reçu : ${value})`);
  return v;
};

export function validateEnv(raw: Record<string, string | undefined>): Env {
  const NODE_ENV = oneOf(raw.NODE_ENV, ['development', 'production', 'test'] as const, 'development', 'NODE_ENV');
  if (!raw.DATABASE_URL) throw new Error('DATABASE_URL est obligatoire');
  if (NODE_ENV === 'production' && !raw.JWT_SECRET) throw new Error('JWT_SECRET est obligatoire en production');
  const env: Env = {
    ...(raw as object),
    NODE_ENV,
    PORT: Number(raw.PORT ?? 3000),
    DATABASE_URL: raw.DATABASE_URL,
    DATABASE_SSL: (raw.DATABASE_SSL ?? 'true') !== 'false',
    DATABASE_SCHEMA: raw.DATABASE_SCHEMA ?? 'public',
    JWT_SECRET: raw.JWT_SECRET ?? 'dev-secret-change-me',
    JWT_ACCESS_TTL: raw.JWT_ACCESS_TTL ?? '15m',
    REFRESH_TTL_DAYS: Number(raw.REFRESH_TTL_DAYS ?? 180),
    OTP_PROVIDER: oneOf(raw.OTP_PROVIDER, ['console', 'twilio'] as const, 'console', 'OTP_PROVIDER'),
    PUSH_PROVIDER: oneOf(raw.PUSH_PROVIDER, ['log', 'fcm'] as const, 'log', 'PUSH_PROVIDER'),
    STORAGE_DRIVER: oneOf(raw.STORAGE_DRIVER, ['local', 's3'] as const, 'local', 'STORAGE_DRIVER'),
    MEDIA_DIR: raw.MEDIA_DIR ?? './media',
  };
  return env;
}

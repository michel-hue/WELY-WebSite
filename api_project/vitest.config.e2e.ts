import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';
import swc from 'unplugin-swc';
import { existsSync, readFileSync } from 'node:fs';

/**
 * Base des tests e2e :
 *  - TEST_DATABASE_URL si défini (ex. CI avec un conteneur PostGIS, TEST_DATABASE_SSL=false) ;
 *  - sinon la DATABASE_URL du fichier .env (Neon), en connexion directe (sans pooler,
 *    nécessaire pour fixer le search_path), dans le schéma isolé `welly_test`.
 */
function dotenvValue(key: string): string | undefined {
  if (!existsSync('.env')) return undefined;
  const line = readFileSync('.env', 'utf8')
    .split(/\r?\n/)
    .find((l) => l.startsWith(`${key}=`));
  return line?.slice(key.length + 1).trim().replace(/^['"]|['"]$/g, '');
}

const fromDotenv = dotenvValue('DATABASE_URL')?.replace('-pooler.', '.').replace('sslmode=require', 'sslmode=verify-full');
const testDbUrl = process.env.TEST_DATABASE_URL ?? fromDotenv;
if (!testDbUrl) throw new Error('Définissez TEST_DATABASE_URL ou DATABASE_URL dans .env pour les tests e2e.');

const testEnv = {
  NODE_ENV: 'test',
  DATABASE_URL: testDbUrl,
  DATABASE_SSL: process.env.TEST_DATABASE_SSL ?? 'true',
  DATABASE_SCHEMA: process.env.TEST_DATABASE_SCHEMA ?? 'welly_test',
  JWT_SECRET: 'test-secret',
  STORAGE_DRIVER: 'local',
  MEDIA_DIR: './.test-media',
  // Les tests enchaînent beaucoup de connexions depuis la même IP.
  THROTTLE_LIMIT: '100000',
  OTP_IP_LIMIT_PER_MIN: '100000',
};
// Le globalSetup tourne dans ce processus : il lit process.env.
Object.assign(process.env, testEnv);

export default defineConfig({
  plugins: [tsconfigPaths(), swc.vite({ module: { type: 'es6' } })],
  test: {
    globals: true,
    root: './',
    include: ['test/**/*.e2e-spec.ts'],
    globalSetup: ['test/utils/global-setup.ts'],
    fileParallelism: false,
    testTimeout: 60_000,
    hookTimeout: 120_000,
    env: testEnv,
  },
});

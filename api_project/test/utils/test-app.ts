import { Test, type TestingModuleBuilder } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { AppModule } from '../../src/app.module.js';
import { configureApp } from '../../src/app.factory.js';
import { OTP_SENDER } from '../../src/auth/otp/otp-sender.js';
import type { AuthSession } from '../../src/auth/auth.service.js';
import { InMemoryOtpSender } from './in-memory-otp-sender.js';

export interface TestApp {
  app: INestApplication;
  http: () => ReturnType<typeof request>;
  reset: () => Promise<void>;
  ds: DataSource;
  otp: InMemoryOtpSender;
}

/** Démarre l'application complète contre la base de test (schéma isolé). */
export async function bootTestApp(
  overrides: (b: TestingModuleBuilder) => TestingModuleBuilder = (b) => b,
): Promise<TestApp> {
  const otp = new InMemoryOtpSender();
  const builder = overrides(
    Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(OTP_SENDER)
      .useValue(otp),
  );
  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication();
  configureApp(app);
  await app.init();
  const ds = app.get(DataSource);

  const reset = async () => {
    const schema = process.env.DATABASE_SCHEMA ?? 'public';
    const tables: { tablename: string }[] = await ds.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = $1 AND tablename NOT IN ('migrations', 'spatial_ref_sys')`,
      [schema],
    );
    if (tables.length) {
      await ds.query(`TRUNCATE ${tables.map((t) => `"${schema}"."${t.tablename}"`).join(', ')} RESTART IDENTITY CASCADE`);
    }
  };
  await reset();

  return { app, http: () => request(app.getHttpServer()), reset, ds, otp };
}

/** Connexion complète (demande de code + vérification). `name` sert à la création du compte. */
export async function loginAs(t: TestApp, phone: string, name = 'Utilisateur Test'): Promise<AuthSession> {
  await t.http().post('/v1/auth/otp/request').send({ phone }).expect(202);
  const e164 = t.otp.sent[t.otp.sent.length - 1].phone;
  const res = await t
    .http()
    .post('/v1/auth/otp/verify')
    .send({ phone, code: t.otp.lastCodeFor(e164), name })
    .expect(200);
  // Antidate les codes pour pouvoir se reconnecter avec ce numéro sans attendre la minute de délai.
  await t.ds.query(`UPDATE otp_challenges SET created_at = created_at - interval '1 hour' WHERE phone = $1`, [e164]);
  return res.body as AuthSession;
}

/** En-tête d'authentification. */
export const bearer = (s: AuthSession) => ({ Authorization: `Bearer ${s.accessToken}` });

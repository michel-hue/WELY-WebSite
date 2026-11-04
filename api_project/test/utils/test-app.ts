import { Test, type TestingModuleBuilder } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { AppModule } from '../../src/app.module.js';
import { configureApp } from '../../src/app.factory.js';

export interface TestApp {
  app: INestApplication;
  http: () => ReturnType<typeof request>;
  reset: () => Promise<void>;
  ds: DataSource;
}

/** Démarre l'application complète contre la base de test (TEST_DATABASE_URL). */
export async function bootTestApp(
  overrides: (b: TestingModuleBuilder) => TestingModuleBuilder = (b) => b,
): Promise<TestApp> {
  const builder = overrides(Test.createTestingModule({ imports: [AppModule] }));
  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication();
  configureApp(app);
  await app.init();
  const ds = app.get(DataSource);

  const reset = async () => {
    const tables: { tablename: string }[] = await ds.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('migrations', 'spatial_ref_sys')`,
    );
    if (tables.length) {
      await ds.query(`TRUNCATE ${tables.map((t) => `"${t.tablename}"`).join(', ')} RESTART IDENTITY CASCADE`);
    }
  };
  await reset();

  return { app, http: () => request(app.getHttpServer()), reset, ds };
}

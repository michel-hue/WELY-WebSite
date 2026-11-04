import type { MigrationInterface, QueryRunner } from 'typeorm';

export class Extensions1730700000000 implements MigrationInterface {
  name = 'Extensions1730700000000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public`);
    await q.query(`CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA public`);
    await q.query(`CREATE EXTENSION IF NOT EXISTS unaccent SCHEMA public`);
    await q.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public`);
    // unaccent() n'est pas IMMUTABLE : ce wrapper permet de l'utiliser dans des index.
    await q.query(`
      CREATE OR REPLACE FUNCTION f_unaccent(text) RETURNS text
      LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
      AS $$ SELECT public.unaccent('public.unaccent'::regdictionary, $1) $$`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP FUNCTION IF EXISTS f_unaccent(text)`);
  }
}

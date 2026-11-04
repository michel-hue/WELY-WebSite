import type { MigrationInterface, QueryRunner } from 'typeorm';

export class SearchIndex1730700005000 implements MigrationInterface {
  name = 'SearchIndex1730700005000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public`);
    // Même expression que la recherche texte (search.service.ts), pour que l'index serve.
    await q.query(`
      CREATE INDEX listings_text_trgm ON listings
      USING gin (f_unaccent(lower(title || ' ' || district || ' ' || city || ' ' || description)) gin_trgm_ops)`);
    await q.query(`CREATE INDEX listings_published_at ON listings (published_at DESC) WHERE status = 'online'`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP INDEX listings_published_at`);
    await q.query(`DROP INDEX listings_text_trgm`);
  }
}

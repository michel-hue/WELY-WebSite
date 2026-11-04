import type { MigrationInterface, QueryRunner } from 'typeorm';

export class FavoritesReports1730700006000 implements MigrationInterface {
  name = 'FavoritesReports1730700006000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE favorites (
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
        created_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (user_id, listing_id)
      )`);

    await q.query(`
      CREATE TABLE reports (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
        user_id uuid REFERENCES users(id) ON DELETE SET NULL,
        installation_id uuid,
        reason varchar(20) NOT NULL
          CHECK (reason IN ('scam', 'misleading_price', 'misleading_photos', 'unavailable', 'other')),
        comment varchar(500),
        created_at timestamptz NOT NULL DEFAULT now(),
        CHECK (user_id IS NOT NULL OR installation_id IS NOT NULL)
      )`);
    await q.query(`CREATE INDEX reports_listing ON reports (listing_id)`);
    await q.query(`CREATE INDEX reports_user ON reports (user_id) WHERE user_id IS NOT NULL`);
    await q.query(`CREATE INDEX reports_installation ON reports (installation_id) WHERE installation_id IS NOT NULL`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE reports`);
    await q.query(`DROP TABLE favorites`);
  }
}

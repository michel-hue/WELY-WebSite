import type { MigrationInterface, QueryRunner } from 'typeorm';

export class Photos1730700004000 implements MigrationInterface {
  name = 'Photos1730700004000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE listing_photos (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
        position int NOT NULL,
        thumb_key varchar(200) NOT NULL,
        large_key varchar(200) NOT NULL,
        width int NOT NULL,
        height int NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      )`);
    await q.query(`CREATE INDEX listing_photos_listing_position ON listing_photos (listing_id, position)`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE listing_photos`);
  }
}

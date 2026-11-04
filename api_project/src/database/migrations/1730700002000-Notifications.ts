import type { MigrationInterface, QueryRunner } from 'typeorm';

export class Notifications1730700002000 implements MigrationInterface {
  name = 'Notifications1730700002000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE notifications (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type varchar(40) NOT NULL,
        title varchar(120) NOT NULL,
        body varchar(500) NOT NULL,
        listing_id uuid,
        request_id uuid,
        reason varchar(40),
        read_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now()
      )`);
    await q.query(`CREATE INDEX notifications_user_created ON notifications (user_id, created_at DESC)`);

    await q.query(`
      CREATE TABLE devices (
        token varchar(255) PRIMARY KEY,
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        platform varchar(10) NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      )`);
    await q.query(`CREATE INDEX devices_user ON devices (user_id)`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE devices`);
    await q.query(`DROP TABLE notifications`);
  }
}

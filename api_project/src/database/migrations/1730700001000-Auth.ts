import type { MigrationInterface, QueryRunner } from 'typeorm';

export class Auth1730700001000 implements MigrationInterface {
  name = 'Auth1730700001000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE users (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        phone varchar(20),
        name varchar(60) NOT NULL,
        avatar_url varchar(500),
        whatsapp_phone varchar(20),
        is_seller boolean NOT NULL DEFAULT false,
        created_at timestamptz NOT NULL DEFAULT now(),
        deleted_at timestamptz
      )`);
    await q.query(`CREATE UNIQUE INDEX users_phone_unique ON users (phone) WHERE phone IS NOT NULL`);

    await q.query(`
      CREATE TABLE otp_challenges (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        phone varchar(20) NOT NULL,
        code_hash varchar(64) NOT NULL,
        channel varchar(10) NOT NULL,
        attempts int NOT NULL DEFAULT 0,
        expires_at timestamptz NOT NULL,
        consumed_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now()
      )`);
    await q.query(`CREATE INDEX otp_challenges_phone_created ON otp_challenges (phone, created_at)`);

    await q.query(`
      CREATE TABLE refresh_tokens (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        family_id uuid NOT NULL,
        token_hash varchar(64) NOT NULL UNIQUE,
        expires_at timestamptz NOT NULL,
        revoked_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now()
      )`);
    await q.query(`CREATE INDEX refresh_tokens_user ON refresh_tokens (user_id)`);
    await q.query(`CREATE INDEX refresh_tokens_family ON refresh_tokens (family_id)`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE refresh_tokens`);
    await q.query(`DROP TABLE otp_challenges`);
    await q.query(`DROP TABLE users`);
  }
}

import type { MigrationInterface, QueryRunner } from 'typeorm';

export class Requests1730700007000 implements MigrationInterface {
  name = 'Requests1730700007000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE listing_requests (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        listing_id uuid NOT NULL REFERENCES listings(id),
        buyer_id uuid NOT NULL REFERENCES users(id),
        offer_type varchar(10) NOT NULL CHECK (offer_type IN ('monthly', 'nightly', 'sale')),
        check_in date,
        check_out date,
        move_in_date date,
        wants_visit boolean NOT NULL DEFAULT false,
        message varchar(1000),
        status varchar(10) NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'accepted', 'refused', 'cancelled')),
        refusal_reason varchar(20) CHECK (refusal_reason IN ('seller', 'dates_unavailable', 'listing_unavailable')),
        seller_message varchar(1000),
        created_at timestamptz NOT NULL DEFAULT now(),
        decided_at timestamptz,
        CHECK (offer_type <> 'nightly' OR (check_in IS NOT NULL AND check_out > check_in))
      )`);
    await q.query(`CREATE INDEX listing_requests_listing ON listing_requests (listing_id, status)`);
    await q.query(`CREATE INDEX listing_requests_buyer ON listing_requests (buyer_id, created_at DESC)`);
    // Une seule demande en attente par acheteur et par annonce.
    await q.query(`CREATE UNIQUE INDEX listing_requests_one_pending ON listing_requests (listing_id, buyer_id) WHERE status = 'pending'`);

    // Nuits bloquées par les séjours acceptés : deux séjours d'une même annonce ne peuvent pas se chevaucher.
    await q.query(`
      CREATE TABLE blocked_stays (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
        request_id uuid NOT NULL UNIQUE REFERENCES listing_requests(id) ON DELETE CASCADE,
        nights daterange NOT NULL,
        EXCLUDE USING gist (listing_id WITH =, nights WITH &&)
      )`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE blocked_stays`);
    await q.query(`DROP TABLE listing_requests`);
  }
}

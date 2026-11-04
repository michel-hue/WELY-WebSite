import type { MigrationInterface, QueryRunner } from 'typeorm';

export class Listings1730700003000 implements MigrationInterface {
  name = 'Listings1730700003000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE listings (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        owner_id uuid NOT NULL REFERENCES users(id),
        title varchar(120) NOT NULL,
        description text NOT NULL DEFAULT '',
        property_type varchar(20) NOT NULL,
        rooms int NOT NULL DEFAULT 0,
        bedrooms int,
        bathrooms int,
        surface_m2 int,
        amenities text[] NOT NULL DEFAULT '{}',
        city varchar(80) NOT NULL,
        district varchar(120) NOT NULL,
        address varchar(200),
        location geography(Point, 4326),
        monthly_rent int CHECK (monthly_rent > 0),
        monthly_terms varchar(300),
        nightly_price int CHECK (nightly_price > 0),
        min_nights int CHECK (min_nights >= 1),
        sale_price int CHECK (sale_price > 0),
        status varchar(12) NOT NULL DEFAULT 'draft'
          CHECK (status IN ('draft', 'online', 'expired', 'deactivated', 'closed')),
        closed_reason varchar(10) CHECK (closed_reason IN ('rented', 'sold')),
        published_until date,
        published_at timestamptz,
        expiry_reminder_sent_at timestamptz,
        view_count int NOT NULL DEFAULT 0,
        contact_click_count int NOT NULL DEFAULT 0,
        request_count int NOT NULL DEFAULT 0,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        deleted_at timestamptz
      )`);
    await q.query(`CREATE INDEX listings_owner ON listings (owner_id)`);
    await q.query(`CREATE INDEX listings_status ON listings (status) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX listings_location ON listings USING gist (location)`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE listings`);
  }
}

import type { MigrationInterface, QueryRunner } from 'typeorm';

/** Un prix de vente peut dépasser 2,1 milliards de FCFA (limite de « int »). */
export class SalePriceBigint1730700008000 implements MigrationInterface {
  name = 'SalePriceBigint1730700008000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE listings ALTER COLUMN sale_price TYPE bigint`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE listings ALTER COLUMN sale_price TYPE int`);
  }
}

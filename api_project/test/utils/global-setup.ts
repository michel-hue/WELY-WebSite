import pg from 'pg';

/** Crée le schéma isolé des tests avant toute migration. */
export default async function setup() {
  const schema = process.env.DATABASE_SCHEMA ?? 'welly_test';
  if (!/^[a-z_][a-z0-9_]*$/.test(schema)) throw new Error(`Nom de schéma invalide : ${schema}`);
  const client = new pg.Client({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_SSL === 'false' ? false : { rejectUnauthorized: false },
  });
  await client.connect();
  try {
    await client.query(`CREATE SCHEMA IF NOT EXISTS ${schema}`);
  } finally {
    await client.end();
  }
}

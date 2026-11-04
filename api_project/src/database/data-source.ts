import 'reflect-metadata';
import { DataSource, type DataSourceOptions } from 'typeorm';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

/**
 * Options TypeORM partagées par l'application et la CLI de migrations.
 * `schema` ≠ public : utilisé par les tests e2e (schéma isolé dans la même base) ;
 * les extensions restent dans `public`, d'où le search_path « <schema>, public ».
 */
export function dataSourceOptions(url: string, ssl: boolean, schema = 'public'): DataSourceOptions {
  return {
    type: 'postgres',
    url,
    ssl: ssl ? { rejectUnauthorized: false } : false,
    schema,
    synchronize: false,
    migrationsRun: true,
    migrations: [join(here, 'migrations', '*.{js,ts}')],
    entities: [join(here, '..', '**', '*.entity.{js,ts}')],
    extra: schema === 'public' ? {} : { options: `-c search_path=${schema},public` },
  };
}

// Utilisé par `npm run migration:*` (à exécuter après `npm run build`).
export default new DataSource(
  dataSourceOptions(
    process.env.DATABASE_URL ?? '',
    (process.env.DATABASE_SSL ?? 'true') !== 'false',
    process.env.DATABASE_SCHEMA ?? 'public',
  ),
);

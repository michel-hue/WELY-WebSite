import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { dataSourceOptions } from './data-source.js';
import type { Env } from '../config/env.validation.js';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService<Env, true>) => ({
        ...dataSourceOptions(
          cfg.get('DATABASE_URL', { infer: true }),
          cfg.get('DATABASE_SSL', { infer: true }),
          cfg.get('DATABASE_SCHEMA', { infer: true }),
        ),
        autoLoadEntities: true,
      }),
    }),
  ],
  exports: [TypeOrmModule],
})
export class DatabaseModule {}

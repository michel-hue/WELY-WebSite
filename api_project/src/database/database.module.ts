import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../users/user.entity.js';
import { Listing } from '../listings/listing.entity.js';
import { Reservation } from '../reservations/reservation.entity.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        type: 'postgres',
        url: cfg.get<string>('DATABASE_URL'),
        autoLoadEntities: true,
        synchronize: cfg.get<string>('DB_SYNCHRONIZE') === 'true',
        ssl: { rejectUnauthorized: false },
        entities: [User, Listing, Reservation],
      }),
    }),
  ],
  exports: [TypeOrmModule],
})
export class DatabaseModule {}
import { Module } from '@nestjs/common';
import { DatabaseModule } from './database/database.module.js';
import { UsersModule } from './users/users.module.js';
import { AuthModule } from './auth/auth.module.js';
import { ListingsModule } from './listings/listings.module.js';
import { ReservationsModule } from './reservations/reservations.module.js';

export const ObserveInstrument = false;

@Module({
  imports: [DatabaseModule, UsersModule, AuthModule, ListingsModule, ReservationsModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
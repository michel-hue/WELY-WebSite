import { Module } from '@nestjs/common';
import { FavoritesModule } from '../favorites/favorites.module.js';
import { ListingsModule } from '../listings/listings.module.js';
import { RequestsModule } from '../requests/requests.module.js';
import { UsersModule } from '../users/users.module.js';
import { AccountController } from './account.controller.js';
import { AccountService } from './account.service.js';

/** Suppression de compte : dépend de presque tous les domaines, d'où un module à part. */
@Module({
  imports: [UsersModule, ListingsModule, RequestsModule, FavoritesModule],
  controllers: [AccountController],
  providers: [AccountService],
})
export class AccountModule {}

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersModule } from '../users/users.module.js';
import { Listing } from './listing.entity.js';
import { ListingsService } from './listings.service.js';
import { SellerListingsController } from './seller-listings.controller.js';

@Module({
  imports: [TypeOrmModule.forFeature([Listing]), UsersModule],
  controllers: [SellerListingsController],
  providers: [ListingsService],
  exports: [ListingsService],
})
export class ListingsModule {}

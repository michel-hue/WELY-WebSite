import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Listing } from '../listings/listing.entity.js';
import { ListingsModule } from '../listings/listings.module.js';
import { UsersModule } from '../users/users.module.js';
import { PublicListingsController } from './public-listings.controller.js';
import { SearchService } from './search.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([Listing]), ListingsModule, UsersModule],
  controllers: [PublicListingsController],
  providers: [SearchService],
  exports: [SearchService],
})
export class SearchModule {}

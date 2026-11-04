import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Listing } from './listing.entity.js';
import { ListingsService } from './listings.service.js';
import { ListingsController } from './listings.controller.js';

@Module({
  imports: [TypeOrmModule.forFeature([Listing])],
  providers: [ListingsService],
  controllers: [ListingsController],
  exports: [ListingsService],
})
export class ListingsModule {}
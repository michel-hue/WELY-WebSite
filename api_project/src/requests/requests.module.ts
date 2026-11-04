import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Listing } from '../listings/listing.entity.js';
import { SearchModule } from '../search/search.module.js';
import { User } from '../users/user.entity.js';
import { ListingRequest } from './listing-request.entity.js';
import { RequestsController } from './requests.controller.js';
import { RequestsService } from './requests.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([ListingRequest, Listing, User]), SearchModule],
  controllers: [RequestsController],
  providers: [RequestsService],
  exports: [RequestsService],
})
export class RequestsModule {}

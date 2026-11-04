import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Listing } from '../listings/listing.entity.js';
import { Report } from '../reports/report.entity.js';
import { ReportsController } from '../reports/reports.controller.js';
import { ReportsService } from '../reports/reports.service.js';
import { SearchModule } from '../search/search.module.js';
import { Favorite } from './favorite.entity.js';
import { FavoritesController } from './favorites.controller.js';
import { FavoritesService } from './favorites.service.js';

/** Favoris et signalements : deux fonctions de l'acheteur bâties sur la recherche publique. */
@Module({
  imports: [TypeOrmModule.forFeature([Favorite, Report, Listing]), SearchModule],
  controllers: [FavoritesController, ReportsController],
  providers: [FavoritesService, ReportsService],
  exports: [FavoritesService],
})
export class FavoritesModule {}

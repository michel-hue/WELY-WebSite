import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsUUID } from 'class-validator';
import { JwtAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { PaginationQuery } from '../common/pagination/paginated.js';
import { FavoritesService } from './favorites.service.js';

class MergeFavoritesDto {
  @IsArray()
  @ArrayMaxSize(200)
  @IsUUID('all', { each: true })
  listingIds!: string[];
}

@ApiTags('favoris')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('me/favorites')
export class FavoritesController {
  constructor(private readonly favorites: FavoritesService) {}

  @Get()
  @ApiOperation({ summary: 'Mes favoris encore disponibles' })
  list(@CurrentUser() u: AuthUser, @Query() q: PaginationQuery) {
    return this.favorites.list(u.id, q.cursor, q.limit);
  }

  @Post('merge')
  @HttpCode(204)
  @ApiOperation({ summary: 'Fusionner les favoris gardés sur le téléphone avant la connexion' })
  async merge(@CurrentUser() u: AuthUser, @Body() dto: MergeFavoritesDto) {
    await this.favorites.merge(u.id, dto.listingIds);
  }

  @Put(':listingId')
  @HttpCode(204)
  async add(@CurrentUser() u: AuthUser, @Param('listingId', ParseUUIDPipe) listingId: string) {
    await this.favorites.add(u.id, listingId);
  }

  @Delete(':listingId')
  @HttpCode(204)
  async remove(@CurrentUser() u: AuthUser, @Param('listingId', ParseUUIDPipe) listingId: string) {
    await this.favorites.remove(u.id, listingId);
  }
}

import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { CloseDto, CreateListingDto, MyListingsQuery, PublishDto, UpdateListingDto } from './dto/listing.dto.js';
import { ListingsService } from './listings.service.js';

@ApiTags('annonces (vendeur)')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class SellerListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Post('listings')
  @ApiOperation({ summary: 'Créer une annonce (brouillon)' })
  async create(@CurrentUser() u: AuthUser, @Body() dto: CreateListingDto) {
    return this.listings.toDto(await this.listings.create(u.id, dto));
  }

  @Patch('listings/:id')
  @ApiOperation({ summary: 'Modifier une annonce ; une offre à null est retirée' })
  async update(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateListingDto) {
    return this.listings.toDto(await this.listings.update(u.id, id, dto));
  }

  @Post('listings/:id/publish')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mettre en ligne (date de fin incluse, ou permanente)' })
  async publish(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PublishDto) {
    return this.listings.toDto(await this.listings.publish(u.id, id, dto.until));
  }

  @Post('listings/:id/reactivate')
  @HttpCode(200)
  @ApiOperation({ summary: 'Remettre en ligne une annonce expirée, désactivée ou close' })
  async reactivate(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PublishDto) {
    return this.listings.toDto(await this.listings.reactivate(u.id, id, dto.until));
  }

  @Post('listings/:id/extend')
  @HttpCode(200)
  @ApiOperation({ summary: 'Prolonger une annonce en ligne (nouvelle date de fin, ou permanente)' })
  async extend(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PublishDto) {
    return this.listings.toDto(await this.listings.extend(u.id, id, dto.until));
  }

  @Post('listings/:id/deactivate')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mettre hors ligne' })
  async deactivate(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.listings.toDto(await this.listings.deactivate(u.id, id));
  }

  @Post('listings/:id/close')
  @HttpCode(200)
  @ApiOperation({ summary: 'Marquer comme loué ou vendu' })
  async close(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CloseDto) {
    return this.listings.toDto(await this.listings.close(u.id, id, dto.reason));
  }

  @Delete('listings/:id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Supprimer une annonce' })
  async remove(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.listings.remove(u.id, id);
  }

  @Get('me/listings')
  @ApiOperation({ summary: 'Mes annonces' })
  mine(@CurrentUser() u: AuthUser, @Query() q: MyListingsQuery) {
    return this.listings.listMine(u.id, q.status, q.cursor, q.limit);
  }

  @Get('me/listings/:id')
  @ApiOperation({ summary: 'Une de mes annonces, avec ses compteurs' })
  async one(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.listings.toDto(await this.listings.findOwned(id, u.id));
  }
}

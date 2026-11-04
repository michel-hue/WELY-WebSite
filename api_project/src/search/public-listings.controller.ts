import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn } from 'class-validator';
import { OptionalAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { InstallationId } from '../common/http/installation-id.decorator.js';
import { SearchQuery } from './search-query.dto.js';
import { SearchService } from './search.service.js';

class ContactClickDto {
  @IsIn(['whatsapp', 'call'])
  channel!: 'whatsapp' | 'call';
}

@ApiTags('consultation')
@UseGuards(OptionalAuthGuard)
@Controller()
export class PublicListingsController {
  constructor(private readonly search: SearchService) {}

  @Get('listings')
  @ApiOperation({ summary: 'Rechercher des annonces (autour de moi, texte, filtres)' })
  list(@Query() q: SearchQuery, @CurrentUser() user?: AuthUser, @InstallationId() installationId?: string) {
    return this.search.search(q, { userId: user?.id, installationId });
  }

  @Get('listings/:id')
  @ApiOperation({ summary: 'Fiche d’une annonce, avec les coordonnées du vendeur' })
  one(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user?: AuthUser, @InstallationId() installationId?: string) {
    return this.search.findPublic(id, { userId: user?.id, installationId });
  }

  @Post('listings/:id/contact-clicks')
  @HttpCode(204)
  @ApiOperation({ summary: 'Signaler un clic sur WhatsApp ou Appeler (statistiques du vendeur)' })
  async click(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ContactClickDto) {
    void dto;
    await this.search.recordContactClick(id);
  }

  @Get('locations')
  @ApiOperation({ summary: 'Villes et quartiers ayant des annonces en ligne' })
  locations() {
    return this.search.locations();
  }
}

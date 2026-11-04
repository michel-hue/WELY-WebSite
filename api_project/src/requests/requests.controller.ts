import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { CreateRequestDto, DecisionDto, RequestsQuery } from './dto/request.dto.js';
import { RequestsService } from './requests.service.js';

@ApiTags('demandes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class RequestsController {
  constructor(private readonly requests: RequestsService) {}

  @Post('requests')
  @ApiOperation({ summary: 'Faire une demande (mois, nuit avec dates, ou achat). Le vendeur reçoit votre nom et numéro.' })
  create(@CurrentUser() u: AuthUser, @Body() dto: CreateRequestDto) {
    return this.requests.create(u.id, dto);
  }

  @Get('me/requests')
  @ApiOperation({ summary: 'Mes demandes (acheteur)' })
  mine(@CurrentUser() u: AuthUser, @Query() q: RequestsQuery) {
    return this.requests.listForBuyer(u.id, q.status, q.cursor, q.limit);
  }

  @Get('me/received-requests')
  @ApiOperation({ summary: 'Demandes reçues sur mes annonces (vendeur), avec le contact de l’acheteur' })
  received(@CurrentUser() u: AuthUser, @Query() q: RequestsQuery) {
    return this.requests.listForSeller(u.id, q.status, q.listingId, q.cursor, q.limit);
  }

  @Post('requests/:id/accept')
  @HttpCode(200)
  @ApiOperation({ summary: 'Accepter (vendeur). À la nuit : bloque les dates et refuse les demandes qui chevauchent.' })
  accept(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: DecisionDto) {
    return this.requests.accept(u.id, id, dto.message);
  }

  @Post('requests/:id/refuse')
  @HttpCode(200)
  @ApiOperation({ summary: 'Refuser (vendeur)' })
  refuse(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: DecisionDto) {
    return this.requests.refuse(u.id, id, dto.message);
  }

  @Post('requests/:id/cancel')
  @HttpCode(200)
  @ApiOperation({ summary: 'Annuler ma demande (acheteur) ; libère les dates d’un séjour accepté' })
  cancel(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.requests.cancel(u.id, id);
  }
}

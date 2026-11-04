import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { ReservationsService } from './reservations.service.js';
import { JwtAuthGuard } from '../common/jwt-auth.guard.js';
import { CreateReservationDto } from './dto/create-reservation.dto.js';
import { UpdateReservationStatusDto } from './dto/update-reservation-status.dto.js';
import { ReservationStatus } from './reservation.entity.js';

@Controller('reservations')
export class ReservationsController {
  constructor(private readonly service: ReservationsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(@Body() dto: CreateReservationDto, @Req() req: any) {
    return this.service.create(dto.listingId, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  findMine(@Req() req: any) {
    return this.service.findMine(req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  findOne(@Param('id') id: string, @Req() req: any) {
    return this.service.findOne(id, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateReservationStatusDto, @Req() req: any) {
    return this.service.updateStatus(id, dto.status, req.user.id);
  }
}
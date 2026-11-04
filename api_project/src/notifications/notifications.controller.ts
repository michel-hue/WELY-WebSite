import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn } from 'class-validator';
import { JwtAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { PaginationQuery } from '../common/pagination/paginated.js';
import { NotificationsService } from './notifications.service.js';

class DeviceDto {
  @IsIn(['ios', 'android'])
  platform!: 'ios' | 'android';
}

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('me')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('notifications')
  @ApiOperation({ summary: 'Mes notifications, plus récentes d’abord' })
  list(@CurrentUser() u: AuthUser, @Query() q: PaginationQuery) {
    return this.notifications.list(u.id, q.cursor, q.limit);
  }

  @Get('notifications/unread-count')
  async unread(@CurrentUser() u: AuthUser) {
    return { count: await this.notifications.unreadCount(u.id) };
  }

  @Post('notifications/read-all')
  @HttpCode(204)
  async readAll(@CurrentUser() u: AuthUser) {
    await this.notifications.markAllRead(u.id);
  }

  @Post('notifications/:id/read')
  @HttpCode(204)
  async read(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.notifications.markRead(u.id, id);
  }

  @Put('devices/:token')
  @HttpCode(204)
  @ApiOperation({ summary: 'Enregistrer cet appareil pour les push (jeton FCM)' })
  async register(@CurrentUser() u: AuthUser, @Param('token') token: string, @Body() dto: DeviceDto) {
    await this.notifications.registerDevice(u.id, token.slice(0, 255), dto.platform);
  }

  @Delete('devices/:token')
  @HttpCode(204)
  async unregister(@CurrentUser() u: AuthUser, @Param('token') token: string) {
    await this.notifications.removeDevice(u.id, token);
  }
}

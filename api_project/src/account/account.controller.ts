import { Controller, Delete, HttpCode, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { AccountService } from './account.service.js';

@ApiTags('compte')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('me')
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Delete()
  @HttpCode(204)
  @ApiOperation({ summary: 'Supprimer mon compte (annonces retirées, données anonymisées)' })
  async remove(@CurrentUser() u: AuthUser) {
    await this.account.deleteAccount(u.id);
  }
}

import { Body, Controller, Get, Patch, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { normalizePhone } from '../auth/phone.js';
import { SellerModeDto, UpdateMeDto } from './dto/update-me.dto.js';
import { toMeDto, type MeDto } from './me.dto.js';
import { UsersService } from './users.service.js';

@ApiTags('compte')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('me')
export class MeController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @ApiOperation({ summary: 'Mon profil' })
  async me(@CurrentUser() auth: AuthUser): Promise<MeDto> {
    return toMeDto(await this.users.getActive(auth.id));
  }

  @Patch()
  @ApiOperation({ summary: 'Modifier mon profil' })
  async update(@CurrentUser() auth: AuthUser, @Body() dto: UpdateMeDto): Promise<MeDto> {
    const user = await this.users.getActive(auth.id);
    if (dto.name !== undefined) user.name = dto.name.trim();
    if (dto.whatsappPhone !== undefined) user.whatsappPhone = dto.whatsappPhone === null ? null : normalizePhone(dto.whatsappPhone);
    if (dto.avatarUrl !== undefined) user.avatarUrl = dto.avatarUrl;
    return toMeDto(await this.users.repo.save(user));
  }

  @Put('seller-mode')
  @ApiOperation({ summary: 'Activer / désactiver le mode vendeur (les annonces restent en ligne)' })
  async sellerMode(@CurrentUser() auth: AuthUser, @Body() dto: SellerModeDto): Promise<MeDto> {
    const user = await this.users.getActive(auth.id);
    user.isSeller = dto.enabled;
    return toMeDto(await this.users.repo.save(user));
  }
}

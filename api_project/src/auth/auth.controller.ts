import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service.js';
import { RefreshDto, RequestOtpDto, VerifyOtpDto } from './dto/auth.dto.js';

const OTP_IP_LIMIT = Number(process.env.OTP_IP_LIMIT_PER_MIN ?? 5);

@ApiTags('connexion')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/request')
  @HttpCode(202)
  @Throttle({ default: { limit: OTP_IP_LIMIT, ttl: 60_000 } })
  @ApiOperation({ summary: 'Envoie un code de connexion par SMS ou WhatsApp' })
  request(@Body() dto: RequestOtpDto) {
    return this.auth.requestOtp(dto.phone, dto.channel);
  }

  @Post('otp/verify')
  @HttpCode(200)
  @ApiOperation({ summary: 'Vérifie le code ; crée le compte au premier passage (nom requis)' })
  verify(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto.phone, dto.code, dto.name);
  }

  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({ summary: 'Renouvelle la session (rotation du jeton de rafraîchissement)' })
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(204)
  @ApiOperation({ summary: 'Ferme la session' })
  async logout(@Body() dto: RefreshDto) {
    await this.auth.logout(dto.refreshToken);
  }
}

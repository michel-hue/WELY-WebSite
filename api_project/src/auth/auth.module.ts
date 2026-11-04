import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import type { Env } from '../config/env.validation.js';
import { JwtAuthGuard, OptionalAuthGuard } from '../common/auth/jwt-auth.guard.js';
import { UsersModule } from '../users/users.module.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { OtpChallenge } from './otp-challenge.entity.js';
import { ConsoleOtpSender } from './otp/console-otp-sender.js';
import { OTP_SENDER } from './otp/otp-sender.js';
import { TwilioOtpSender } from './otp/twilio-otp-sender.js';
import { RefreshToken } from './refresh-token.entity.js';

/** Global : les gardes d'authentification sont utilisables dans tous les modules. */
@Global()
@Module({
  imports: [
    UsersModule,
    TypeOrmModule.forFeature([OtpChallenge, RefreshToken]),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService<Env, true>) => ({
        secret: cfg.get('JWT_SECRET', { infer: true }),
        signOptions: { expiresIn: cfg.get('JWT_ACCESS_TTL', { infer: true }) as `${number}m` },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtAuthGuard,
    OptionalAuthGuard,
    {
      provide: OTP_SENDER,
      inject: [ConfigService],
      useFactory: (cfg: ConfigService<Env, true>) =>
        cfg.get('OTP_PROVIDER', { infer: true }) === 'twilio'
          ? new TwilioOtpSender({
              accountSid: cfg.get('TWILIO_ACCOUNT_SID', { infer: true }) ?? '',
              authToken: cfg.get('TWILIO_AUTH_TOKEN', { infer: true }) ?? '',
              smsFrom: cfg.get('TWILIO_SMS_FROM', { infer: true }),
              whatsappFrom: cfg.get('TWILIO_WHATSAPP_FROM', { infer: true }),
            })
          : new ConsoleOtpSender(),
    },
  ],
  exports: [AuthService, JwtModule, JwtAuthGuard, OptionalAuthGuard],
})
export class AuthModule {}

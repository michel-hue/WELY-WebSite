import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import type { Env } from '../config/env.validation.js';
import { Device } from './device.entity.js';
import { Notification } from './notification.entity.js';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';
import { FcmPushSender } from './push/fcm-push-sender.js';
import { LogPushSender } from './push/log-push-sender.js';
import { PUSH_SENDER } from './push/push-sender.js';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([Notification, Device])],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    {
      provide: PUSH_SENDER,
      inject: [ConfigService],
      useFactory: (cfg: ConfigService<Env, true>) =>
        cfg.get('PUSH_PROVIDER', { infer: true }) === 'fcm'
          ? new FcmPushSender(cfg.get('FCM_SERVICE_ACCOUNT_JSON', { infer: true }) ?? '{}')
          : new LogPushSender(),
    },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}

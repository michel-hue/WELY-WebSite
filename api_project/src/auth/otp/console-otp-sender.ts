import { Logger } from '@nestjs/common';
import type { OtpChannel, OtpSender } from './otp-sender.js';

/** Développement : le code est simplement écrit dans les logs. */
export class ConsoleOtpSender implements OtpSender {
  private readonly logger = new Logger('OTP');

  async send(phone: string, code: string, channel: OtpChannel): Promise<void> {
    this.logger.log(`[${channel}] ${phone} → ${code}`);
  }
}

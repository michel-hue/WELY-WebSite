import { Logger } from '@nestjs/common';
import type { OtpChannel, OtpSender } from './otp-sender.js';

export interface TwilioConfig {
  accountSid: string;
  authToken: string;
  smsFrom?: string;
  whatsappFrom?: string;
}

/** Envoi réel par SMS ou WhatsApp via l'API Messages de Twilio. */
export class TwilioOtpSender implements OtpSender {
  private readonly logger = new Logger('OTP');

  constructor(private readonly cfg: TwilioConfig) {}

  async send(phone: string, code: string, channel: OtpChannel): Promise<void> {
    const from = channel === 'whatsapp' ? this.cfg.whatsappFrom : this.cfg.smsFrom;
    if (!from) throw new Error(`Expéditeur Twilio non configuré pour le canal ${channel}`);
    const prefix = channel === 'whatsapp' ? 'whatsapp:' : '';
    const body = new URLSearchParams({
      To: `${prefix}${phone}`,
      From: `${prefix}${from}`,
      Body: `Votre code WELLY : ${code}. Il expire dans 5 minutes.`,
    });
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${this.cfg.accountSid}/Messages.json`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${this.cfg.accountSid}:${this.cfg.authToken}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });
    if (!res.ok) {
      this.logger.error(`Échec d'envoi Twilio (${res.status}) : ${await res.text()}`);
      throw new Error('Envoi du code impossible');
    }
  }
}

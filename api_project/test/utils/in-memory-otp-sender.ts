import type { OtpChannel, OtpSender } from '../../src/auth/otp/otp-sender.js';

/** Capture les codes envoyés pour que les tests puissent se connecter. */
export class InMemoryOtpSender implements OtpSender {
  readonly sent: { phone: string; code: string; channel: OtpChannel }[] = [];

  async send(phone: string, code: string, channel: OtpChannel): Promise<void> {
    this.sent.push({ phone, code, channel });
  }

  lastCodeFor(phone: string): string {
    const found = [...this.sent].reverse().find((s) => s.phone === phone);
    if (!found) throw new Error(`Aucun code envoyé à ${phone}`);
    return found.code;
  }
}

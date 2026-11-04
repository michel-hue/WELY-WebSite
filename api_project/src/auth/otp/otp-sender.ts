export type OtpChannel = 'sms' | 'whatsapp';

/** Envoi d'un code de connexion. Implémentation choisie par OTP_PROVIDER. */
export interface OtpSender {
  send(phone: string, code: string, channel: OtpChannel): Promise<void>;
}

export const OTP_SENDER = Symbol('OTP_SENDER');

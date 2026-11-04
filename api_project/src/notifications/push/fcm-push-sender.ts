import { Logger } from '@nestjs/common';
import type { PushMessage, PushSender } from './push-sender.js';

type Messaging = {
  sendEachForMulticast(msg: {
    tokens: string[];
    notification: { title: string; body: string };
    data: Record<string, string>;
  }): Promise<{ responses: { success: boolean; error?: { code: string } }[] }>;
};

const INVALID_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Firebase Cloud Messaging. `firebase-admin` est chargé à la demande :
 * il n'est requis que si PUSH_PROVIDER=fcm (npm i firebase-admin).
 */
export class FcmPushSender implements PushSender {
  private readonly logger = new Logger('Push');
  private messaging?: Promise<Messaging>;

  constructor(private readonly serviceAccountJson: string) {}

  private load(): Promise<Messaging> {
    this.messaging ??= (async () => {
      const pkg = 'firebase-admin';
      const admin = (await import(pkg)).default;
      const app = admin.initializeApp({ credential: admin.credential.cert(JSON.parse(this.serviceAccountJson)) });
      return admin.messaging(app) as Messaging;
    })();
    return this.messaging;
  }

  async send(tokens: string[], message: PushMessage) {
    if (!tokens.length) return { invalidTokens: [] };
    const res = await (await this.load()).sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
    });
    const invalidTokens = res.responses.flatMap((r, i) => (!r.success && r.error && INVALID_CODES.has(r.error.code) ? [tokens[i]] : []));
    const failed = res.responses.filter((r) => !r.success).length;
    if (failed > invalidTokens.length) this.logger.warn(`${failed - invalidTokens.length} push en échec`);
    return { invalidTokens };
  }
}

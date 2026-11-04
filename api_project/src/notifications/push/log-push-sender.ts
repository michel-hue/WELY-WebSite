import { Logger } from '@nestjs/common';
import type { PushMessage, PushSender } from './push-sender.js';

/** Développement : les push sont seulement journalisés. */
export class LogPushSender implements PushSender {
  private readonly logger = new Logger('Push');

  async send(tokens: string[], message: PushMessage) {
    if (tokens.length) this.logger.log(`${tokens.length} appareil(s) ← ${message.title} — ${message.body}`);
    return { invalidTokens: [] };
  }
}

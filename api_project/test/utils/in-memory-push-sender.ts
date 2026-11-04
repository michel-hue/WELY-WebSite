import type { PushMessage, PushSender } from '../../src/notifications/push/push-sender.js';

/** Capture les push envoyés ; les jetons de `invalid` sont signalés comme expirés. */
export class InMemoryPushSender implements PushSender {
  readonly sent: { tokens: string[]; message: PushMessage }[] = [];
  readonly invalid = new Set<string>();

  async send(tokens: string[], message: PushMessage) {
    this.sent.push({ tokens, message });
    return { invalidTokens: tokens.filter((t) => this.invalid.has(t)) };
  }
}

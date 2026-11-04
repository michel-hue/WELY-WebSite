export interface PushMessage {
  title: string;
  body: string;
  data: Record<string, string>;
}

/** Envoi de notifications push. Implémentation choisie par PUSH_PROVIDER. */
export interface PushSender {
  send(tokens: string[], message: PushMessage): Promise<{ invalidTokens: string[] }>;
}

export const PUSH_SENDER = Symbol('PUSH_SENDER');

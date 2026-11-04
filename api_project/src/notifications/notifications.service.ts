import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Repository } from 'typeorm';
import { notFound } from '../common/errors/app-error.js';
import { decodeCursor, encodeCursor } from '../common/pagination/cursor.js';
import type { Paginated } from '../common/pagination/paginated.js';
import { Device } from './device.entity.js';
import { Notification, type NotificationType } from './notification.entity.js';
import { PUSH_SENDER, type PushSender } from './push/push-sender.js';

export interface NotificationData {
  title: string;
  body: string;
  listingId?: string;
  requestId?: string;
  reason?: string;
}

export interface NotificationDto {
  id: string;
  type: NotificationType;
  title: string;
  body: string;
  listingId: string | null;
  requestId: string | null;
  reason: string | null;
  readAt: string | null;
  createdAt: string;
}

const toDto = (n: Notification): NotificationDto => ({
  id: n.id,
  type: n.type,
  title: n.title,
  body: n.body,
  listingId: n.listingId,
  requestId: n.requestId,
  reason: n.reason,
  readAt: n.readAt?.toISOString() ?? null,
  createdAt: n.createdAt.toISOString(),
});

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger('Notifications');

  constructor(
    @InjectRepository(Notification) private readonly repo: Repository<Notification>,
    @InjectRepository(Device) private readonly devices: Repository<Device>,
    @Inject(PUSH_SENDER) private readonly push: PushSender,
  ) {}

  /** Enregistre la notification puis l'envoie en push. Un échec push n'est jamais propagé. */
  async notify(userId: string, type: NotificationType, data: NotificationData): Promise<void> {
    await this.repo.save(
      this.repo.create({
        userId,
        type,
        title: data.title,
        body: data.body,
        listingId: data.listingId ?? null,
        requestId: data.requestId ?? null,
        reason: data.reason ?? null,
      }),
    );
    try {
      const tokens = (await this.devices.find({ where: { userId } })).map((d) => d.token);
      if (!tokens.length) return;
      const payload: Record<string, string> = { type };
      for (const key of ['listingId', 'requestId', 'reason'] as const) if (data[key]) payload[key] = data[key]!;
      const { invalidTokens } = await this.push.send(tokens, { title: data.title, body: data.body, data: payload });
      if (invalidTokens.length) await this.devices.delete({ token: In(invalidTokens) });
    } catch (e) {
      this.logger.warn(`Push non envoyé : ${(e as Error).message}`);
    }
  }

  async list(userId: string, cursor: string | undefined, limit: number): Promise<Paginated<NotificationDto>> {
    // Tri et comparaison à la milliseconde : c'est la précision conservée dans le curseur.
    const ts = `date_trunc('milliseconds', n.created_at)`;
    const qb = this.repo
      .createQueryBuilder('n')
      .where('n.userId = :userId', { userId })
      .orderBy(ts, 'DESC')
      .addOrderBy('n.id', 'DESC')
      .take(limit + 1);
    if (cursor) {
      const c = decodeCursor(cursor);
      qb.andWhere(`(${ts}, n.id) < (:createdAt::timestamptz, :id::uuid)`, { createdAt: c.createdAt, id: c.id });
    }
    const rows = await qb.getMany();
    const page = rows.slice(0, limit);
    const last = page.at(-1);
    return {
      data: page.map(toDto),
      nextCursor: rows.length > limit && last ? encodeCursor({ createdAt: last.createdAt.toISOString(), id: last.id }) : null,
    };
  }

  unreadCount(userId: string): Promise<number> {
    return this.repo.count({ where: { userId, readAt: IsNull() } });
  }

  async markRead(userId: string, id: string): Promise<void> {
    const { affected } = await this.repo.update({ id, userId }, { readAt: () => 'COALESCE(read_at, now())' });
    if (!affected) throw notFound('NOTIFICATION_NOT_FOUND', 'Notification introuvable.');
  }

  async markAllRead(userId: string): Promise<void> {
    await this.repo.update({ userId, readAt: IsNull() }, { readAt: new Date() });
  }

  async registerDevice(userId: string, token: string, platform: 'ios' | 'android'): Promise<void> {
    await this.devices.upsert({ token, userId, platform }, ['token']);
  }

  async removeDevice(userId: string, token: string): Promise<void> {
    await this.devices.delete({ token, userId });
  }

  /** Supprime tous les appareils d'un utilisateur (suppression de compte). */
  async removeAllDevices(userId: string): Promise<void> {
    await this.devices.delete({ userId });
  }
}

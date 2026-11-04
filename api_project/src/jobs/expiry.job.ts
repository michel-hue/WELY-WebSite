import { Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Cron } from '@nestjs/schedule';
import { DataSource } from 'typeorm';
import { LISTING_UNAVAILABLE, type ListingUnavailableEvent } from '../common/events/domain-events.js';
import type { Env } from '../config/env.validation.js';
import { todayIso } from '../listings/listings.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';

/** Verrou PostgreSQL partagé par toutes les instances de l'API. */
const LOCK_KEY = 7346201;
const REMINDER_DAYS = 3;

type Row = { id: string; owner_id: string; title: string; published_until: string };

const frDate = (iso: string) => iso.split('-').reverse().join('/');

/**
 * Chaque matin (et au démarrage) :
 *  - les annonces dont la date de fin est passée deviennent « expirées » (le dernier jour est inclus) ;
 *  - les vendeurs sont prévenus 3 jours avant la fin.
 * Sûr avec plusieurs instances : verrou consultatif de transaction (libéré automatiquement,
 * même en cas d'erreur) ; idempotent : UPDATE … RETURNING ne renvoie chaque annonce qu'une fois.
 */
@Injectable()
export class ExpiryJob implements OnApplicationBootstrap {
  private readonly logger = new Logger('Expiration');

  constructor(
    private readonly ds: DataSource,
    private readonly events: EventEmitter2,
    private readonly notifications: NotificationsService,
    private readonly cfg: ConfigService<Env, true>,
  ) {}

  private get enabled() {
    return this.cfg.get('NODE_ENV', { infer: true }) !== 'test';
  }

  onApplicationBootstrap() {
    if (this.enabled) void this.run().catch((e: Error) => this.logger.error(e.stack));
  }

  @Cron('0 6 * * *', { timeZone: 'Africa/Abidjan' })
  async daily() {
    if (this.enabled) await this.run();
  }

  async run(now: Date = new Date()): Promise<{ expired: number; reminded: number }> {
    const today = todayIso(now);
    const result = await this.ds.transaction(async (m) => {
      const [{ locked }] = await m.query(`SELECT pg_try_advisory_xact_lock($1) AS locked`, [LOCK_KEY]);
      if (!locked) return null;
      const [expired]: [Row[], number] = await m.query(
        `UPDATE listings SET status = 'expired', updated_at = now()
         WHERE status = 'online' AND deleted_at IS NULL
           AND published_until IS NOT NULL AND published_until < $1::date
         RETURNING id, owner_id, title, published_until::text`,
        [today],
      );
      const [reminded]: [Row[], number] = await m.query(
        `UPDATE listings SET expiry_reminder_sent_at = now()
         WHERE status = 'online' AND deleted_at IS NULL AND expiry_reminder_sent_at IS NULL
           AND published_until IS NOT NULL
           AND published_until >= $1::date AND published_until <= $1::date + $2::int
         RETURNING id, owner_id, title, published_until::text`,
        [today, REMINDER_DAYS],
      );
      return { expired, reminded };
    });
    if (!result) return { expired: 0, reminded: 0 };

    // Effets après validation de la transaction.
    for (const l of result.expired) {
      await this.events.emitAsync(LISTING_UNAVAILABLE, { listingId: l.id } satisfies ListingUnavailableEvent);
      await this.notifications.notify(l.owner_id, 'listing_expired', {
        title: 'Annonce expirée',
        body: `Votre annonce « ${l.title} » a expiré. Réactivez-la quand vous voulez.`,
        listingId: l.id,
      });
    }
    for (const l of result.reminded) {
      await this.notifications.notify(l.owner_id, 'listing_expiring_soon', {
        title: 'Votre annonce expire bientôt',
        body: `« ${l.title} » sera retirée après le ${frDate(l.published_until)}. Prolongez-la si besoin.`,
        listingId: l.id,
      });
    }
    if (result.expired.length || result.reminded.length) {
      this.logger.log(`${result.expired.length} annonce(s) expirée(s), ${result.reminded.length} rappel(s) envoyé(s)`);
    }
    return { expired: result.expired.length, reminded: result.reminded.length };
  }
}

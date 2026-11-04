import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AuthService } from '../auth/auth.service.js';
import { FavoritesService } from '../favorites/favorites.service.js';
import { ListingsService } from '../listings/listings.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { RequestsService } from '../requests/requests.service.js';
import { UsersService } from '../users/users.service.js';

/**
 * Suppression de compte (exigée par l'App Store et Google Play) :
 * annonces retirées, demandes en cours annulées, sessions et appareils révoqués,
 * données personnelles anonymisées. Le numéro redevient libre.
 */
@Injectable()
export class AccountService {
  constructor(
    private readonly ds: DataSource,
    private readonly users: UsersService,
    private readonly listings: ListingsService,
    private readonly requests: RequestsService,
    private readonly favorites: FavoritesService,
    private readonly auth: AuthService,
    private readonly notifications: NotificationsService,
  ) {}

  async deleteAccount(userId: string): Promise<void> {
    await this.users.getActive(userId);

    const wasOnline: string[] = await this.ds.transaction(async (m) => {
      const [removed]: [{ id: string; status: string }[], number] = await m.query(
        `UPDATE listings l SET deleted_at = now()
         FROM (SELECT id, status FROM listings WHERE owner_id = $1 AND deleted_at IS NULL FOR UPDATE) old
         WHERE l.id = old.id
         RETURNING l.id, old.status`,
        [userId],
      );
      await m.query(
        `UPDATE users SET name = 'Utilisateur supprimé', phone = NULL, whatsapp_phone = NULL,
                          avatar_url = NULL, is_seller = false, deleted_at = now()
         WHERE id = $1`,
        [userId],
      );
      return removed.filter((l) => l.status === 'online').map((l) => l.id);
    });

    await this.auth.revokeAll(userId);
    await this.notifications.removeAllDevices(userId);
    await this.favorites.removeAll(userId);
    // Effets visibles par les autres, après validation.
    for (const listingId of wasOnline) await this.listings.emitUnavailable({ listingId });
    await this.requests.cancelAllForBuyer(userId);
  }
}

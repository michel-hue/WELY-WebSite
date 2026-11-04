import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { notFound } from '../common/errors/app-error.js';
import { decodeCursor, encodeCursor } from '../common/pagination/cursor.js';
import type { Paginated } from '../common/pagination/paginated.js';
import type { ListingCardDto } from '../search/public-listing.dto.js';
import { SearchService } from '../search/search.service.js';
import { Favorite } from './favorite.entity.js';

@Injectable()
export class FavoritesService {
  constructor(
    @InjectRepository(Favorite) private readonly repo: Repository<Favorite>,
    private readonly search: SearchService,
  ) {}

  /** Favoris encore en ligne et non masqués, du plus récent au plus ancien. */
  async list(userId: string, cursor: string | undefined, limit: number): Promise<Paginated<ListingCardDto>> {
    const ts = `date_trunc('milliseconds', f.created_at)`;
    const qb = this.search
      .publicQuery({ userId })
      .innerJoin(Favorite, 'f', 'f.listing_id = l.id AND f.user_id = :favUser', { favUser: userId })
      .addSelect(ts, 'fav_at')
      .orderBy(ts, 'DESC')
      .addOrderBy('l.id', 'DESC')
      .limit(limit + 1);
    if (cursor) {
      const c = decodeCursor(cursor);
      qb.andWhere(`(${ts}, l.id) < (:favAt::timestamptz, :favId::uuid)`, { favAt: c.v, favId: c.id });
    }
    const { entities, raw } = await qb.getRawAndEntities();
    const page = entities.slice(0, limit);
    const last = page.at(-1);
    const lastAt = last && raw.find((r) => r.l_id === last.id)?.fav_at;
    return {
      data: await this.search.toCards(page),
      nextCursor: entities.length > limit && last ? encodeCursor({ v: new Date(lastAt).toISOString(), id: last.id }) : null,
    };
  }

  async add(userId: string, listingId: string): Promise<void> {
    const exists = await this.search.publicQuery({ userId }).andWhere('l.id = :id', { id: listingId }).getExists();
    if (!exists) throw notFound('LISTING_NOT_FOUND', 'Annonce introuvable.');
    await this.repo.createQueryBuilder().insert().values({ userId, listingId }).orIgnore().execute();
  }

  async remove(userId: string, listingId: string): Promise<void> {
    await this.repo.delete({ userId, listingId });
  }

  /** Fusionne les favoris gardés sur le téléphone avant la connexion (ids inconnus ignorés). */
  async merge(userId: string, listingIds: string[]): Promise<void> {
    if (!listingIds.length) return;
    await this.repo.query(
      `INSERT INTO favorites (user_id, listing_id)
       SELECT $1, l.id FROM listings l
       WHERE l.id = ANY($2::uuid[]) AND l.status = 'online' AND l.deleted_at IS NULL
       ON CONFLICT DO NOTHING`,
      [userId, listingIds],
    );
  }

  /** Supprime tous les favoris d'un utilisateur (suppression de compte). */
  async removeAll(userId: string): Promise<void> {
    await this.repo.delete({ userId });
  }
}

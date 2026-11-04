import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository, type SelectQueryBuilder } from 'typeorm';
import { notFound } from '../common/errors/app-error.js';
import type { OfferType } from '../common/events/domain-events.js';
import { decodeCursor, encodeCursor } from '../common/pagination/cursor.js';
import type { Paginated } from '../common/pagination/paginated.js';
import { Listing } from '../listings/listing.entity.js';
import { ListingsService } from '../listings/listings.service.js';
import { UsersService } from '../users/users.service.js';
import { toCardDto, toPublicDto, type ListingCardDto, type PublicListingDto } from './public-listing.dto.js';
import type { SearchQuery, SearchSort } from './search-query.dto.js';

/** Qui consulte : utilisateur connecté et/ou installation de l'app. */
export interface Viewer {
  userId?: string;
  installationId?: string;
}

const PRICE_COLUMN: Record<OfferType, string> = {
  monthly: 'l.monthly_rent',
  nightly: 'l.nightly_price',
  sale: 'l.sale_price',
};

const TEXT = `f_unaccent(lower(l.title || ' ' || l.district || ' ' || l.city || ' ' || l.description))`;
const POINT = `ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography`;
const escapeLike = (s: string) => s.replace(/[\\%_]/g, (c) => `\\${c}`);

@Injectable()
export class SearchService {
  constructor(
    @InjectRepository(Listing) private readonly repo: Repository<Listing>,
    private readonly listings: ListingsService,
    private readonly users: UsersService,
  ) {}

  /**
   * Annonces masquées pour ce visiteur (signalées par lui). Sous-requête SQL renvoyant des ids,
   * ou null s'il n'y a rien à masquer.
   */
  hiddenListingIdsFor(viewer: Viewer): { sql: string; params: Record<string, unknown> } | null {
    const conditions: string[] = [];
    if (viewer.userId) conditions.push('hr.user_id = :hiddenUser');
    if (viewer.installationId) conditions.push('hr.installation_id = :hiddenInstallation');
    if (!conditions.length) return null;
    return {
      sql: `SELECT hr.listing_id FROM reports hr WHERE ${conditions.join(' OR ')}`,
      params: { hiddenUser: viewer.userId, hiddenInstallation: viewer.installationId },
    };
  }

  /** Annonces visibles par ce visiteur : en ligne, non supprimées, non signalées par lui. */
  publicQuery(viewer: Viewer): SelectQueryBuilder<Listing> {
    const qb = this.repo.createQueryBuilder('l').where(`l.status = 'online' AND l.deleted_at IS NULL`);
    const hidden = this.hiddenListingIdsFor(viewer);
    if (hidden) qb.andWhere(`l.id NOT IN (${hidden.sql})`, hidden.params);
    return qb;
  }

  async search(q: SearchQuery, viewer: Viewer): Promise<Paginated<ListingCardDto>> {
    const qb = this.publicQuery(viewer);
    const geo = q.lat !== undefined && q.lng !== undefined;
    const sort: SearchSort = q.sort ?? (geo ? 'distance' : 'recent');

    if (geo) {
      qb.andWhere(`ST_DWithin(l.location, ${POINT}, :radius)`, { lat: q.lat, lng: q.lng, radius: q.radiusKm * 1000 });
      qb.addSelect(`ST_Distance(l.location, ${POINT})`, 'distance');
    }
    if (q.q?.trim()) {
      qb.andWhere(`${TEXT} LIKE '%' || f_unaccent(lower(:q)) || '%'`, { q: escapeLike(q.q.trim()) });
    }
    if (q.offerType) {
      const price = PRICE_COLUMN[q.offerType];
      qb.andWhere(`${price} IS NOT NULL`);
      if (q.priceMin !== undefined) qb.andWhere(`${price} >= :priceMin`, { priceMin: q.priceMin });
      if (q.priceMax !== undefined) qb.andWhere(`${price} <= :priceMax`, { priceMax: q.priceMax });
    }
    if (q.propertyType?.length) qb.andWhere('l.property_type IN (:...types)', { types: q.propertyType });
    if (q.city) qb.andWhere('f_unaccent(lower(l.city)) = f_unaccent(lower(:city))', { city: q.city.trim() });
    if (q.district) {
      qb.andWhere(`f_unaccent(lower(l.district)) LIKE '%' || f_unaccent(lower(:district)) || '%'`, {
        district: escapeLike(q.district.trim()),
      });
    }
    if (q.roomsMin !== undefined) qb.andWhere('l.rooms >= :roomsMin', { roomsMin: q.roomsMin });
    if (q.bedroomsMin !== undefined) qb.andWhere('l.bedrooms >= :bedroomsMin', { bedroomsMin: q.bedroomsMin });
    if (q.amenities?.length) qb.andWhere('l.amenities @> :amenities::text[]', { amenities: q.amenities });
    this.filterStayDates(qb, q);

    // Pagination par clé (keyset) : valeur de tri + id, même sens.
    const { expr, dir, cast } = this.sortKey(sort, q.offerType);
    qb.orderBy(expr, dir).addOrderBy('l.id', dir).limit(q.limit + 1);
    if (q.cursor) {
      const c = decodeCursor(q.cursor);
      qb.andWhere(`(${expr}, l.id) ${dir === 'ASC' ? '>' : '<'} (:cv::${cast}, :cid::uuid)`, { cv: c.v, cid: c.id });
    }

    const { entities, raw } = await qb.getRawAndEntities();
    const page = entities.slice(0, q.limit);
    const distances = new Map(raw.map((r) => [r.l_id as string, r.distance === undefined ? null : Number(r.distance)]));
    const last = page.at(-1);
    return {
      data: await this.toCards(page, distances),
      nextCursor:
        entities.length > q.limit && last
          ? encodeCursor({ v: this.sortValue(sort, last, distances.get(last.id) ?? null, q.offerType), id: last.id })
          : null,
    };
  }

  /** Cartes de liste (photo de couverture, distance éventuelle). */
  async toCards(listings: Listing[], distances = new Map<string, number | null>()): Promise<ListingCardDto[]> {
    const photos = await this.listings.photosOf(listings.map((l) => l.id));
    return listings.map((l) => toCardDto(l, photos.get(l.id)?.[0], distances.get(l.id) ?? null));
  }

  /** Exclut les annonces dont des nuits du séjour demandé sont déjà bloquées. */
  protected filterStayDates(qb: SelectQueryBuilder<Listing>, q: SearchQuery): void {
    if (!q.checkIn || !q.checkOut) return;
    qb.andWhere(
      `NOT EXISTS (SELECT 1 FROM blocked_stays bs WHERE bs.listing_id = l.id AND bs.nights && daterange(:checkIn::date, :checkOut::date, '[)'))`,
      { checkIn: q.checkIn, checkOut: q.checkOut },
    );
  }

  private sortKey(sort: SearchSort, offerType?: OfferType): { expr: string; dir: 'ASC' | 'DESC'; cast: string } {
    switch (sort) {
      case 'distance':
        return { expr: `ST_Distance(l.location, ${POINT})`, dir: 'ASC', cast: 'float8' };
      case 'price_asc':
        return { expr: PRICE_COLUMN[offerType!], dir: 'ASC', cast: 'int' };
      case 'price_desc':
        return { expr: PRICE_COLUMN[offerType!], dir: 'DESC', cast: 'int' };
      default:
        return { expr: `date_trunc('milliseconds', l.published_at)`, dir: 'DESC', cast: 'timestamptz' };
    }
  }

  private sortValue(sort: SearchSort, l: Listing, distance: number | null, offerType?: OfferType): string | number {
    switch (sort) {
      case 'distance':
        return distance ?? 0;
      case 'price_asc':
      case 'price_desc':
        return { monthly: l.monthlyRent, nightly: l.nightlyPrice, sale: l.salePrice }[offerType!] ?? 0;
      default:
        return l.publishedAt!.toISOString();
    }
  }

  async findPublic(id: string, viewer: Viewer): Promise<PublicListingDto> {
    const listing = await this.publicQuery(viewer).andWhere('l.id = :id', { id }).getOne();
    if (!listing) throw notFound('LISTING_NOT_FOUND', 'Annonce introuvable.');
    await this.repo.increment({ id }, 'viewCount', 1);
    const seller = await this.users.getActive(listing.ownerId);
    const onlineCount = await this.repo.count({ where: { ownerId: seller.id, status: 'online', deletedAt: IsNull() } });
    const photos = (await this.listings.photosOf([id])).get(id) ?? [];
    return toPublicDto(listing, photos, seller, onlineCount);
  }

  async recordContactClick(id: string): Promise<void> {
    const { affected } = await this.repo
      .createQueryBuilder()
      .update()
      .set({ contactClickCount: () => 'contact_click_count + 1' })
      .where(`id = :id AND status = 'online' AND deleted_at IS NULL`, { id })
      .execute();
    if (!affected) throw notFound('LISTING_NOT_FOUND', 'Annonce introuvable.');
  }

  async locations(): Promise<{ cities: { city: string; districts: string[] }[] }> {
    const rows: { city: string; districts: string[] }[] = await this.repo.query(`
      SELECT city, array_agg(DISTINCT district ORDER BY district) AS districts
      FROM listings
      WHERE status = 'online' AND deleted_at IS NULL
      GROUP BY city
      ORDER BY city`);
    return { cities: rows };
  }
}

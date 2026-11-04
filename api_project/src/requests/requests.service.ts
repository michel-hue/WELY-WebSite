import { Injectable } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, IsNull, QueryFailedError, Repository, type EntityManager } from 'typeorm';
import { badRequest, conflict, notFound, unprocessable } from '../common/errors/app-error.js';
import { LISTING_UNAVAILABLE, type ListingUnavailableEvent, type OfferType } from '../common/events/domain-events.js';
import { decodeCursor, encodeCursor } from '../common/pagination/cursor.js';
import type { Paginated } from '../common/pagination/paginated.js';
import { Listing } from '../listings/listing.entity.js';
import { offerTypesOf } from '../listings/listing.mapper.js';
import { todayIso } from '../listings/listings.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import type { ListingCardDto } from '../search/public-listing.dto.js';
import { SearchService } from '../search/search.service.js';
import { User } from '../users/user.entity.js';
import type { CreateRequestDto } from './dto/request.dto.js';
import { ListingRequest, type RefusalReason } from './listing-request.entity.js';
import { validateStay } from './stay-dates.js';

export interface RequestDto {
  id: string;
  status: ListingRequest['status'];
  refusalReason: RefusalReason | null;
  sellerMessage: string | null;
  offerType: OfferType;
  checkIn: string | null;
  checkOut: string | null;
  moveInDate: string | null;
  wantsVisit: boolean;
  message: string | null;
  createdAt: string;
  decidedAt: string | null;
  listing: ListingCardDto;
  buyer?: { id: string; name: string; phone: string | null };
}

const NOT_FOUND = () => notFound('REQUEST_NOT_FOUND', 'Demande introuvable.');
const DATES_TAKEN = () => conflict('STAY_DATES_UNAVAILABLE', 'Ces dates ne sont plus disponibles.');
const pgCode = (e: unknown) => (e instanceof QueryFailedError ? (e.driverError as { code?: string }).code : undefined);

const REFUSAL_TEXT: Record<RefusalReason, string> = {
  seller: 'Le vendeur a décliné votre demande.',
  dates_unavailable: 'Ces dates ne sont plus disponibles.',
  listing_unavailable: 'Cette annonce n’est plus disponible.',
};

@Injectable()
export class RequestsService {
  constructor(
    @InjectRepository(ListingRequest) private readonly repo: Repository<ListingRequest>,
    @InjectRepository(Listing) private readonly listings: Repository<Listing>,
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly ds: DataSource,
    private readonly notifications: NotificationsService,
    private readonly search: SearchService,
  ) {}

  async create(buyerId: string, dto: CreateRequestDto): Promise<RequestDto> {
    const listing = await this.listings.findOne({ where: { id: dto.listingId, deletedAt: IsNull() } });
    if (!listing) throw notFound('LISTING_NOT_FOUND', 'Annonce introuvable.');
    if (listing.status !== 'online') throw unprocessable('LISTING_NOT_AVAILABLE', 'Cette annonce n’est plus disponible.');
    if (listing.ownerId === buyerId) {
      throw unprocessable('CANNOT_REQUEST_OWN_LISTING', 'Vous ne pouvez pas faire de demande sur votre propre annonce.');
    }
    if (!offerTypesOf(listing).includes(dto.offerType)) {
      throw unprocessable('OFFER_NOT_AVAILABLE', 'Cette offre n’est pas proposée pour ce bien.');
    }
    const nightly = dto.offerType === 'nightly';
    if (nightly) {
      if (!dto.checkIn || !dto.checkOut) {
        throw badRequest('VALIDATION_ERROR', 'Certaines informations sont invalides.', [
          { field: 'checkIn', message: 'Indiquez vos dates de séjour.' },
        ]);
      }
      validateStay(dto.checkIn, dto.checkOut, listing.minNights, todayIso());
      if (await this.nightsTaken(this.ds.manager, listing.id, dto.checkIn, dto.checkOut)) throw DATES_TAKEN();
    }

    let saved: ListingRequest;
    try {
      saved = await this.repo.save(
        this.repo.create({
          listingId: listing.id,
          buyerId,
          offerType: dto.offerType,
          checkIn: nightly ? dto.checkIn! : null,
          checkOut: nightly ? dto.checkOut! : null,
          moveInDate: nightly ? null : (dto.moveInDate ?? null),
          wantsVisit: dto.wantsVisit ?? false,
          message: dto.message?.trim() || null,
        }),
      );
    } catch (e) {
      if (pgCode(e) === '23505') {
        throw conflict('REQUEST_ALREADY_PENDING', 'Vous avez déjà une demande en attente pour ce bien.');
      }
      throw e;
    }
    await this.listings.increment({ id: listing.id }, 'requestCount', 1);

    const buyer = await this.users.findOneByOrFail({ id: buyerId });
    await this.notifications.notify(listing.ownerId, 'request_received', {
      title: 'Nouvelle demande',
      body: `${buyer.name} est intéressé(e) par « ${listing.title} ».`,
      listingId: listing.id,
      requestId: saved.id,
    });
    return (await this.toDtos([saved], false))[0];
  }

  async accept(sellerId: string, id: string, message?: string): Promise<RequestDto> {
    const { request, listing } = await this.loadForSeller(sellerId, id);
    let autoRefused: { id: string; buyer_id: string }[] = [];

    try {
      await this.ds.transaction(async (m) => {
        // Les acceptations d'une même annonce sont traitées l'une après l'autre.
        await m.query(`SELECT id FROM listings WHERE id = $1 FOR UPDATE`, [listing.id]);
        const [current] = await m.query(`SELECT status, refusal_reason FROM listing_requests WHERE id = $1`, [id]);
        if (current.status === 'refused' && current.refusal_reason === 'dates_unavailable') throw DATES_TAKEN();
        if (current.status !== 'pending') throw this.notPending();

        if (request.offerType === 'nightly') {
          await m.query(
            `INSERT INTO blocked_stays (listing_id, request_id, nights) VALUES ($1, $2, daterange($3::date, $4::date, '[)'))`,
            [listing.id, id, request.checkIn, request.checkOut],
          );
          [autoRefused] = await m.query(
            `UPDATE listing_requests
             SET status = 'refused', refusal_reason = 'dates_unavailable', decided_at = now()
             WHERE listing_id = $1 AND id <> $2 AND status = 'pending' AND offer_type = 'nightly'
               AND daterange(check_in, check_out, '[)') && daterange($3::date, $4::date, '[)')
             RETURNING id, buyer_id`,
            [listing.id, id, request.checkIn, request.checkOut],
          );
        }
        await m.update(ListingRequest, { id }, { status: 'accepted', sellerMessage: message?.trim() || null, decidedAt: new Date() });
      });
    } catch (e) {
      if (pgCode(e) === '23P01') {
        // Chevauche un séjour déjà accepté (demande créée pendant une acceptation).
        await this.refuse(sellerId, id, undefined, 'dates_unavailable').catch(() => undefined);
        throw DATES_TAKEN();
      }
      throw e;
    }

    await this.notifications.notify(request.buyerId, 'request_accepted', {
      title: 'Demande acceptée',
      body: `Le vendeur a accepté votre demande pour « ${listing.title} ». Il va vous contacter.`,
      listingId: listing.id,
      requestId: id,
    });
    await this.notifyRefused(autoRefused, listing, 'dates_unavailable');
    return this.getForSeller(sellerId, id);
  }

  async refuse(sellerId: string, id: string, message?: string, reason: RefusalReason = 'seller'): Promise<RequestDto> {
    const { listing } = await this.loadForSeller(sellerId, id);
    const rows: { id: string; buyer_id: string }[] = (
      await this.ds.query(
        `UPDATE listing_requests SET status = 'refused', refusal_reason = $2, seller_message = $3, decided_at = now()
         WHERE id = $1 AND status = 'pending' RETURNING id, buyer_id`,
        [id, reason, message?.trim() || null],
      )
    )[0];
    if (!rows.length) throw this.notPending();
    await this.notifyRefused(rows, listing, reason);
    return this.getForSeller(sellerId, id);
  }

  async cancel(buyerId: string, id: string): Promise<RequestDto> {
    const request = await this.repo.findOne({ where: { id, buyerId } });
    if (!request) throw NOT_FOUND();
    const cancelled = await this.cancelRequests([request.id]);
    if (!cancelled.length) throw unprocessable('REQUEST_NOT_CANCELLABLE', 'Cette demande ne peut plus être annulée.');
    return (await this.toDtos([await this.repo.findOneByOrFail({ id })], false))[0];
  }

  /** Annule toutes les demandes en cours d'un acheteur (suppression de compte). */
  async cancelAllForBuyer(buyerId: string): Promise<void> {
    const open = await this.repo.find({ where: { buyerId, status: In(['pending', 'accepted']) }, select: { id: true } });
    await this.cancelRequests(open.map((r) => r.id));
  }

  /** Une annonce quitte le marché (ou perd des offres) : ses demandes en attente sont refusées. */
  @OnEvent(LISTING_UNAVAILABLE)
  async onListingUnavailable(event: ListingUnavailableEvent): Promise<void> {
    const params: unknown[] = [event.listingId];
    let offerFilter = '';
    if (event.offerTypes?.length) {
      params.push(event.offerTypes);
      offerFilter = 'AND offer_type = ANY($2)';
    }
    const rows: { id: string; buyer_id: string }[] = (
      await this.ds.query(
        `UPDATE listing_requests SET status = 'refused', refusal_reason = 'listing_unavailable', decided_at = now()
         WHERE listing_id = $1 AND status = 'pending' ${offerFilter} RETURNING id, buyer_id`,
        params,
      )
    )[0];
    if (!rows.length) return;
    const listing = await this.listings.findOneByOrFail({ id: event.listingId });
    await this.notifyRefused(rows, listing, 'listing_unavailable');
  }

  async listForBuyer(buyerId: string, status: string | undefined, cursor: string | undefined, limit: number) {
    return this.page({ buyerId, status }, cursor, limit, false);
  }

  async listForSeller(sellerId: string, status: string | undefined, listingId: string | undefined, cursor: string | undefined, limit: number) {
    return this.page({ sellerId, status, listingId }, cursor, limit, true);
  }

  // --- interne ---

  private notPending() {
    return unprocessable('REQUEST_NOT_PENDING', 'Cette demande a déjà été traitée.');
  }

  private nightsTaken(m: EntityManager, listingId: string, checkIn: string, checkOut: string): Promise<boolean> {
    return m
      .query(
        `SELECT EXISTS (SELECT 1 FROM blocked_stays WHERE listing_id = $1 AND nights && daterange($2::date, $3::date, '[)')) AS taken`,
        [listingId, checkIn, checkOut],
      )
      .then((rows: { taken: boolean }[]) => rows[0].taken);
  }

  private async loadForSeller(sellerId: string, id: string) {
    const request = await this.repo.findOne({ where: { id } });
    if (!request) throw NOT_FOUND();
    const listing = await this.listings.findOneBy({ id: request.listingId });
    if (!listing || listing.ownerId !== sellerId) throw NOT_FOUND();
    return { request, listing };
  }

  private async getForSeller(sellerId: string, id: string): Promise<RequestDto> {
    const request = await this.repo.findOneByOrFail({ id });
    const listing = await this.listings.findOneByOrFail({ id: request.listingId });
    if (listing.ownerId !== sellerId) throw NOT_FOUND();
    return (await this.toDtos([request], true))[0];
  }

  /** Annule des demandes en attente ou acceptées, libère leurs nuits et prévient les vendeurs. */
  private async cancelRequests(ids: string[]): Promise<{ id: string; listing_id: string }[]> {
    if (!ids.length) return [];
    const rows: { id: string; listing_id: string }[] = await this.ds.transaction(async (m) => {
      const [updated] = await m.query(
        `UPDATE listing_requests SET status = 'cancelled', decided_at = now()
         WHERE id = ANY($1) AND status IN ('pending', 'accepted') RETURNING id, listing_id`,
        [ids],
      );
      await m.query(`DELETE FROM blocked_stays WHERE request_id = ANY($1)`, [ids]);
      return updated;
    });
    for (const row of rows) {
      const listing = await this.listings.findOneBy({ id: row.listing_id });
      if (!listing) continue;
      await this.notifications.notify(listing.ownerId, 'request_cancelled', {
        title: 'Demande annulée',
        body: `Une demande pour « ${listing.title} » a été annulée.`,
        listingId: listing.id,
        requestId: row.id,
      });
    }
    return rows;
  }

  private async notifyRefused(rows: { id: string; buyer_id: string }[], listing: Listing, reason: RefusalReason) {
    for (const row of rows) {
      await this.notifications.notify(row.buyer_id, 'request_refused', {
        title: 'Demande non retenue',
        body: `« ${listing.title} » : ${REFUSAL_TEXT[reason]}`,
        listingId: listing.id,
        requestId: row.id,
        reason,
      });
    }
  }

  private async page(
    filter: { buyerId?: string; sellerId?: string; status?: string; listingId?: string },
    cursor: string | undefined,
    limit: number,
    withBuyer: boolean,
  ): Promise<Paginated<RequestDto>> {
    const ts = `date_trunc('milliseconds', r.created_at)`;
    const qb = this.repo.createQueryBuilder('r').orderBy(ts, 'DESC').addOrderBy('r.id', 'DESC').take(limit + 1);
    if (filter.buyerId) qb.where('r.buyer_id = :buyerId', { buyerId: filter.buyerId });
    if (filter.sellerId) {
      qb.where('r.listing_id IN (SELECT id FROM listings WHERE owner_id = :sellerId)', { sellerId: filter.sellerId });
    }
    if (filter.status) qb.andWhere('r.status = :status', { status: filter.status });
    if (filter.listingId) qb.andWhere('r.listing_id = :listingId', { listingId: filter.listingId });
    if (cursor) {
      const c = decodeCursor(cursor);
      qb.andWhere(`(${ts}, r.id) < (:createdAt::timestamptz, :id::uuid)`, { createdAt: c.createdAt, id: c.id });
    }
    const rows = await qb.getMany();
    const pageRows = rows.slice(0, limit);
    const last = pageRows.at(-1);
    return {
      data: await this.toDtos(pageRows, withBuyer),
      nextCursor: rows.length > limit && last ? encodeCursor({ createdAt: last.createdAt.toISOString(), id: last.id }) : null,
    };
  }

  private async toDtos(requests: ListingRequest[], withBuyer: boolean): Promise<RequestDto[]> {
    if (!requests.length) return [];
    const listings = await this.listings.findBy({ id: In([...new Set(requests.map((r) => r.listingId))]) });
    const cards = new Map((await this.search.toCards(listings)).map((c) => [c.id, c]));
    const buyers = withBuyer
      ? new Map((await this.users.findBy({ id: In([...new Set(requests.map((r) => r.buyerId))]) })).map((u) => [u.id, u]))
      : new Map<string, User>();
    return requests.map((r) => {
      const buyer = buyers.get(r.buyerId);
      return {
        id: r.id,
        status: r.status,
        refusalReason: r.refusalReason,
        sellerMessage: r.sellerMessage,
        offerType: r.offerType,
        checkIn: r.checkIn,
        checkOut: r.checkOut,
        moveInDate: r.moveInDate,
        wantsVisit: r.wantsVisit,
        message: r.message,
        createdAt: r.createdAt.toISOString(),
        decidedAt: r.decidedAt?.toISOString() ?? null,
        listing: cards.get(r.listingId)!,
        ...(withBuyer && buyer ? { buyer: { id: buyer.id, name: buyer.name, phone: buyer.phone } } : {}),
      };
    });
  }
}

import { Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { forbidden, notFound, unprocessable } from '../common/errors/app-error.js';
import { LISTING_UNAVAILABLE, type ListingUnavailableEvent, type OfferType } from '../common/events/domain-events.js';
import { decodeCursor, encodeCursor } from '../common/pagination/cursor.js';
import type { Paginated } from '../common/pagination/paginated.js';
import { UsersService } from '../users/users.service.js';
import type { CreateListingDto, UpdateListingDto } from './dto/listing.dto.js';
import { Listing } from './listing.entity.js';
import { offerTypesOf, toSellerListingDto, type PhotoDto, type SellerListingDto } from './listing.mapper.js';
import { assertTransition, type ListingAction } from './listing-status.js';

/** Vraie date du calendrier au format AAAA-MM-JJ (refuse le 31 février). */
export const isRealDate = (s: string) =>
  /^\d{4}-\d{2}-\d{2}$/.test(s) &&
  !Number.isNaN(Date.parse(`${s}T00:00:00Z`)) &&
  new Date(`${s}T00:00:00Z`).toISOString().slice(0, 10) === s;

/** Date du jour (AAAA-MM-JJ) en heure d'Abidjan, qui est UTC. */
export const todayIso = (now = new Date()) => now.toISOString().slice(0, 10);

@Injectable()
export class ListingsService {
  constructor(
    @InjectRepository(Listing) readonly repo: Repository<Listing>,
    private readonly users: UsersService,
    private readonly events: EventEmitter2,
  ) {}

  /** Photos d'une annonce, ordonnées. Remplacé par le module photos. */
  photosOf: (listingIds: string[]) => Promise<Map<string, PhotoDto[]>> = async () => new Map();

  /** Nombre de photos d'une annonce (règle de publication). Remplacé par le module photos. */
  photoCount: (listingId: string) => Promise<number | null> = async () => null;

  async toDto(l: Listing): Promise<SellerListingDto> {
    return toSellerListingDto(l, (await this.photosOf([l.id])).get(l.id) ?? []);
  }

  private async assertSeller(userId: string) {
    const user = await this.users.getActive(userId);
    if (!user.isSeller) throw forbidden('SELLER_MODE_REQUIRED', 'Activez le mode vendeur pour publier.');
  }

  /** Annonce non supprimée appartenant à l'utilisateur. */
  async findOwned(id: string, userId: string): Promise<Listing> {
    const listing = await this.repo.findOne({ where: { id, deletedAt: IsNull() } });
    if (!listing) throw notFound('LISTING_NOT_FOUND', 'Annonce introuvable.');
    if (listing.ownerId !== userId) throw forbidden('NOT_LISTING_OWNER', 'Cette annonce ne vous appartient pas.');
    return listing;
  }

  async create(userId: string, dto: CreateListingDto): Promise<Listing> {
    await this.assertSeller(userId);
    const listing = this.repo.create({ ownerId: userId, status: 'draft', amenities: [], description: '' });
    this.apply(listing, dto);
    return this.repo.save(listing);
  }

  async update(userId: string, id: string, dto: UpdateListingDto): Promise<Listing> {
    const listing = await this.findOwned(id, userId);
    const before = offerTypesOf(listing);
    this.apply(listing, dto);
    if (listing.status === 'online' && !offerTypesOf(listing).length) {
      throw unprocessable('LISTING_INCOMPLETE', 'Une annonce en ligne doit garder au moins une offre.', [
        { field: 'offers', message: 'Au moins une offre est requise.' },
      ]);
    }
    const saved = await this.repo.save(listing);
    const removed = before.filter((o) => !offerTypesOf(saved).includes(o));
    if (removed.length) await this.emitUnavailable({ listingId: id, offerTypes: removed });
    return saved;
  }

  async publish(userId: string, id: string, until?: string) {
    await this.assertSeller(userId);
    return this.transition(userId, id, 'publish', async (l) => {
      await this.assertPublishable(l, until);
      l.publishedUntil = until ?? null;
      l.publishedAt = new Date();
      l.expiryReminderSentAt = null;
    });
  }

  async reactivate(userId: string, id: string, until?: string) {
    await this.assertSeller(userId);
    return this.transition(userId, id, 'reactivate', async (l) => {
      await this.assertPublishable(l, until);
      l.publishedUntil = until ?? null;
      l.publishedAt = new Date();
      l.closedReason = null;
      l.expiryReminderSentAt = null;
    });
  }

  /** Prolonge (ou rend permanente) une annonce en ligne, sans la retirer du marché. */
  async extend(userId: string, id: string, until?: string): Promise<Listing> {
    const listing = await this.findOwned(id, userId);
    if (listing.status !== 'online') {
      throw unprocessable('INVALID_LISTING_TRANSITION', 'Seule une annonce en ligne peut être prolongée.');
    }
    if (until !== undefined && (!isRealDate(until) || until < todayIso())) {
      throw unprocessable('INVALID_PUBLICATION_DATE', 'La date de fin doit être aujourd’hui ou plus tard.');
    }
    listing.publishedUntil = until ?? null;
    listing.expiryReminderSentAt = null;
    return this.repo.save(listing);
  }

  deactivate(userId: string, id: string) {
    return this.transition(userId, id, 'deactivate', async () => undefined);
  }

  close(userId: string, id: string, reason: 'rented' | 'sold') {
    return this.transition(userId, id, 'close', async (l) => {
      l.closedReason = reason;
    });
  }

  async remove(userId: string, id: string): Promise<void> {
    const listing = await this.findOwned(id, userId);
    const wasOnline = listing.status === 'online';
    listing.deletedAt = new Date();
    await this.repo.save(listing);
    if (wasOnline) await this.emitUnavailable({ listingId: id });
  }

  async listMine(userId: string, status: string | undefined, cursor: string | undefined, limit: number): Promise<Paginated<SellerListingDto>> {
    const ts = `date_trunc('milliseconds', l.created_at)`;
    const qb = this.repo
      .createQueryBuilder('l')
      .where('l.ownerId = :userId AND l.deletedAt IS NULL', { userId })
      .orderBy(ts, 'DESC')
      .addOrderBy('l.id', 'DESC')
      .take(limit + 1);
    if (status) qb.andWhere('l.status = :status', { status });
    if (cursor) {
      const c = decodeCursor(cursor);
      qb.andWhere(`(${ts}, l.id) < (:createdAt::timestamptz, :id::uuid)`, { createdAt: c.createdAt, id: c.id });
    }
    const rows = await qb.getMany();
    const page = rows.slice(0, limit);
    const photos = await this.photosOf(page.map((l) => l.id));
    const last = page.at(-1);
    return {
      data: page.map((l) => toSellerListingDto(l, photos.get(l.id) ?? [])),
      nextCursor: rows.length > limit && last ? encodeCursor({ createdAt: last.createdAt.toISOString(), id: last.id }) : null,
    };
  }

  emitUnavailable(event: ListingUnavailableEvent) {
    return this.events.emitAsync(LISTING_UNAVAILABLE, event);
  }

  // Le mode vendeur n'est exigé que pour créer, publier et réactiver : un vendeur repassé
  // acheteur peut toujours gérer (modifier, désactiver, clore, supprimer) ses annonces.
  private async transition(userId: string, id: string, action: ListingAction, mutate: (l: Listing) => Promise<void>) {
    const listing = await this.findOwned(id, userId);
    const wasOnline = listing.status === 'online';
    listing.status = assertTransition(listing.status, action);
    await mutate(listing);
    const saved = await this.repo.save(listing);
    if (wasOnline && saved.status !== 'online') await this.emitUnavailable({ listingId: id });
    return saved;
  }

  private async assertPublishable(l: Listing, until?: string) {
    if (until !== undefined && (!isRealDate(until) || until < todayIso())) {
      throw unprocessable('INVALID_PUBLICATION_DATE', 'La date de fin doit être aujourd’hui ou plus tard.');
    }
    const missing: { field: string; message: string }[] = [];
    if (!offerTypesOf(l).length) missing.push({ field: 'offers', message: 'Ajoutez au moins une offre (mois, nuit ou vente).' });
    if (!l.location) missing.push({ field: 'location', message: 'Placez le bien sur la carte.' });
    const photos = await this.photoCount(l.id);
    if (photos !== null && photos < 1) missing.push({ field: 'photos', message: 'Ajoutez au moins une photo.' });
    if (missing.length) throw unprocessable('LISTING_INCOMPLETE', 'L’annonce est incomplète.', missing);
  }

  private apply(l: Listing, dto: UpdateListingDto) {
    const simple = ['title', 'description', 'propertyType', 'rooms', 'bedrooms', 'bathrooms', 'surfaceM2', 'amenities', 'city', 'district', 'address'] as const;
    for (const key of simple) {
      if (dto[key] !== undefined) (l as unknown as Record<string, unknown>)[key] = typeof dto[key] === 'string' ? (dto[key] as string).trim() : dto[key];
    }
    if (dto.location !== undefined) l.location = { type: 'Point', coordinates: [dto.location.lng, dto.location.lat] };
    const o = dto.offers;
    if (o) {
      if (o.monthly !== undefined) {
        l.monthlyRent = o.monthly?.rent ?? null;
        l.monthlyTerms = o.monthly?.terms ?? null;
      }
      if (o.nightly !== undefined) {
        l.nightlyPrice = o.nightly?.price ?? null;
        l.minNights = o.nightly?.minNights ?? null;
      }
      if (o.sale !== undefined) l.salePrice = o.sale?.price ?? null;
    }
  }
}

export type { OfferType };

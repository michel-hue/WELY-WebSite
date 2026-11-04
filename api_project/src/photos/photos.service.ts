import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'node:crypto';
import { DataSource, In, Repository } from 'typeorm';
import { badRequest, notFound, unprocessable } from '../common/errors/app-error.js';
import type { PhotoDto } from '../listings/listing.mapper.js';
import { ListingsService } from '../listings/listings.service.js';
import { processImage } from './image-processor.js';
import { ListingPhoto } from './listing-photo.entity.js';
import { STORAGE, type Storage } from './storage/storage.js';

export const MAX_PHOTOS_PER_LISTING = 15;

@Injectable()
export class PhotosService implements OnModuleInit {
  constructor(
    @InjectRepository(ListingPhoto) private readonly repo: Repository<ListingPhoto>,
    @Inject(STORAGE) private readonly storage: Storage,
    private readonly listings: ListingsService,
    private readonly ds: DataSource,
  ) {}

  /** Branche les photos sur les annonces (DTO et règle de publication). */
  onModuleInit() {
    this.listings.photosOf = (ids) => this.photosOf(ids);
    this.listings.photoCount = (id) => this.repo.count({ where: { listingId: id } });
  }

  toDto = (p: ListingPhoto): PhotoDto => ({
    id: p.id,
    thumbUrl: this.storage.publicUrl(p.thumbKey),
    largeUrl: this.storage.publicUrl(p.largeKey),
    width: p.width,
    height: p.height,
    position: p.position,
  });

  async photosOf(listingIds: string[]): Promise<Map<string, PhotoDto[]>> {
    const map = new Map<string, PhotoDto[]>();
    if (!listingIds.length) return map;
    const rows = await this.repo.find({ where: { listingId: In(listingIds) }, order: { position: 'ASC' } });
    for (const p of rows) map.set(p.listingId, [...(map.get(p.listingId) ?? []), this.toDto(p)]);
    return map;
  }

  async add(userId: string, listingId: string, files: Express.Multer.File[]): Promise<PhotoDto[]> {
    await this.listings.findOwned(listingId, userId);
    if (!files.length) throw badRequest('NO_PHOTO', 'Ajoutez au moins une photo.');
    const existing = await this.repo.count({ where: { listingId } });
    if (existing + files.length > MAX_PHOTOS_PER_LISTING) {
      throw unprocessable('TOO_MANY_PHOTOS', `Une annonce peut contenir ${MAX_PHOTOS_PER_LISTING} photos au maximum.`);
    }
    // Toutes les images sont traitées avant d'écrire quoi que ce soit.
    const processed = [];
    for (const f of files) processed.push(await processImage(f.buffer)); // une à une : mémoire bornée
    const saved: ListingPhoto[] = [];
    for (const [i, img] of processed.entries()) {
      const base = `listings/${listingId}/${randomUUID()}`;
      const photo = this.repo.create({
        listingId,
        position: existing + i,
        thumbKey: `${base}-thumb.webp`,
        largeKey: `${base}-large.webp`,
        width: img.width,
        height: img.height,
      });
      await this.storage.put(photo.thumbKey, img.thumb, 'image/webp');
      await this.storage.put(photo.largeKey, img.large, 'image/webp');
      saved.push(await this.repo.save(photo));
    }
    return saved.map(this.toDto);
  }

  async reorder(userId: string, listingId: string, photoIds: string[]): Promise<void> {
    await this.listings.findOwned(listingId, userId);
    const photos = await this.repo.find({ where: { listingId } });
    const known = new Set(photos.map((p) => p.id));
    if (photoIds.length !== photos.length || new Set(photoIds).size !== photoIds.length || !photoIds.every((id) => known.has(id))) {
      throw badRequest('INVALID_PHOTO_ORDER', 'La liste doit contenir exactement toutes les photos de l’annonce.');
    }
    await this.ds.transaction(async (m) => {
      for (const [position, id] of photoIds.entries()) await m.update(ListingPhoto, { id }, { position });
    });
  }

  async remove(userId: string, listingId: string, photoId: string): Promise<void> {
    const listing = await this.listings.findOwned(listingId, userId);
    const photo = await this.repo.findOne({ where: { id: photoId, listingId } });
    if (!photo) throw notFound('PHOTO_NOT_FOUND', 'Photo introuvable.');
    const count = await this.repo.count({ where: { listingId } });
    if (listing.status === 'online' && count <= 1) {
      throw unprocessable('LAST_PHOTO_OF_ONLINE_LISTING', 'Une annonce en ligne doit garder au moins une photo.');
    }
    await this.repo.delete({ id: photo.id });
    // Les positions restent continues (0, 1, 2…).
    await this.repo
      .createQueryBuilder()
      .update()
      .set({ position: () => 'position - 1' })
      .where('listing_id = :listingId AND position > :position', { listingId, position: photo.position })
      .execute();
    await Promise.all([this.storage.delete(photo.thumbKey), this.storage.delete(photo.largeKey)]);
  }
}

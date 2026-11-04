import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Listing, ListingType, ListingStatus } from './listing.entity.js';

@Injectable()
export class ListingsService {
  constructor(@InjectRepository(Listing) private readonly repo: Repository<Listing>) {}

  async create(data: Partial<Listing>, ownerId: string): Promise<Listing> {
    const listing = this.repo.create({ ...data, ownerId });
    return this.repo.save(listing);
  }

  async findAll(): Promise<Listing[]> {
    const list = await this.repo.find({ relations: { owner: true } });
    return list.map((l) => this.sanitizeOwner(l));
  }

  async findOne(id: string): Promise<Listing> {
    const l = await this.repo.findOne({ where: { id }, relations: { owner: true } });
    if (!l) throw new NotFoundException('Listing not found');
    return this.sanitizeOwner(l);
  }

  private sanitizeOwner(l: Listing): Listing {
    if (l.owner) {
      const { passwordHash, ...rest } = l.owner as any;
      l.owner = rest as any;
    }
    return l;
  }

  async update(id: string, data: Partial<Listing>, userId: string): Promise<Listing> {
    const l = await this.findOne(id);
    if (l.ownerId !== userId) throw new ForbiddenException('Not owner');
    Object.assign(l, data);
    return this.repo.save(l);
  }

  async remove(id: string, userId: string): Promise<void> {
    const l = await this.findOne(id);
    if (l.ownerId !== userId) throw new ForbiddenException('Not owner');
    await this.repo.remove(l);
  }

  async addImages(id: string, userId: string, files: any[]): Promise<Listing> {
    const l = await this.repo.findOne({ where: { id } });
    if (!l) throw new NotFoundException('Listing not found');
    if (l.ownerId !== userId) throw new ForbiddenException('Not owner');
    const urls = files.map((f) => `/uploads/${f.filename}`);
    l.photos = [...(l.photos || []), ...urls];
    return this.repo.save(l);
  }
}

export { ListingType, ListingStatus };
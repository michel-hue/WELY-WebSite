import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Reservation, ReservationStatus } from './reservation.entity.js';
import { Listing } from '../listings/listing.entity.js';

@Injectable()
export class ReservationsService {
  constructor(
    @InjectRepository(Reservation) private readonly repo: Repository<Reservation>,
    @InjectRepository(Listing) private readonly listingsRepo: Repository<Listing>,
  ) {}

  async create(listingId: string, buyerId: string): Promise<Reservation> {
    const listing = await this.listingsRepo.findOne({ where: { id: listingId } });
    if (!listing) throw new NotFoundException('Listing not found');
    if (listing.ownerId === buyerId) throw new BadRequestException('Cannot reserve own listing');
    const r = this.repo.create({ listingId, buyerId, status: ReservationStatus.PENDING });
    return this.repo.save(r);
  }

  async findMine(buyerId: string): Promise<Reservation[]> {
    return this.repo.find({ where: { buyerId } });
  }

  async findOne(id: string, userId: string): Promise<Reservation> {
    const r = await this.repo.findOne({ where: { id } });
    if (!r) throw new NotFoundException('Reservation not found');
    // allow buyer or owner of listing
    const listing = await this.listingsRepo.findOne({ where: { id: r.listingId } });
    if (r.buyerId !== userId && listing?.ownerId !== userId) throw new ForbiddenException('Not allowed');
    return r;
  }

  async updateStatus(id: string, status: ReservationStatus, userId: string): Promise<Reservation> {
    const r = await this.repo.findOne({ where: { id } });
    if (!r) throw new NotFoundException('Reservation not found');
    const listing = await this.listingsRepo.findOne({ where: { id: r.listingId } });
    const isBuyer = r.buyerId === userId;
    const isSeller = listing?.ownerId === userId;
    if (!listing) throw new NotFoundException('Listing not found');
    // Buyer may only cancel their own reservation
    if (isBuyer && status === ReservationStatus.CANCELLED) {
      r.status = status;
      return this.repo.save(r);
    }
    // Seller keeps other transitions
    if (isSeller) {
      r.status = status;
      return this.repo.save(r);
    }
    throw new ForbiddenException('Not allowed');
  }
}

export { ReservationStatus };
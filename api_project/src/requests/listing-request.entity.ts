import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';
import type { OfferType } from '../common/events/domain-events.js';

export type RequestStatus = 'pending' | 'accepted' | 'refused' | 'cancelled';
export type RefusalReason = 'seller' | 'dates_unavailable' | 'listing_unavailable';

/** Demande d'un acheteur sur une offre d'une annonce (aucun paiement). */
@Entity('listing_requests')
export class ListingRequest {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column('uuid')
  listingId!: string;

  @Index()
  @Column('uuid')
  buyerId!: string;

  @Column({ type: 'varchar', length: 10 })
  offerType!: OfferType;

  @Column({ type: 'date', nullable: true })
  checkIn!: string | null;

  @Column({ type: 'date', nullable: true })
  checkOut!: string | null;

  @Column({ type: 'date', nullable: true })
  moveInDate!: string | null;

  @Column({ default: false })
  wantsVisit!: boolean;

  @Column({ type: 'varchar', length: 1000, nullable: true })
  message!: string | null;

  @Column({ type: 'varchar', length: 10, default: 'pending' })
  status!: RequestStatus;

  @Column({ type: 'varchar', length: 20, nullable: true })
  refusalReason!: RefusalReason | null;

  @Column({ type: 'varchar', length: 1000, nullable: true })
  sellerMessage!: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  decidedAt!: Date | null;
}

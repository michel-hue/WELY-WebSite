import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import type { Point } from 'typeorm';
import type { ListingStatus } from './listing-status.js';

export const PROPERTY_TYPES = ['house', 'villa', 'apartment', 'studio', 'room', 'land', 'other'] as const;
export type PropertyType = (typeof PROPERTY_TYPES)[number];

export const AMENITIES = [
  'furnished',
  'air_conditioning',
  'parking',
  'pool',
  'generator',
  'security',
  'wifi',
  'water_tank',
  'garden',
  'balcony',
] as const;
export type Amenity = (typeof AMENITIES)[number];

@Entity('listings')
export class Listing {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column('uuid')
  ownerId!: string;

  @Column({ type: 'varchar', length: 120 })
  title!: string;

  @Column({ type: 'text', default: '' })
  description!: string;

  @Column({ type: 'varchar', length: 20 })
  propertyType!: PropertyType;

  @Column({ type: 'int', default: 0 })
  rooms!: number;

  @Column({ type: 'int', nullable: true })
  bedrooms!: number | null;

  @Column({ type: 'int', nullable: true })
  bathrooms!: number | null;

  @Column({ type: 'int', nullable: true })
  surfaceM2!: number | null;

  @Column({ type: 'text', array: true, default: () => `'{}'` })
  amenities!: Amenity[];

  @Column({ type: 'varchar', length: 80 })
  city!: string;

  @Column({ type: 'varchar', length: 120 })
  district!: string;

  @Column({ type: 'varchar', length: 200, nullable: true })
  address!: string | null;

  @Column({ type: 'geography', spatialFeatureType: 'Point', srid: 4326, nullable: true })
  location!: Point | null;

  // --- Offres (null = offre absente) ---
  @Column({ type: 'int', nullable: true })
  monthlyRent!: number | null;

  @Column({ type: 'varchar', length: 300, nullable: true })
  monthlyTerms!: string | null;

  @Column({ type: 'int', nullable: true })
  nightlyPrice!: number | null;

  @Column({ type: 'int', nullable: true })
  minNights!: number | null;

  @Column({ type: 'int', nullable: true })
  salePrice!: number | null;

  // --- Publication ---
  @Index()
  @Column({ type: 'varchar', length: 12, default: 'draft' })
  status!: ListingStatus;

  @Column({ type: 'varchar', length: 10, nullable: true })
  closedReason!: 'rented' | 'sold' | null;

  /** Dernier jour de publication (inclus). null = permanente. */
  @Column({ type: 'date', nullable: true })
  publishedUntil!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  publishedAt!: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  expiryReminderSentAt!: Date | null;

  // --- Compteurs ---
  @Column({ type: 'int', default: 0 })
  viewCount!: number;

  @Column({ type: 'int', default: 0 })
  contactClickCount!: number;

  @Column({ type: 'int', default: 0 })
  requestCount!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  deletedAt!: Date | null;
}

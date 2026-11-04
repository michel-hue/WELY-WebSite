import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from '../users/user.entity.js';

export enum ListingType {
  HOUSE = 'house',
  APARTMENT = 'apartment',
}

export enum ListingStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  SOLD = 'sold',
}

@Entity('listings')
export class Listing {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  title!: string;

  @Column('text')
  description!: string;

  @Column('numeric')
  price!: number;

  @Column()
  city!: string;

  @Column({ type: 'enum', enum: ListingType })
  type!: ListingType;

  @Column('int')
  rooms!: number;

  @Column('text', { array: true, default: [] })
  photos!: string[];

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  owner!: User;

  @Column()
  ownerId!: string;

  @Column({ type: 'enum', enum: ListingStatus, default: ListingStatus.ACTIVE })
  status!: ListingStatus;

  @CreateDateColumn()
  createdAt!: Date;
}
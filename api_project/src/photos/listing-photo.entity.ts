import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('listing_photos')
@Index(['listingId', 'position'])
export class ListingPhoto {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  listingId!: string;

  /** 0 = photo de couverture. */
  @Column('int')
  position!: number;

  @Column({ type: 'varchar', length: 200 })
  thumbKey!: string;

  @Column({ type: 'varchar', length: 200 })
  largeKey!: string;

  @Column('int')
  width!: number;

  @Column('int')
  height!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}

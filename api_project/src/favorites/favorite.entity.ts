import { CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

@Entity('favorites')
export class Favorite {
  @PrimaryColumn('uuid')
  userId!: string;

  @PrimaryColumn('uuid')
  listingId!: string;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}

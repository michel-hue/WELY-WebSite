import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

export const NOTIFICATION_TYPES = [
  'request_received',
  'request_cancelled',
  'request_accepted',
  'request_refused',
  'listing_expired',
  'listing_expiring_soon',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

@Entity('notifications')
@Index(['userId', 'createdAt'])
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  userId!: string;

  @Column({ type: 'varchar', length: 40 })
  type!: NotificationType;

  @Column({ type: 'varchar', length: 120 })
  title!: string;

  @Column({ type: 'varchar', length: 500 })
  body!: string;

  @Column({ type: 'uuid', nullable: true })
  listingId!: string | null;

  @Column({ type: 'uuid', nullable: true })
  requestId!: string | null;

  @Column({ type: 'varchar', length: 40, nullable: true })
  reason!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  readAt!: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}

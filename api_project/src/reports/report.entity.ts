import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

export const REPORT_REASONS = ['scam', 'misleading_price', 'misleading_photos', 'unavailable', 'other'] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

/** Signalement : masque l'annonce pour son auteur (utilisateur et/ou installation), conservé pour modération future. */
@Entity('reports')
export class Report {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column('uuid')
  listingId!: string;

  @Index()
  @Column({ type: 'uuid', nullable: true })
  userId!: string | null;

  @Index()
  @Column({ type: 'uuid', nullable: true })
  installationId!: string | null;

  @Column({ type: 'varchar', length: 20 })
  reason!: ReportReason;

  @Column({ type: 'varchar', length: 500, nullable: true })
  comment!: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}

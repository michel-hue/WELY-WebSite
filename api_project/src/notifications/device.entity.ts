import { Column, CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';

/** Appareil recevant les push (jeton FCM). */
@Entity('devices')
export class Device {
  @PrimaryColumn({ type: 'varchar', length: 255 })
  token!: string;

  @Index()
  @Column('uuid')
  userId!: string;

  @Column({ type: 'varchar', length: 10 })
  platform!: 'ios' | 'android';

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}

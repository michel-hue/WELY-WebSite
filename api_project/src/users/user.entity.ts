import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('users')
@Index('users_phone_unique', ['phone'], { unique: true, where: 'phone IS NOT NULL' })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** E.164 ; null une fois le compte supprimé (anonymisé). */
  @Column({ type: 'varchar', length: 20, nullable: true })
  phone!: string | null;

  @Column({ type: 'varchar', length: 60 })
  name!: string;

  @Column({ type: 'varchar', length: 500, nullable: true })
  avatarUrl!: string | null;

  /** Numéro WhatsApp du vendeur s'il diffère de `phone`. */
  @Column({ type: 'varchar', length: 20, nullable: true })
  whatsappPhone!: string | null;

  @Column({ default: false })
  isSeller!: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  deletedAt!: Date | null;
}

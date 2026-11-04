import type { User } from './user.entity.js';

export interface MeDto {
  id: string;
  name: string;
  phone: string | null;
  whatsappPhone: string | null;
  avatarUrl: string | null;
  isSeller: boolean;
  createdAt: string;
}

export const toMeDto = (u: User): MeDto => ({
  id: u.id,
  name: u.name,
  phone: u.phone,
  whatsappPhone: u.whatsappPhone,
  avatarUrl: u.avatarUrl,
  isSeller: u.isSeller,
  createdAt: u.createdAt.toISOString(),
});

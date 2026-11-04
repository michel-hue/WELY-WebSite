import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { User } from './user.entity.js';
import { notFound } from '../common/errors/app-error.js';

@Injectable()
export class UsersService {
  constructor(@InjectRepository(User) readonly repo: Repository<User>) {}

  findActiveByPhone(phone: string): Promise<User | null> {
    return this.repo.findOne({ where: { phone, deletedAt: IsNull() } });
  }

  findActiveById(id: string): Promise<User | null> {
    return this.repo.findOne({ where: { id, deletedAt: IsNull() } });
  }

  async getActive(id: string): Promise<User> {
    const user = await this.findActiveById(id);
    if (!user) throw notFound('USER_NOT_FOUND', 'Compte introuvable.');
    return user;
  }

  create(phone: string, name: string): Promise<User> {
    return this.repo.save(this.repo.create({ phone, name }));
  }
}

import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service.js';
import { UserRole } from '../users/user.entity.js';
import { IAuthService } from './interfaces/auth-service.interface.js';
import * as bcrypt from 'bcrypt';

export type { IAuthService };

@Injectable()
export class AuthService implements IAuthService {
  constructor(private readonly users: UsersService, private readonly jwt: JwtService) {}

  private async hash(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }

  private async verify(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  async register(email: string, password: string, role: UserRole = UserRole.BUYER) {
    const existing = await this.users.findByEmail(email);
    if (existing) throw new UnauthorizedException('Email already used');
    const user = await this.users.create(email, await this.hash(password), role);
    const token = this.jwt.sign({ sub: user.id, role: user.role });
    return { token, user: { id: user.id, email: user.email, role: user.role, createdAt: user.createdAt } };
  }

  async login(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user || !(await this.verify(password, user.passwordHash))) throw new UnauthorizedException('Invalid credentials');
    const token = this.jwt.sign({ sub: user.id, role: user.role });
    return { token, user: { id: user.id, email: user.email, role: user.role, createdAt: user.createdAt } };
  }
}
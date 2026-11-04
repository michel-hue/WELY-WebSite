import { describe, it, expect, beforeEach, vi } from 'vitest';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service.js';
import { UsersService } from '../users/users.service.js';
import { UserRole } from '../users/user.entity.js';

describe('AuthService', () => {
  let service: AuthService;
  let users: jest.Mocked<UsersService>;
  let jwt: jest.Mocked<JwtService>;

  beforeEach(() => {
    users = {
      findByEmail: vi.fn(),
      create: vi.fn(),
      findById: vi.fn(),
    } as any;
    jwt = { sign: vi.fn().mockReturnValue('token-123') } as any;
    service = new AuthService(users as any, jwt as any);
  });

  it('register success returns token + user', async () => {
    users.findByEmail.mockResolvedValue(null);
    users.create.mockResolvedValue({ id: 'u1', email: 'a@b.com', role: UserRole.BUYER, createdAt: new Date() } as any);
    const res = await service.register('a@b.com', 'password123');
    expect(res.token).toBe('token-123');
    expect(res.user.email).toBe('a@b.com');
  });

  it('register duplicate email throws', async () => {
    users.findByEmail.mockResolvedValue({ id: 'u0' } as any);
    await expect(service.register('a@b.com', 'password123')).rejects.toThrow();
  });

  it('login success returns token + user', async () => {
    users.findByEmail.mockResolvedValue({ id: 'u1', email: 'a@b.com', role: UserRole.BUYER, passwordHash: await (service as any).hash('password123'), createdAt: new Date() } as any);
    const res = await service.login('a@b.com', 'password123');
    expect(res.token).toBe('token-123');
  });

  it('login wrong password throws', async () => {
    users.findByEmail.mockResolvedValue({ id: 'u1', email: 'a@b.com', role: UserRole.BUYER, passwordHash: 'wrong', createdAt: new Date() } as any);
    await expect(service.login('a@b.com', 'password123')).rejects.toThrow();
  });
});
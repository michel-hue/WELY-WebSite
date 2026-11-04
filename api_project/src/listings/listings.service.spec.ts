import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ListingsService } from './listings.service.js';

describe('ListingsService', () => {
  let service: ListingsService;
  let repo: any;

  beforeEach(() => {
    repo = {
      create: vi.fn((d) => d),
      save: vi.fn(async (d) => d),
      find: vi.fn(async () => []),
      findOne: vi.fn(),
      remove: vi.fn(async () => {}),
    };
    service = new ListingsService(repo);
  });

  it('create sets ownerId', async () => {
    const l = await service.create({ title: 't' } as any, 'u1');
    expect(repo.create).toHaveBeenCalled();
    expect((l as any).ownerId).toBe('u1');
  });

  it('findOne throws 404 when missing', async () => {
    repo.findOne.mockResolvedValue(null);
    await expect(service.findOne('x')).rejects.toThrow();
  });

  it('update throws 403 if not owner', async () => {
    repo.findOne.mockResolvedValue({ id: 'l1', ownerId: 'other' });
    await expect(service.update('l1', { title: 'y' } as any, 'u1')).rejects.toThrow();
  });

  it('remove throws 403 if not owner', async () => {
    repo.findOne.mockResolvedValue({ id: 'l1', ownerId: 'other' });
    await expect(service.remove('l1', 'u1')).rejects.toThrow();
  });

  it('update success', async () => {
    const l = { id: 'l1', ownerId: 'u1', title: 'old' };
    repo.findOne.mockResolvedValue(l);
    repo.save.mockResolvedValue({ ...l, title: 'new' });
    const r = await service.update('l1', { title: 'new' } as any, 'u1');
    expect(r.title).toBe('new');
  });
});
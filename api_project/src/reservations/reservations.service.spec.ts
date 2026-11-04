import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ReservationsService, ReservationStatus } from './reservations.service.js';

describe('ReservationsService', () => {
  let service: ReservationsService;
  let repo: any;
  let listingsRepo: any;

  beforeEach(() => {
    repo = {
      create: vi.fn((d) => d),
      save: vi.fn(async (d) => d),
      find: vi.fn(async () => []),
      findOne: vi.fn(),
    };
    listingsRepo = {
      findOne: vi.fn(),
    };
    service = new ReservationsService(repo, listingsRepo);
  });

  it('create throws 404 when listing missing', async () => {
    listingsRepo.findOne.mockResolvedValue(null);
    await expect(service.create('l1', 'u1')).rejects.toThrow();
  });

  it('create throws 400 when buyer is owner', async () => {
    listingsRepo.findOne.mockResolvedValue({ id: 'l1', ownerId: 'u1' });
    await expect(service.create('l1', 'u1')).rejects.toThrow();
  });

  it('create success', async () => {
    listingsRepo.findOne.mockResolvedValue({ id: 'l1', ownerId: 'owner' });
    const r = await service.create('l1', 'buyer');
    expect(repo.create).toHaveBeenCalled();
    expect((r as any).status).toBe(ReservationStatus.PENDING);
  });

  it('findMine returns list', async () => {
    repo.find.mockResolvedValue([{ id: 'r1' }]);
    const r = await service.findMine('buyer');
    expect(r).toHaveLength(1);
  });

  it('findOne throws 404 when missing', async () => {
    repo.findOne.mockResolvedValue(null);
    await expect(service.findOne('x', 'u1')).rejects.toThrow();
  });

  it('findOne throws 403 when not allowed', async () => {
    repo.findOne.mockResolvedValue({ id: 'r1', buyerId: 'other', listingId: 'l1' });
    listingsRepo.findOne.mockResolvedValue({ id: 'l1', ownerId: 'someone' });
    await expect(service.findOne('r1', 'u1')).rejects.toThrow();
  });

  it('updateStatus throws 403 if not owner', async () => {
    repo.findOne.mockResolvedValue({ id: 'r1', listingId: 'l1' });
    listingsRepo.findOne.mockResolvedValue({ id: 'l1', ownerId: 'other' });
    await expect(service.updateStatus('r1', ReservationStatus.CONFIRMED, 'u1')).rejects.toThrow();
  });

  it('updateStatus success', async () => {
    const r = { id: 'r1', listingId: 'l1', status: ReservationStatus.PENDING };
    repo.findOne.mockResolvedValue(r);
    listingsRepo.findOne.mockResolvedValue({ id: 'l1', ownerId: 'u1' });
    repo.save.mockResolvedValue({ ...r, status: ReservationStatus.CONFIRMED });
    const res = await service.updateStatus('r1', ReservationStatus.CONFIRMED, 'u1');
    expect(res.status).toBe(ReservationStatus.CONFIRMED);
  });
}); 
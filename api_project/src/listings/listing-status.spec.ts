import { assertTransition, type ListingAction, type ListingStatus } from './listing-status.js';
import { AppError } from '../common/errors/app-error.js';

describe('assertTransition', () => {
  it.each<[ListingStatus, ListingAction, ListingStatus]>([
    ['draft', 'publish', 'online'],
    ['online', 'deactivate', 'deactivated'],
    ['online', 'close', 'closed'],
    ['expired', 'reactivate', 'online'],
    ['deactivated', 'reactivate', 'online'],
    ['closed', 'reactivate', 'online'],
  ])('%s --%s--> %s', (from, action, to) => {
    expect(assertTransition(from, action)).toBe(to);
  });

  it.each<[ListingStatus, ListingAction]>([
    ['draft', 'close'],
    ['draft', 'reactivate'],
    ['online', 'publish'],
    ['online', 'reactivate'],
    ['closed', 'deactivate'],
    ['expired', 'close'],
  ])('refuses %s --%s-->', (from, action) => {
    try {
      assertTransition(from, action);
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(AppError);
      expect((e as AppError).code).toBe('INVALID_LISTING_TRANSITION');
      expect((e as AppError).getStatus()).toBe(422);
    }
  });
});

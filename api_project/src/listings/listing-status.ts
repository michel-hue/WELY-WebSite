import { unprocessable } from '../common/errors/app-error.js';

export const LISTING_STATUSES = ['draft', 'online', 'expired', 'deactivated', 'closed'] as const;
export type ListingStatus = (typeof LISTING_STATUSES)[number];
export type ListingAction = 'publish' | 'deactivate' | 'close' | 'reactivate';

// online → expired est réservé à la tâche d'expiration (jobs/expiry.job.ts).
const TRANSITIONS: Record<ListingAction, { from: ListingStatus[]; to: ListingStatus }> = {
  publish: { from: ['draft'], to: 'online' },
  deactivate: { from: ['online'], to: 'deactivated' },
  close: { from: ['online'], to: 'closed' },
  reactivate: { from: ['expired', 'deactivated', 'closed'], to: 'online' },
};

export function assertTransition(from: ListingStatus, action: ListingAction): ListingStatus {
  const rule = TRANSITIONS[action];
  if (!rule.from.includes(from)) {
    throw unprocessable('INVALID_LISTING_TRANSITION', 'Cette action n’est pas possible dans l’état actuel de l’annonce.');
  }
  return rule.to;
}

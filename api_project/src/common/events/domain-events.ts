export const OFFER_TYPES = ['monthly', 'nightly', 'sale'] as const;
export type OfferType = (typeof OFFER_TYPES)[number];

/**
 * Une annonce n'accepte plus (tout ou partie) des demandes :
 * - sans `offerTypes` : l'annonce a quitté l'état « en ligne » (ou a été supprimée) ;
 * - avec `offerTypes` : ces offres ont été retirées de l'annonce.
 * Émis avec `emitAsync` : les écouteurs sont attendus.
 */
export const LISTING_UNAVAILABLE = 'listing.unavailable';
export interface ListingUnavailableEvent {
  listingId: string;
  offerTypes?: OfferType[];
}

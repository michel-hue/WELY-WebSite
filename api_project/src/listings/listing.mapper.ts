import type { OfferType } from '../common/events/domain-events.js';
import type { Listing } from './listing.entity.js';

export interface PhotoDto {
  id: string;
  thumbUrl: string;
  largeUrl: string;
  width: number;
  height: number;
  position: number;
}

export interface OffersView {
  monthly?: { rent: number; terms: string | null };
  nightly?: { price: number; minNights: number | null };
  sale?: { price: number };
}

export const offersOf = (l: Listing): OffersView => ({
  ...(l.monthlyRent != null ? { monthly: { rent: l.monthlyRent, terms: l.monthlyTerms } } : {}),
  ...(l.nightlyPrice != null ? { nightly: { price: l.nightlyPrice, minNights: l.minNights } } : {}),
  ...(l.salePrice != null ? { sale: { price: l.salePrice } } : {}),
});

export const offerTypesOf = (l: Listing): OfferType[] =>
  [l.monthlyRent != null && 'monthly', l.nightlyPrice != null && 'nightly', l.salePrice != null && 'sale'].filter(
    Boolean,
  ) as OfferType[];

export const locationOf = (l: Listing): { lat: number; lng: number } | null =>
  l.location ? { lat: l.location.coordinates[1], lng: l.location.coordinates[0] } : null;

export interface SellerListingDto {
  id: string;
  status: Listing['status'];
  closedReason: Listing['closedReason'];
  title: string;
  description: string;
  propertyType: Listing['propertyType'];
  rooms: number;
  bedrooms: number | null;
  bathrooms: number | null;
  surfaceM2: number | null;
  amenities: Listing['amenities'];
  city: string;
  district: string;
  address: string | null;
  location: { lat: number; lng: number } | null;
  offers: OffersView;
  publishedUntil: string | null;
  publishedAt: string | null;
  photos: PhotoDto[];
  /** Compteurs visibles du seul vendeur. */
  stats: { views: number; contactClicks: number; requests: number };
  createdAt: string;
  updatedAt: string;
}

export const toSellerListingDto = (l: Listing, photos: PhotoDto[] = []): SellerListingDto => ({
  id: l.id,
  status: l.status,
  closedReason: l.closedReason,
  title: l.title,
  description: l.description,
  propertyType: l.propertyType,
  rooms: l.rooms,
  bedrooms: l.bedrooms,
  bathrooms: l.bathrooms,
  surfaceM2: l.surfaceM2,
  amenities: l.amenities,
  city: l.city,
  district: l.district,
  address: l.address,
  location: locationOf(l),
  offers: offersOf(l),
  publishedUntil: l.publishedUntil,
  publishedAt: l.publishedAt?.toISOString() ?? null,
  photos,
  stats: { views: l.viewCount, contactClicks: l.contactClickCount, requests: l.requestCount },
  createdAt: l.createdAt.toISOString(),
  updatedAt: l.updatedAt.toISOString(),
});

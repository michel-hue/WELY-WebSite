import type { Listing } from '../listings/listing.entity.js';
import { locationOf, offersOf, type OffersView, type PhotoDto } from '../listings/listing.mapper.js';
import type { User } from '../users/user.entity.js';

/** Carte de liste : jamais de coordonnées exactes. */
export interface ListingCardDto {
  id: string;
  title: string;
  propertyType: Listing['propertyType'];
  city: string;
  district: string;
  coverThumbUrl: string | null;
  offers: OffersView;
  rooms: number;
  distanceMeters: number | null;
  publishedAt: string | null;
}

export interface PublicSellerDto {
  id: string;
  name: string;
  avatarUrl: string | null;
  memberSince: string;
  onlineListingsCount: number;
  phone: string | null;
  whatsappPhone: string | null;
}

export interface PublicListingDto extends ListingCardDto {
  description: string;
  bedrooms: number | null;
  bathrooms: number | null;
  surfaceM2: number | null;
  amenities: Listing['amenities'];
  address: string | null;
  location: { lat: number; lng: number } | null;
  photos: PhotoDto[];
  seller: PublicSellerDto;
}

export const toCardDto = (l: Listing, cover: PhotoDto | undefined, distance: number | null): ListingCardDto => ({
  id: l.id,
  title: l.title,
  propertyType: l.propertyType,
  city: l.city,
  district: l.district,
  coverThumbUrl: cover?.thumbUrl ?? null,
  offers: offersOf(l),
  rooms: l.rooms,
  distanceMeters: distance === null ? null : Math.round(distance),
  publishedAt: l.publishedAt?.toISOString() ?? null,
});

export const toPublicDto = (l: Listing, photos: PhotoDto[], seller: User, onlineListingsCount: number): PublicListingDto => ({
  ...toCardDto(l, photos[0], null),
  description: l.description,
  bedrooms: l.bedrooms,
  bathrooms: l.bathrooms,
  surfaceM2: l.surfaceM2,
  amenities: l.amenities,
  address: l.address,
  location: locationOf(l),
  photos,
  seller: {
    id: seller.id,
    name: seller.name,
    avatarUrl: seller.avatarUrl,
    memberSince: seller.createdAt.toISOString(),
    onlineListingsCount,
    phone: seller.phone,
    whatsappPhone: seller.whatsappPhone ?? seller.phone,
  },
});

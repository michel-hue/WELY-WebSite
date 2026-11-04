import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsDefined,
  IsIn,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateIf,
  type ValidationArguments,
  ValidatorConstraint,
  type ValidatorConstraintInterface,
  Validate,
} from 'class-validator';
import { OFFER_TYPES, type OfferType } from '../common/events/domain-events.js';
import { PaginationQuery } from '../common/pagination/paginated.js';
import { AMENITIES, PROPERTY_TYPES, type Amenity, type PropertyType } from '../listings/listing.entity.js';

export const SORTS = ['distance', 'recent', 'price_asc', 'price_desc'] as const;
export type SearchSort = (typeof SORTS)[number];

const DATE = /^\d{4}-\d{2}-\d{2}$/;

/** `a=1&a=2` ou `a=1,2` → ['1', '2'] */
const toList = ({ value }: { value: unknown }) =>
  value === undefined
    ? undefined
    : (Array.isArray(value) ? value : [value]).flatMap((v) => String(v).split(',')).map((v) => v.trim()).filter(Boolean);

const needsOfferType = (o: SearchQuery) =>
  o.priceMin !== undefined ||
  o.priceMax !== undefined ||
  o.sort === 'price_asc' ||
  o.sort === 'price_desc' ||
  o.checkIn !== undefined ||
  o.checkOut !== undefined;

@ValidatorConstraint({ name: 'nightlyForDates' })
class NightlyForDates implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments) {
    const o = args.object as SearchQuery;
    return (o.checkIn === undefined && o.checkOut === undefined) || value === 'nightly';
  }
  defaultMessage() {
    return 'Les dates de séjour exigent offerType=nightly.';
  }
}

@ValidatorConstraint({ name: 'coordinatesForDistance' })
class CoordinatesForDistance implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments) {
    const o = args.object as SearchQuery;
    return value !== 'distance' || (o.lat !== undefined && o.lng !== undefined);
  }
  defaultMessage() {
    return 'Le tri par distance exige lat et lng.';
  }
}

@ValidatorConstraint({ name: 'checkOutAfterCheckIn' })
class CheckOutAfterCheckIn implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments) {
    const o = args.object as SearchQuery;
    return typeof value === 'string' && typeof o.checkIn === 'string' && value > o.checkIn;
  }
  defaultMessage() {
    return 'La date de départ doit suivre la date d’arrivée.';
  }
}

export class SearchQuery extends PaginationQuery {
  @ApiPropertyOptional({ example: 5.36 })
  @ValidateIf((o: SearchQuery) => o.lat !== undefined || o.lng !== undefined)
  @IsDefined({ message: 'lat et lng vont ensemble.' })
  @Type(() => Number)
  @IsLatitude()
  lat?: number;

  @ApiPropertyOptional({ example: -3.98 })
  @ValidateIf((o: SearchQuery) => o.lat !== undefined || o.lng !== undefined)
  @IsDefined({ message: 'lat et lng vont ensemble.' })
  @Type(() => Number)
  @IsLongitude()
  lng?: number;

  @ApiPropertyOptional({ default: 10, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.1)
  @Max(100)
  radiusKm: number = 10;

  @ApiPropertyOptional({ description: 'Texte libre (titre, quartier, ville, description)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @ApiPropertyOptional({ enum: OFFER_TYPES })
  @ValidateIf((o: SearchQuery) => o.offerType !== undefined || needsOfferType(o))
  @IsDefined({ message: 'Précisez le type d’offre (offerType).' })
  @IsIn(OFFER_TYPES)
  @Validate(NightlyForDates)
  offerType?: OfferType;

  @ApiPropertyOptional({ enum: PROPERTY_TYPES, isArray: true })
  @IsOptional()
  @Transform(toList)
  @IsIn(PROPERTY_TYPES, { each: true })
  propertyType?: PropertyType[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  district?: string;

  @ApiPropertyOptional({ description: 'Prix minimum de l’offre choisie (FCFA)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  priceMin?: number;

  @ApiPropertyOptional({ description: 'Prix maximum de l’offre choisie (FCFA)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  priceMax?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  roomsMin?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  bedroomsMin?: number;

  @ApiPropertyOptional({ enum: AMENITIES, isArray: true, description: 'Tous requis' })
  @IsOptional()
  @Transform(toList)
  @IsIn(AMENITIES, { each: true })
  amenities?: Amenity[];

  @ApiPropertyOptional({ example: '2026-12-10' })
  @ValidateIf((o: SearchQuery) => o.checkIn !== undefined || o.checkOut !== undefined)
  @Matches(DATE, { message: 'Date attendue au format AAAA-MM-JJ.' })
  checkIn?: string;

  @ApiPropertyOptional({ example: '2026-12-12' })
  @ValidateIf((o: SearchQuery) => o.checkIn !== undefined || o.checkOut !== undefined)
  @Matches(DATE, { message: 'Date attendue au format AAAA-MM-JJ.' })
  @Validate(CheckOutAfterCheckIn)
  checkOut?: string;

  @ApiPropertyOptional({ enum: SORTS, description: 'Par défaut : distance si lat/lng, sinon recent' })
  @IsOptional()
  @IsIn(SORTS)
  @Validate(CoordinatesForDistance)
  sort?: SearchSort;
}

import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { AMENITIES, PROPERTY_TYPES, type Amenity, type PropertyType } from '../listing.entity.js';
import { PaginationQuery } from '../../common/pagination/paginated.js';

/** Plus grand entier PostgreSQL « int » (loyers, prix par nuit). */
const MAX_INT = 2_147_483_647;
const TOO_HIGH = { message: 'Montant trop élevé.' };

export class LocationDto {
  @ApiProperty({ example: 5.3599 })
  @IsLatitude()
  lat!: number;

  @ApiProperty({ example: -3.9873 })
  @IsLongitude()
  lng!: number;
}

export class MonthlyOfferDto {
  @ApiProperty({ example: 350000, description: 'Loyer mensuel en FCFA' })
  @IsInt()
  @Min(1)
  @Max(MAX_INT, TOO_HIGH)
  rent!: number;

  @ApiPropertyOptional({ example: '3 mois de caution, 2 mois d’avance' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  terms?: string;
}

export class NightlyOfferDto {
  @ApiProperty({ example: 30000, description: 'Prix par nuit en FCFA' })
  @IsInt()
  @Min(1)
  @Max(MAX_INT, TOO_HIGH)
  price!: number;

  @ApiPropertyOptional({ example: 2 })
  @IsOptional()
  @IsInt()
  @Min(1)
  minNights?: number;
}

export class SaleOfferDto {
  @ApiProperty({ example: 85000000, description: 'Prix de vente en FCFA' })
  @IsInt()
  @Min(1)
  @Max(Number.MAX_SAFE_INTEGER, TOO_HIGH)
  price!: number;
}

/** Offres de l'annonce ; `null` retire une offre lors d'une modification. */
export class OffersDto {
  @ApiPropertyOptional({ type: MonthlyOfferDto, nullable: true })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @ValidateNested()
  @Type(() => MonthlyOfferDto)
  monthly?: MonthlyOfferDto | null;

  @ApiPropertyOptional({ type: NightlyOfferDto, nullable: true })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @ValidateNested()
  @Type(() => NightlyOfferDto)
  nightly?: NightlyOfferDto | null;

  @ApiPropertyOptional({ type: SaleOfferDto, nullable: true })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @ValidateNested()
  @Type(() => SaleOfferDto)
  sale?: SaleOfferDto | null;
}

export class CreateListingDto {
  @ApiProperty({ example: 'Villa contemporaine' })
  @IsString()
  @Length(3, 120)
  title!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @ApiProperty({ enum: PROPERTY_TYPES })
  @IsIn(PROPERTY_TYPES)
  propertyType!: PropertyType;

  @ApiPropertyOptional({ example: 4 })
  @IsOptional()
  @IsInt()
  @Min(0)
  rooms?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  bedrooms?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  bathrooms?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  surfaceM2?: number;

  @ApiPropertyOptional({ enum: AMENITIES, isArray: true })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(AMENITIES.length)
  @IsIn(AMENITIES, { each: true })
  amenities?: Amenity[];

  @ApiProperty({ example: 'Abidjan' })
  @IsString()
  @Length(2, 80)
  city!: string;

  @ApiProperty({ example: 'Cocody, Angré' })
  @IsString()
  @Length(2, 120)
  district!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  address?: string;

  @ApiPropertyOptional({ type: LocationDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => LocationDto)
  location?: LocationDto;

  @ApiPropertyOptional({ type: OffersDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => OffersDto)
  offers?: OffersDto;
}

export class UpdateListingDto extends PartialType(CreateListingDto) {}

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export class PublishDto {
  @ApiPropertyOptional({ example: '2026-12-31', description: 'Dernier jour de publication (inclus). Absent = permanente.' })
  @IsOptional()
  @Matches(DATE, { message: 'Date attendue au format AAAA-MM-JJ.' })
  until?: string;
}

export class CloseDto {
  @ApiProperty({ enum: ['rented', 'sold'] })
  @IsIn(['rented', 'sold'])
  reason!: 'rented' | 'sold';
}

export class MyListingsQuery extends PaginationQuery {
  @IsOptional()
  @IsIn(['draft', 'online', 'expired', 'deactivated', 'closed'])
  status?: string;
}

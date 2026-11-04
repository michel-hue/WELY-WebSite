import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, IsUUID, Matches, MaxLength, ValidateIf } from 'class-validator';
import { OFFER_TYPES, type OfferType } from '../../common/events/domain-events.js';
import { PaginationQuery } from '../../common/pagination/paginated.js';

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const DATE_MSG = { message: 'Date attendue au format AAAA-MM-JJ.' };

export class CreateRequestDto {
  @ApiProperty()
  @IsUUID()
  listingId!: string;

  @ApiProperty({ enum: OFFER_TYPES })
  @IsIn(OFFER_TYPES)
  offerType!: OfferType;

  @ApiPropertyOptional({ example: '2026-12-10', description: 'Obligatoire pour une demande à la nuit' })
  @ValidateIf((o: CreateRequestDto) => o.offerType === 'nightly' || o.checkIn !== undefined)
  @Matches(DATE, DATE_MSG)
  checkIn?: string;

  @ApiPropertyOptional({ example: '2026-12-13', description: 'Obligatoire pour une demande à la nuit' })
  @ValidateIf((o: CreateRequestDto) => o.offerType === 'nightly' || o.checkOut !== undefined)
  @Matches(DATE, DATE_MSG)
  checkOut?: string;

  @ApiPropertyOptional({ example: '2027-01-01', description: 'Date d’emménagement souhaitée (location au mois)' })
  @IsOptional()
  @Matches(DATE, DATE_MSG)
  moveInDate?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  wantsVisit?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  message?: string;
}

export class DecisionDto {
  @ApiPropertyOptional({ description: 'Message pour l’acheteur' })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  message?: string;
}

export class RequestsQuery extends PaginationQuery {
  @IsOptional()
  @IsIn(['pending', 'accepted', 'refused', 'cancelled'])
  status?: string;

  @IsOptional()
  @IsUUID()
  listingId?: string;
}

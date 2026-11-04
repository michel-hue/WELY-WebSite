import { IsEnum, IsInt, IsNumber, IsOptional, IsString, IsUrl, Min, MinLength } from 'class-validator';
import { ListingType, ListingStatus } from '../listing.entity.js';

export class CreateListingDto {
  @IsString() @MinLength(3) title!: string;
  @IsString() description!: string;
  @IsNumber() @Min(0) price!: number;
  @IsString() city!: string;
  @IsEnum(ListingType) type!: ListingType;
  @IsInt() @Min(1) rooms!: number;
  @IsOptional() photos?: string[];
  @IsOptional() @IsEnum(ListingStatus) status?: ListingStatus;
}

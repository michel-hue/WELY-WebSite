import { IsUUID } from 'class-validator';

export class CreateReservationDto {
  @IsUUID() listingId!: string;
}
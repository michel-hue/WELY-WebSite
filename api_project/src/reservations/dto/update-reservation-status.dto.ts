import { IsEnum } from 'class-validator';
import { ReservationStatus } from '../reservation.entity.js';

export class UpdateReservationStatusDto {
  @IsEnum(ReservationStatus)
  status!: ReservationStatus;
}

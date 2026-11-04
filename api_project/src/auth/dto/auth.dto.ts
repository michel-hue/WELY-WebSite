import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({ example: '07 07 07 07 07' })
  @IsString()
  @MaxLength(30)
  phone!: string;

  @ApiPropertyOptional({ enum: ['sms', 'whatsapp'], default: 'sms' })
  @IsOptional()
  @IsIn(['sms', 'whatsapp'])
  channel?: 'sms' | 'whatsapp';
}

export class VerifyOtpDto {
  @ApiProperty({ example: '07 07 07 07 07' })
  @IsString()
  @MaxLength(30)
  phone!: string;

  @ApiProperty({ example: '123456' })
  @Matches(/^\d{6}$/, { message: 'Le code contient 6 chiffres.' })
  code!: string;

  @ApiPropertyOptional({ description: 'Obligatoire pour créer un compte (2 à 60 caractères).', example: 'Awa Koné' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  name?: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @MaxLength(200)
  refreshToken!: string;
}

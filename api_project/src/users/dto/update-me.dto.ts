import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, IsUrl, Length, MaxLength, ValidateIf } from 'class-validator';

export class UpdateMeDto {
  @ApiPropertyOptional({ example: 'Awa Koné' })
  @IsOptional()
  @IsString()
  @Length(2, 60)
  name?: string;

  @ApiPropertyOptional({ description: 'Numéro WhatsApp si différent du téléphone ; null pour le retirer', nullable: true })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(30)
  whatsappPhone?: string | null;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsUrl({ require_protocol: true })
  @MaxLength(500)
  avatarUrl?: string | null;
}

export class SellerModeDto {
  @IsBoolean()
  enabled!: boolean;
}

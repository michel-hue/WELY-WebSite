import { Body, Controller, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { OptionalAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { InstallationId } from '../common/http/installation-id.decorator.js';
import { REPORT_REASONS, type ReportReason } from './report.entity.js';
import { ReportsService } from './reports.service.js';

class ReportDto {
  @IsIn(REPORT_REASONS)
  reason!: ReportReason;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;
}

@ApiTags('consultation')
@UseGuards(OptionalAuthGuard)
@Controller('listings/:id/reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Post()
  @ApiOperation({ summary: 'Signaler une annonce (elle est masquée pour vous seulement)' })
  report(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReportDto,
    @CurrentUser() user?: AuthUser,
    @InstallationId() installationId?: string,
  ) {
    return this.reports.report(id, { userId: user?.id, installationId }, dto.reason, dto.comment);
  }
}

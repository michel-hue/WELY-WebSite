import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { badRequest, notFound, unprocessable } from '../common/errors/app-error.js';
import { Listing } from '../listings/listing.entity.js';
import type { Viewer } from '../search/search.service.js';
import { Report, type ReportReason } from './report.entity.js';

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(Report) private readonly repo: Repository<Report>,
    @InjectRepository(Listing) private readonly listings: Repository<Listing>,
  ) {}

  async report(listingId: string, viewer: Viewer, reason: ReportReason, comment?: string): Promise<{ id: string }> {
    if (!viewer.userId && !viewer.installationId) {
      throw badRequest('INSTALLATION_ID_REQUIRED', 'Identifiant d’installation manquant (en-tête X-Installation-Id).');
    }
    const listing = await this.listings.findOne({ where: { id: listingId, deletedAt: IsNull() } });
    if (!listing) throw notFound('LISTING_NOT_FOUND', 'Annonce introuvable.');
    if (viewer.userId && listing.ownerId === viewer.userId) {
      throw unprocessable('CANNOT_REPORT_OWN_LISTING', 'Vous ne pouvez pas signaler votre propre annonce.');
    }

    // Un seul signalement par annonce et par auteur (utilisateur ou installation).
    const existing = await this.repo
      .createQueryBuilder('r')
      .where('r.listing_id = :listingId', { listingId })
      .andWhere(viewer.userId ? 'r.user_id = :userId' : 'r.installation_id = :installationId', viewer)
      .getOne();
    if (existing) return { id: existing.id };

    const saved = await this.repo.save(
      this.repo.create({
        listingId,
        userId: viewer.userId ?? null,
        installationId: viewer.installationId ?? null,
        reason,
        comment: comment?.trim() || null,
      }),
    );
    return { id: saved.id };
  }
}

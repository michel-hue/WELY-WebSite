import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import type { Env } from '../config/env.validation.js';
import { ListingsModule } from '../listings/listings.module.js';
import { ListingPhoto } from './listing-photo.entity.js';
import { PhotosController } from './photos.controller.js';
import { PhotosService } from './photos.service.js';
import { LocalStorage } from './storage/local-storage.js';
import { S3Storage } from './storage/s3-storage.js';
import { STORAGE } from './storage/storage.js';

export function createStorage(cfg: ConfigService<Env, true>) {
  const publicBase = cfg.get('PUBLIC_MEDIA_BASE_URL', { infer: true });
  if (cfg.get('STORAGE_DRIVER', { infer: true }) === 's3') {
    return new S3Storage({
      endpoint: cfg.get('S3_ENDPOINT', { infer: true }),
      region: cfg.get('S3_REGION', { infer: true }) ?? 'auto',
      bucket: cfg.get('S3_BUCKET', { infer: true }) ?? '',
      accessKeyId: cfg.get('S3_ACCESS_KEY_ID', { infer: true }) ?? '',
      secretAccessKey: cfg.get('S3_SECRET_ACCESS_KEY', { infer: true }) ?? '',
      publicBaseUrl: publicBase ?? '',
    });
  }
  return new LocalStorage(cfg.get('MEDIA_DIR', { infer: true }), publicBase || '/media');
}

@Module({
  imports: [TypeOrmModule.forFeature([ListingPhoto]), ListingsModule],
  controllers: [PhotosController],
  providers: [PhotosService, { provide: STORAGE, inject: [ConfigService], useFactory: createStorage }],
  exports: [PhotosService, STORAGE],
})
export class PhotosModule {}

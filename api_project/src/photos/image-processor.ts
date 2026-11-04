import sharp, { type Metadata } from 'sharp';
import { badRequest } from '../common/errors/app-error.js';

export const THUMB_WIDTH = 480;
export const LARGE_MAX = 1600;
/** Au-delà, l'image est refusée avant décodage (mémoire). */
export const MAX_INPUT_PIXELS = 50_000_000;

sharp.concurrency(1);

export interface ProcessedImage {
  thumb: Buffer;
  large: Buffer;
  width: number;
  height: number;
}

/**
 * Prépare une photo : orientation EXIF appliquée, métadonnées supprimées (GPS…),
 * vignette 480 px de large et grande version 1600 px max, en webp.
 */
export async function processImage(input: Buffer): Promise<ProcessedImage> {
  let meta: Metadata;
  try {
    meta = await sharp(input).metadata();
  } catch {
    throw badRequest('UNSUPPORTED_IMAGE', 'Image illisible. Formats acceptés : JPEG, PNG, WebP.');
  }
  if ((meta.width ?? 0) * (meta.height ?? 0) > MAX_INPUT_PIXELS) {
    throw badRequest('IMAGE_TOO_LARGE', 'Image trop grande (50 mégapixels maximum).');
  }
  try {
    const base = sharp(input, { failOn: 'error', limitInputPixels: MAX_INPUT_PIXELS }).rotate();
    const large = await base
      .clone()
      .resize({ width: LARGE_MAX, height: LARGE_MAX, fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 80 })
      .toBuffer({ resolveWithObject: true });
    const thumb = await base
      .clone()
      .resize({ width: THUMB_WIDTH, withoutEnlargement: true })
      .webp({ quality: 72 })
      .toBuffer();
    return { thumb, large: large.data, width: large.info.width, height: large.info.height };
  } catch {
    throw badRequest('UNSUPPORTED_IMAGE', 'Image illisible. Formats acceptés : JPEG, PNG, WebP.');
  }
}

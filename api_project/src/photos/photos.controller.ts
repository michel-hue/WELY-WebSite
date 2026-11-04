import {
  Body,
  Controller,
  Delete,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsUUID } from 'class-validator';
import { memoryStorage } from 'multer';
import { JwtAuthGuard, type AuthUser } from '../common/auth/jwt-auth.guard.js';
import { badRequest } from '../common/errors/app-error.js';
import { CurrentUser } from '../common/http/current-user.decorator.js';
import { MAX_PHOTOS_PER_LISTING, PhotosService } from './photos.service.js';

class PhotoOrderDto {
  @IsArray()
  @ArrayMaxSize(MAX_PHOTOS_PER_LISTING)
  @IsUUID('4', { each: true })
  photoIds!: string[];
}

const ALLOWED = new Set(['image/jpeg', 'image/png', 'image/webp']);

@ApiTags('annonces (vendeur)')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('listings/:id/photos')
export class PhotosController {
  constructor(private readonly photos: PhotosService) {}

  @Post()
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Ajouter des photos (champ « photos », 10 par envoi, 8 Mo max chacune)' })
  @UseInterceptors(
    FilesInterceptor('photos', 10, {
      storage: memoryStorage(),
      limits: { fileSize: 8 * 1024 * 1024 },
      fileFilter: (_req, file, cb) =>
        ALLOWED.has(file.mimetype)
          ? cb(null, true)
          : cb(badRequest('UNSUPPORTED_IMAGE', 'Image illisible. Formats acceptés : JPEG, PNG, WebP.'), false),
    }),
  )
  add(
    @CurrentUser() u: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFiles() files: Express.Multer.File[] = [],
  ) {
    return this.photos.add(u.id, id, files);
  }

  @Put('order')
  @HttpCode(204)
  @ApiOperation({ summary: 'Réordonner les photos (la première devient la couverture)' })
  async reorder(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PhotoOrderDto) {
    await this.photos.reorder(u.id, id, dto.photoIds);
  }

  @Delete(':photoId')
  @HttpCode(204)
  async remove(
    @CurrentUser() u: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
  ) {
    await this.photos.remove(u.id, id, photoId);
  }
}

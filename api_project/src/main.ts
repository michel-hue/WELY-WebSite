import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module.js';
import * as express from 'express';
import * as path from 'path';

async function bootstrap() {
  if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET is required in production');
  }
  if (!process.env.JWT_SECRET) {
    console.warn('WARNING: JWT_SECRET not set, using dev default');
  }
  const app = await NestFactory.create(AppModule);
  const corsOrigin = process.env.CORS_ORIGIN || (process.env.NODE_ENV === 'production' ? false : true);
  app.enableCors({ origin: corsOrigin, credentials: true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
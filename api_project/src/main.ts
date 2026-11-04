import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module.js';
import { configureApp } from './app.factory.js';
import type { Env } from './config/env.validation.js';

async function bootstrap() {
  const app = configureApp(await NestFactory.create(AppModule));
  await app.listen(app.get(ConfigService<Env, true>).get('PORT', { infer: true }));
}
await bootstrap();

import { BadRequestException, type INestApplication, ValidationPipe, type ValidationError } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AllExceptionsFilter } from './common/errors/all-exceptions.filter.js';
import { badRequest } from './common/errors/app-error.js';
import type { Env } from './config/env.validation.js';

function flatten(errors: ValidationError[], parent = ''): { field: string; message: string }[] {
  return errors.flatMap((e) => {
    const field = parent ? `${parent}.${e.property}` : e.property;
    const own = Object.values(e.constraints ?? {}).map((message) => ({ field, message }));
    return [...own, ...flatten(e.children ?? [], field)];
  });
}

/** Paramétrage HTTP commun à main.ts et aux tests e2e. */
export function configureApp(app: INestApplication): INestApplication {
  const cfg = app.get(ConfigService<Env, true>);
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  const cors = cfg.get('CORS_ORIGIN', { infer: true });
  app.enableCors({ origin: cors ? cors.split(',').map((s) => s.trim()) : cfg.get('NODE_ENV', { infer: true }) !== 'production' });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      exceptionFactory: (errors): BadRequestException =>
        badRequest('VALIDATION_ERROR', 'Certaines informations sont invalides.', flatten(errors)),
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());

  if (cfg.get('NODE_ENV', { infer: true }) !== 'production') {
    const doc = SwaggerModule.createDocument(
      app,
      new DocumentBuilder()
        .setTitle('WELLY API')
        .setDescription("API de mise en relation acheteurs / vendeurs de l'application WELLY.")
        .setVersion('1')
        .addBearerAuth()
        .addGlobalParameters({ name: 'X-Installation-Id', in: 'header', required: false, schema: { type: 'string', format: 'uuid' } })
        .build(),
    );
    SwaggerModule.setup('docs', app, doc);
  }
  return app;
}

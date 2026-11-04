import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import type { Response } from 'express';
import { AppError } from './app-error.js';

const DEFAULTS: Record<number, { code: string; message: string }> = {
  400: { code: 'BAD_REQUEST', message: 'Requête invalide.' },
  401: { code: 'UNAUTHORIZED', message: 'Connexion requise.' },
  403: { code: 'FORBIDDEN', message: 'Action non autorisée.' },
  404: { code: 'NOT_FOUND', message: 'Ressource introuvable.' },
  409: { code: 'CONFLICT', message: 'Conflit avec l’état actuel.' },
  413: { code: 'PAYLOAD_TOO_LARGE', message: 'Fichier ou requête trop volumineux.' },
  422: { code: 'UNPROCESSABLE', message: 'Action impossible.' },
  429: { code: 'TOO_MANY_REQUESTS', message: 'Trop de requêtes, réessayez dans un instant.' },
  500: { code: 'INTERNAL_ERROR', message: 'Une erreur inattendue est survenue.' },
};

/** Convertit toute erreur au format { error: { code, message, details? } }. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Exceptions');

  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();

    if (exception instanceof AppError) {
      return res.status(exception.getStatus()).json(exception.getResponse());
    }
    if (exception instanceof ThrottlerException) {
      return res.status(429).json({ error: DEFAULTS[429] });
    }
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const base = DEFAULTS[status] ?? { code: HttpStatus[status] ?? 'ERROR', message: exception.message };
      return res.status(status).json({ error: base });
    }

    this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    return res.status(500).json({ error: DEFAULTS[500] });
  }
}

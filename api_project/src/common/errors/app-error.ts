import { HttpException } from '@nestjs/common';

/** Erreur métier au format uniforme : { error: { code, message, details? } }. */
export class AppError extends HttpException {
  constructor(
    status: number,
    readonly code: string,
    message: string,
    readonly details?: unknown[],
  ) {
    super({ error: { code, message, ...(details ? { details } : {}) } }, status);
  }
}

export const badRequest = (code: string, message: string, details?: unknown[]) => new AppError(400, code, message, details);
export const unauthorized = (code: string, message: string) => new AppError(401, code, message);
export const forbidden = (code: string, message: string) => new AppError(403, code, message);
export const notFound = (code: string, message: string) => new AppError(404, code, message);
export const conflict = (code: string, message: string) => new AppError(409, code, message);
export const unprocessable = (code: string, message: string, details?: unknown[]) =>
  new AppError(422, code, message, details);
export const tooMany = (code: string, message: string) => new AppError(429, code, message);

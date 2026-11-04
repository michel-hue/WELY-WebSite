import { createParamDecorator, type ExecutionContext } from '@nestjs/common';
import type { AuthUser } from '../auth/jwt-auth.guard.js';

/** Utilisateur connecté (posé par JwtAuthGuard / OptionalAuthGuard). */
export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthUser | undefined => ctx.switchToHttp().getRequest().user,
);

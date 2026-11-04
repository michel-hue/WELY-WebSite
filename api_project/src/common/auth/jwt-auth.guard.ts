import { type CanActivate, type ExecutionContext, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { unauthorized } from '../errors/app-error.js';

export interface AuthUser {
  id: string;
}

async function readUser(jwt: JwtService, req: Request): Promise<AuthUser | undefined> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) return undefined;
  try {
    const payload = await jwt.verifyAsync<{ sub: string }>(header.slice(7));
    return payload.sub ? { id: payload.sub } : undefined;
  } catch {
    return undefined;
  }
}

/** Route réservée aux utilisateurs connectés. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request & { user?: AuthUser }>();
    const user = await readUser(this.jwt, req);
    if (!user) throw unauthorized('UNAUTHORIZED', 'Connexion requise.');
    req.user = user;
    return true;
  }
}

/** Route publique : l'utilisateur est identifié s'il envoie un jeton valide. */
@Injectable()
export class OptionalAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request & { user?: AuthUser }>();
    req.user = await readUser(this.jwt, req);
    return true;
  }
}

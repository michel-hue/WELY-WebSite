import { createParamDecorator, ExecutionContext } from '@nestjs/common';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Identifiant d'installation de l'app (en-tête X-Installation-Id). Ignoré s'il n'est pas un UUID. */
export const InstallationId = createParamDecorator((_: unknown, ctx: ExecutionContext): string | undefined => {
  const value = ctx.switchToHttp().getRequest().headers['x-installation-id'];
  return typeof value === 'string' && UUID.test(value) ? value.toLowerCase() : undefined;
});

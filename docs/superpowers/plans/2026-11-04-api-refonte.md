# WELLY API (refonte) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconstruire `api_project/` en API de mise en relation : consultation anonyme et recherche géolocalisée, connexion sans mot de passe par code SMS/WhatsApp, annonces multi-offres avec expiration, demandes sans paiement, notifications, favoris, signalements.

**Architecture:** NestJS 12 (ESM) modulaire, un module par domaine (`auth`, `users`, `listings`, `photos`, `search`, `requests`, `notifications`, `favorites`, `reports`, `jobs`). PostgreSQL (Neon en prod, PostGIS en Docker en dev/test) via TypeORM **avec migrations**. Les dépendances externes (envoi de codes, push, stockage d'images) sont derrière des interfaces avec une implémentation locale par défaut. Les modules communiquent par événements de domaine (`@nestjs/event-emitter`) quand un module ne doit pas dépendre d'un autre (ex. annonce retirée → demandes refusées).

**Tech Stack:** NestJS 12, TypeORM 1.1, PostgreSQL 16 + PostGIS + `btree_gist` + `unaccent`, Vitest 4 + supertest, `libphonenumber-js`, `@nestjs/jwt`, `@nestjs/swagger`, `@nestjs/throttler`, `@nestjs/schedule`, `@nestjs/event-emitter`, `helmet`, `sharp`, `@aws-sdk/client-s3`, `firebase-admin` (optionnel au runtime).

**Spec:** `docs/superpowers/specs/2026-11-04-api-design.md`

## Global Constraints

- Toutes les routes sous le préfixe `/v1` ; `GET /health` et `/docs` (Swagger, uniquement hors production) hors préfixe.
- Ressources en anglais, pluriel, kebab-case ; JSON en camelCase ; valeurs d'énumération en anglais minuscule.
- Format d'erreur unique : `{ "error": { "code": "UPPER_SNAKE", "message": "<français>", "details"?: [...] } }`. Statuts : 400 validation, 401, 403, 404, 409 conflit, 422 règle métier, 429 trop de requêtes.
- Listes paginées : `{ "data": [...], "nextCursor": string | null }`, `limit` par défaut 20, max 50.
- Dates : ISO 8601 UTC ; dates de séjour `YYYY-MM-DD`.
- Montants en FCFA, entiers (`integer`).
- Téléphones stockés en E.164, région par défaut `CI`.
- Messages destinés à l'utilisateur en français.
- Pas de mot de passe nulle part. Pas de `synchronize` : schéma uniquement par migrations.
- En-tête `X-Installation-Id` (UUID généré par l'app) accepté sur toutes les routes ; obligatoire seulement pour signaler sans compte.
- Aucun secret par défaut en production : l'app refuse de démarrer si `JWT_SECRET` manque quand `NODE_ENV=production`.
- Ne jamais renvoyer le téléphone d'un acheteur ailleurs que dans les demandes reçues par le vendeur concerné.

## Review Focus

1. **Deux acceptations simultanées de séjours qui se chevauchent** → une seule réussit, l'autre reçoit 409 `STAY_DATES_UNAVAILABLE` (Task 8, test « concurrent accept »).
2. **Formats de numéro ivoirien variés** (`07 07 07 07 07`, `0707070707`, `+225 0707070707`) → même compte ; numéro invalide → 400 `INVALID_PHONE` (Task 2).
3. **Filtre de prix sans type d'offre** → 400 `VALIDATION_ERROR` avec détail sur `offerType` ; une annonce sans offre « nuit » n'apparaît jamais dans une recherche `offerType=nightly` (Task 6).
4. **Annonce signalée** → absente de la liste **et** 404 sur la fiche pour cet utilisateur/cette installation, visible pour les autres (Task 7).
5. **Tâche d'expiration lancée deux fois en parallèle** → chaque vendeur reçoit exactement une notification d'expiration et un seul rappel J-3 (Task 9).

---

## File Structure

```
api_project/
  docker-compose.yml                  # postgis dev (5433) + test (5434)
  .env.example                        # toutes les variables documentées
  src/
    main.ts                           # bootstrap via createApp()
    app.factory.ts                    # createApp(): préfixe, pipes, filtre, helmet, cors, swagger
    app.module.ts
    config/env.validation.ts          # schéma des variables d'env
    database/
      data-source.ts                  # DataSource TypeORM pour CLI migrations
      database.module.ts
      migrations/                     # une migration par task qui touche le schéma
    common/
      errors/app-error.ts             # AppError + helpers
      errors/all-exceptions.filter.ts
      pagination/cursor.ts            # encode/decode curseurs
      pagination/paginated.dto.ts
      http/installation-id.decorator.ts
      http/current-user.decorator.ts
      auth/jwt-auth.guard.ts          # requis
      auth/optional-auth.guard.ts     # facultatif
      events/domain-events.ts         # noms + payloads d'événements
    health/health.controller.ts
    users/        user.entity.ts, users.service.ts, me.controller.ts, dto/
    auth/         otp-challenge.entity.ts, refresh-token.entity.ts, auth.service.ts, auth.controller.ts,
                  phone.ts, otp/otp-sender.ts, otp/console-otp-sender.ts, otp/twilio-otp-sender.ts
    notifications/ notification.entity.ts, device.entity.ts, notifications.service.ts,
                   notifications.controller.ts, push/push-sender.ts, push/log-push-sender.ts, push/fcm-push-sender.ts
    listings/     listing.entity.ts, listing-status.ts, listings.service.ts, seller-listings.controller.ts, dto/
    photos/       listing-photo.entity.ts, photos.service.ts, photos.controller.ts,
                  storage/storage.ts, storage/local-storage.ts, storage/s3-storage.ts, image-processor.ts
    search/       search.service.ts, public-listings.controller.ts, dto/
    favorites/    favorite.entity.ts, favorites.service.ts, favorites.controller.ts
    reports/      report.entity.ts, reports.service.ts, reports.controller.ts
    requests/     listing-request.entity.ts, blocked-stay.entity.ts, requests.service.ts,
                  requests.controller.ts, listing-events.listener.ts, dto/
    jobs/         expiry.job.ts
    seed/seed.ts                      # données de démo (npm run seed)
  test/
    utils/test-app.ts                 # boot + reset DB + helpers (login, createSeller…)
    *.e2e-spec.ts                     # un fichier par domaine
```

Les anciens dossiers `src/auth`, `src/users`, `src/listings`, `src/reservations`, `src/app.controller*`, `src/app.service.ts`, `src/multer.d.ts` sont supprimés en Task 1 et réécrits dans les tasks suivantes.

**Stratégie de tests.** Unitaires (`*.spec.ts`, `npm test`) pour la logique pure. E2E (`*.e2e-spec.ts`, `npm run test:e2e`) contre la base PostGIS de test Docker (`TEST_DATABASE_URL`), migrations jouées au démarrage, toutes les tables vidées (`TRUNCATE … CASCADE`) avant chaque fichier de test, `fileParallelism: false`. Le `OtpSender` est remplacé en e2e par `InMemoryOtpSender` (expose `lastCodeFor(phone)`), le `PushSender` par un `InMemoryPushSender`.

---

### Task 1: Socle — configuration, erreurs, santé, Swagger, base de test

**Files:**
- Delete: `src/auth/**`, `src/users/**`, `src/listings/**`, `src/reservations/**`, `src/app.controller.ts`, `src/app.controller.spec.ts`, `src/app.service.ts`, `src/multer.d.ts`, `test/app.e2e-spec.ts`
- Create: `docker-compose.yml`, `src/app.factory.ts`, `src/config/env.validation.ts`, `src/database/data-source.ts`, `src/database/migrations/1730700000000-Extensions.ts`, `src/common/errors/*`, `src/common/pagination/*`, `src/common/http/installation-id.decorator.ts`, `src/health/health.controller.ts`, `test/utils/test-app.ts`, `test/health.e2e-spec.ts`, `src/common/pagination/cursor.spec.ts`
- Modify: `src/main.ts`, `src/app.module.ts`, `src/database/database.module.ts`, `package.json`, `.env.example`, `vitest.config.e2e.ts`

**Interfaces:**
- Produces:
  - `createApp(module?: Type): Promise<INestApplication>` — applique tout le paramétrage HTTP (utilisé par `main.ts` et les e2e).
  - `class AppError extends HttpException { constructor(status: number, code: string, message: string, details?: unknown[]) }` + fabriques `notFound(code, message)`, `forbidden(code, message)`, `conflict(code, message)`, `unprocessable(code, message)`.
  - `encodeCursor(values: Record<string, string | number>): string`, `decodeCursor(cursor: string): Record<string, string | number>` (base64url JSON ; curseur invalide → `AppError(400, 'INVALID_CURSOR', …)`).
  - `@InstallationId(): string | undefined` (valide un UUID, sinon ignoré).
  - `bootTestApp(overrides?: (b: TestingModuleBuilder) => TestingModuleBuilder): Promise<{ app: INestApplication; http: () => supertest.Agent; reset: () => Promise<void> }>`.

- [ ] **Step 1:** Ajouter les dépendances : `npm i @nestjs/swagger @nestjs/throttler @nestjs/schedule @nestjs/event-emitter helmet libphonenumber-js sharp @aws-sdk/client-s3` et `npm i -D @types/multer`. Retirer `bcrypt`, `@types/bcrypt`, `passport`, `passport-jwt`, `@nestjs/passport`, `@types/passport-jwt`. Scripts : `"migration:generate": "typeorm-ts-node-esm migration:generate -d src/database/data-source.ts"` (ou équivalent compatible ESM choisi par l'implémenteur), `"migration:run"`, `"seed": "node dist/seed/seed.js"`, `"db:up": "docker compose up -d"`.
- [ ] **Step 2:** `docker-compose.yml` : deux services `postgis/postgis:16-3.4` — `db` (port 5433, base `welly`) et `db-test` (port 5434, base `welly_test`, `tmpfs` pour la vitesse).
- [ ] **Step 3:** Migration `Extensions` : `CREATE EXTENSION IF NOT EXISTS postgis; … btree_gist; … unaccent; … pgcrypto;` + fonction immuable `f_unaccent(text)` (wrapper de `unaccent('unaccent', $1)`) pour l'indexation.
- [ ] **Step 4:** `env.validation.ts` — variables : `NODE_ENV`, `PORT` (3000), `DATABASE_URL`, `DATABASE_SSL` (`true` par défaut, `false` pour Docker), `JWT_SECRET`, `JWT_ACCESS_TTL` (`15m`), `REFRESH_TTL_DAYS` (180), `CORS_ORIGIN`, `OTP_PROVIDER` (`console`|`twilio`), `TWILIO_*`, `PUSH_PROVIDER` (`log`|`fcm`), `FCM_SERVICE_ACCOUNT_JSON`, `STORAGE_DRIVER` (`local`|`s3`), `S3_*`, `PUBLIC_MEDIA_BASE_URL`. Production sans `JWT_SECRET` → erreur au démarrage.
- [ ] **Step 5: Tests (échouent).** `cursor.spec.ts` : aller-retour encode/decode ; `decodeCursor('pas-du-base64')` lève `AppError` code `INVALID_CURSOR`. `health.e2e-spec.ts` : `GET /health` → 200 `{ status: 'ok', db: 'up' }` ; `GET /v1/nope` → 404 `{ error: { code: 'NOT_FOUND', message: 'Ressource introuvable.' } }` ; un body JSON invalide → 400 `{ error: { code: 'BAD_REQUEST' } }`.
- [ ] **Step 6: Implémenter.** `AllExceptionsFilter` : `AppError` → tel quel ; `BadRequestException` issue du `ValidationPipe` → `VALIDATION_ERROR`, message `Certaines informations sont invalides.`, `details: [{ field, message }]` (via `exceptionFactory`) ; `ThrottlerException` → 429 `TOO_MANY_REQUESTS` ; autres `HttpException` → code dérivé du statut (`NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `BAD_REQUEST`) ; inconnu → 500 `INTERNAL_ERROR` (loggé, message générique). `createApp` : `setGlobalPrefix('v1', { exclude: ['health'] })`, `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`, `helmet()`, CORS selon `CORS_ORIGIN`, Swagger sur `/docs` si `NODE_ENV !== 'production'`, `ThrottlerModule` global 100 req/min. `DatabaseModule` : `synchronize: false`, `migrationsRun: true`, ssl selon `DATABASE_SSL`.
- [ ] **Step 7: Vérifier.** `npm run db:up && npm run build && npm test && TEST_DATABASE_URL=postgres://postgres:postgres@localhost:5434/welly_test npm run test:e2e` → tout PASS ; `npm run lint` sans erreur.
- [ ] **Step 8: Commit** `feat(api): socle v1 — erreurs, santé, swagger, migrations`

### Task 2: Connexion sans mot de passe (OTP + sessions)

**Files:**
- Create: `src/users/user.entity.ts`, `src/users/users.service.ts`, `src/users/users.module.ts`, `src/auth/*` (voir structure), `src/common/auth/jwt-auth.guard.ts`, `src/common/auth/optional-auth.guard.ts`, `src/common/http/current-user.decorator.ts`, migration `…-Auth.ts`, `src/auth/phone.spec.ts`, `src/auth/auth.service.spec.ts`, `test/auth.e2e-spec.ts`, `test/utils/in-memory-otp-sender.ts`

**Interfaces:**
- Produces:
  - Entité `User { id: uuid; phone: string|null (unique partiel si non null); name: string; avatarUrl: string|null; whatsappPhone: string|null; isSeller: boolean; createdAt; deletedAt: Date|null }`.
  - `normalizePhone(input: string): string` (E.164, région `CI`) — lève `AppError(400, 'INVALID_PHONE', 'Numéro de téléphone invalide.')`.
  - `interface OtpSender { send(phone: string, code: string, channel: 'sms' | 'whatsapp'): Promise<void> }`, token d'injection `OTP_SENDER`.
  - `AuthUser = { id: string }` placé sur `req.user` ; `@CurrentUser(): AuthUser` ; `JwtAuthGuard` (401 `UNAUTHORIZED`, message `Connexion requise.`) ; `OptionalAuthGuard` (ne lève jamais, `req.user` absent si pas de jeton valide).
  - `AuthSession = { accessToken: string; refreshToken: string; user: MeDto }` ; `MeDto = { id, name, phone, whatsappPhone, avatarUrl, isSeller, createdAt }`.
  - e2e : `loginAs(http, phone: string, name = 'Test'): Promise<AuthSession>` dans `test/utils/test-app.ts`.

Routes :
- `POST /v1/auth/otp/request` `{ phone, channel?: 'sms'|'whatsapp' (déf. sms) }` → 202 `{ expiresInSeconds: 300, isNewUser: boolean }`.
- `POST /v1/auth/otp/verify` `{ phone, code, name? }` → 200 `AuthSession`. `name` obligatoire (2–60 car.) si nouveau compte, sinon ignoré.
- `POST /v1/auth/refresh` `{ refreshToken }` → 200 `AuthSession` (rotation : l'ancien est révoqué).
- `POST /v1/auth/logout` `{ refreshToken }` → 204.

Règles (valeurs figées) : code 6 chiffres, haché (SHA-256 + `JWT_SECRET` en sel) ; validité 5 min ; 5 essais max puis challenge invalidé (`OTP_TOO_MANY_ATTEMPTS`, 429) ; renvoi possible après 60 s (`OTP_RESEND_TOO_SOON`, 429) ; max 5 envois par numéro par heure ; throttle IP 5/min sur `otp/request`. Jeton d'accès JWT `{ sub }` 15 min ; refresh token opaque 32 octets aléatoires, stocké haché, 180 jours, révoqué au logout, à la rotation ou si réutilisé après rotation (réutilisation → toute la famille révoquée). Utilisateur supprimé (`deletedAt`) → traité comme inexistant.

- [ ] **Step 1: Tests unitaires (échouent).** `phone.spec.ts` : `normalizePhone('07 07 07 07 07')`, `('0707070707')`, `('+225 07 07 07 07 07')` → `'+2250707070707'` ; `normalizePhone('123')` lève `INVALID_PHONE`. `auth.service.spec.ts` (repos mockés) : code expiré → `OTP_INVALID` ; 6ᵉ essai → `OTP_TOO_MANY_ATTEMPTS`.
- [ ] **Step 2: Tests e2e (échouent).** `auth.e2e-spec.ts` : nouveau numéro → `isNewUser: true` ; verify sans `name` pour nouveau compte → 400 `VALIDATION_ERROR` détail `name` ; verify OK → session, `user.isSeller === false` ; deux formats du même numéro → même `user.id` ; mauvais code → 401 `OTP_INVALID` message `Code incorrect ou expiré.` ; refresh → nouveaux jetons, l'ancien refresh → 401 `REFRESH_INVALID` ; logout puis refresh → 401 ; `otp/request` deux fois en < 60 s → 429 `OTP_RESEND_TOO_SOON`.
- [ ] **Step 3: Implémenter** entités, migration, services, contrôleur, gardes ; `ConsoleOtpSender` (log `[OTP] +225… → 123456`) par défaut, `TwilioOtpSender` (API Messages, `whatsapp:` préfixé pour le canal WhatsApp) quand `OTP_PROVIDER=twilio`.
- [ ] **Step 4: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 5: Commit** `feat(api): connexion sans mot de passe par code`

### Task 3: Profil, mode vendeur, appareils et notifications

**Files:**
- Create: `src/users/me.controller.ts`, `src/users/dto/update-me.dto.ts`, `src/notifications/*`, migration `…-Notifications.ts`, `test/me.e2e-spec.ts`, `test/notifications.e2e-spec.ts`, `test/utils/in-memory-push-sender.ts`

**Interfaces:**
- Consumes: `JwtAuthGuard`, `@CurrentUser`, `User`.
- Produces:
  - `NotificationType = 'request_received' | 'request_cancelled' | 'request_accepted' | 'request_refused' | 'listing_expired' | 'listing_expiring_soon'`.
  - `NotificationsService.notify(userId: string, type: NotificationType, data: { listingId?: string; requestId?: string; reason?: string; title: string; body: string }): Promise<void>` — enregistre en base puis pousse sur tous les appareils (erreurs push loggées, jamais propagées ; jeton FCM invalide → appareil supprimé).
  - `interface PushSender { send(tokens: string[], message: { title: string; body: string; data: Record<string, string> }): Promise<{ invalidTokens: string[] }> }`, token `PUSH_SENDER`.

Routes :
- `GET /v1/me` → `MeDto` ; `PATCH /v1/me` `{ name?, whatsappPhone? (normalisé), avatarUrl? }` → `MeDto`.
- `PUT /v1/me/seller-mode` `{ enabled: boolean }` → `MeDto` (désactiver ne touche pas aux annonces).
- `PUT /v1/me/devices/:token` `{ platform: 'ios'|'android' }` → 204 (upsert, rattache le jeton FCM à l'utilisateur courant) ; `DELETE /v1/me/devices/:token` → 204.
- `GET /v1/me/notifications?cursor&limit` → paginé `{ id, type, title, body, listingId, requestId, readAt, createdAt }`, plus récentes d'abord ; `GET /v1/me/notifications/unread-count` → `{ count }` ; `POST /v1/me/notifications/:id/read` → 204 ; `POST /v1/me/notifications/read-all` → 204.

- [ ] **Step 1: Tests e2e (échouent).** `me.e2e-spec.ts` : `GET /v1/me` sans jeton → 401 ; `PATCH` nom → reflété ; `whatsappPhone: '05 05 05 05 05'` → `'+2250505050505'` ; `PUT seller-mode {enabled:true}` → `isSeller: true`. `notifications.e2e-spec.ts` (appel direct de `NotificationsService.notify` via `app.get`) : notification listée, `unread-count` 1 puis 0 après `read` ; l'utilisateur B ne voit pas les notifications de A ; `InMemoryPushSender` a reçu le message pour le jeton enregistré.
- [ ] **Step 2: Implémenter** ; `FcmPushSender` (firebase-admin, chargé dynamiquement seulement si `PUSH_PROVIDER=fcm`).
- [ ] **Step 3: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 4: Commit** `feat(api): profil, mode vendeur, notifications`

### Task 4: Annonces côté vendeur (création, offres, cycle de vie)

**Files:**
- Create: `src/listings/*`, migration `…-Listings.ts`, `src/listings/listing-status.spec.ts`, `test/seller-listings.e2e-spec.ts`, `src/common/events/domain-events.ts`

**Interfaces:**
- Consumes: `User`, gardes, `AppError`.
- Produces:
  - Entité `Listing { id; ownerId; title; description; propertyType: 'house'|'villa'|'apartment'|'studio'|'room'|'land'|'other'; rooms: int; bedrooms: int|null; bathrooms: int|null; surfaceM2: int|null; amenities: Amenity[]; city: string; district: string; address: string|null; location: geography(Point,4326)|null; monthlyRent: int|null; monthlyTerms: string|null; nightlyPrice: int|null; minNights: int|null; salePrice: int|null; status: ListingStatus; closedReason: 'rented'|'sold'|null; publishedUntil: Date|null (null = permanente quand en ligne); viewCount; contactClickCount; requestCount; expiryReminderSentAt: Date|null; publishedAt; createdAt; updatedAt; deletedAt }`.
  - `Amenity = 'furnished'|'air_conditioning'|'parking'|'pool'|'generator'|'security'|'wifi'|'water_tank'|'garden'|'balcony'`.
  - `ListingStatus = 'draft'|'online'|'expired'|'deactivated'|'closed'`.
  - `assertTransition(from: ListingStatus, action: 'publish'|'deactivate'|'close'|'reactivate'): ListingStatus` (lève `AppError(422, 'INVALID_LISTING_TRANSITION', …)`). Transitions : draft→online (publish) ; online→deactivated ; online→closed ; expired|deactivated|closed→online (reactivate). Le passage online→expired est réservé au job (Task 9).
  - Événements : `LISTING_UNAVAILABLE = 'listing.unavailable'` payload `{ listingId: string; offerTypes?: OfferType[] }` (émis via `eventEmitter.emitAsync`, donc attendu) quand une annonce quitte `online` ou qu'une offre est retirée ; `OfferType = 'monthly'|'nightly'|'sale'`.
  - `ListingsService.findOwned(id, userId): Promise<Listing>` (404 `LISTING_NOT_FOUND` si absent/supprimé, 403 `NOT_LISTING_OWNER`).
  - `SellerListingDto` (tous champs + `offers: { monthly?: { rent, terms }, nightly?: { price, minNights }, sale?: { price } }`, `location: { lat, lng } | null`, `photos: PhotoDto[]` — `photos` vide jusqu'à Task 5, `stats: { views, contactClicks, requests }` — compteurs visibles du seul vendeur).

Routes (toutes `JwtAuthGuard`, `isSeller` requis sinon 403 `SELLER_MODE_REQUIRED` message `Activez le mode vendeur pour publier.`) :
- `POST /v1/listings` (crée en `draft`) ; `PATCH /v1/listings/:id` (champs partiels ; une offre mise à `null` = retirée) ; `GET /v1/me/listings?status&cursor&limit` ; `GET /v1/me/listings/:id`.
- `POST /v1/listings/:id/publish` `{ until?: 'YYYY-MM-DD' }` (absent = permanente) ; `POST /:id/deactivate` ; `POST /:id/close` `{ reason: 'rented'|'sold' }` ; `POST /:id/reactivate` `{ until?: 'YYYY-MM-DD' }` ; `DELETE /v1/listings/:id` (suppression logique, 204).

Règles de publication (publish et reactivate) : au moins une offre, `location` renseignée, au moins 1 photo (vérifiée à partir de Task 5 ; jusque-là la règle est codée mais le test qui l'exerce est dans Task 5), `until` ≥ aujourd'hui, la date de fin étant incluse : l'annonce reste en ligne toute cette journée (sinon 422 `INVALID_PUBLICATION_DATE`). Échecs → 422 `LISTING_INCOMPLETE` avec `details` listant `offers`/`location`/`photos`. `reactivate` remet `expiryReminderSentAt = null`. Prix : entiers > 0 ; `minNights` ≥ 1.

- [ ] **Step 1: Test unitaire (échoue).** `listing-status.spec.ts` : chaque transition autorisée du tableau ; `assertTransition('draft','close')` lève `INVALID_LISTING_TRANSITION`.
- [ ] **Step 2: Tests e2e (échouent).** Utilisateur non vendeur → 403 `SELLER_MODE_REQUIRED` ; création brouillon avec `offers.monthly.rent = 350000` ; `publish` sans localisation → 422 `LISTING_INCOMPLETE` détail `location` ; un autre utilisateur `PATCH` → 403 `NOT_LISTING_OWNER` ; `close {reason:'rented'}` → `status: 'closed'`, `closedReason: 'rented'` ; `reactivate {until: hier}` → 422 `INVALID_PUBLICATION_DATE` ; un écouteur de test sur `listing.unavailable` reçoit `{ listingId }` après `deactivate` et `{ listingId, offerTypes:['nightly'] }` après `PATCH offers.nightly = null`.
- [ ] **Step 3: Implémenter** (index GIST sur `location`, index sur `status`, `ownerId`).
- [ ] **Step 4: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 5: Commit** `feat(api): annonces vendeur et cycle de vie`

### Task 5: Photos (upload, tailles, ordre, stockage)

**Files:**
- Create: `src/photos/*`, migration `…-Photos.ts`, `test/photos.e2e-spec.ts`, `test/fixtures/house.jpg` (petite image ≤ 50 Ko)
- Modify: `src/listings/listings.service.ts` (règle « ≥ 1 photo », `photos` dans les DTO), `src/main.ts`/`app.factory.ts` (servir `/media` en driver local)

**Interfaces:**
- Consumes: `ListingsService.findOwned`.
- Produces:
  - Entité `ListingPhoto { id; listingId; position: int; thumbKey; largeKey; width; height; createdAt }`.
  - `PhotoDto = { id, thumbUrl, largeUrl, width, height, position }` (première position = couverture).
  - `interface Storage { put(key: string, body: Buffer, contentType: string): Promise<void>; delete(key: string): Promise<void>; publicUrl(key: string): string }`, token `STORAGE`. `LocalStorage` écrit dans `./media` et sert `/media/*` ; `S3Storage` (endpoint configurable → R2/S3).
  - `processImage(buf: Buffer): Promise<{ thumb: Buffer; large: Buffer; width; height }>` — webp, vignette 480 px de large, grande 1600 px max, rotation EXIF appliquée, métadonnées supprimées.

Routes (propriétaire) : `POST /v1/listings/:id/photos` multipart champ `photos` (1–10 fichiers par envoi, jpeg/png/webp, 8 Mo max chacun, 15 photos max par annonce → 422 `TOO_MANY_PHOTOS`, mauvais type → 400 `UNSUPPORTED_IMAGE`) → 201 `PhotoDto[]` ; `PUT /v1/listings/:id/photos/order` `{ photoIds: string[] }` (doit contenir exactement toutes les photos, sinon 400 `INVALID_PHOTO_ORDER`) ; `DELETE /v1/listings/:id/photos/:photoId` → 204 (supprime aussi du stockage). Supprimer la dernière photo d'une annonce `online` → 422 `LAST_PHOTO_OF_ONLINE_LISTING`.

- [ ] **Step 1: Tests e2e (échouent).** Upload de `house.jpg` → 201, `thumbUrl` répond 200 en `image/webp` ; envoi d'un `.txt` → 400 `UNSUPPORTED_IMAGE` ; 16ᵉ photo → 422 `TOO_MANY_PHOTOS` ; réordonnancement → la 2ᵉ devient position 0 ; `publish` sans photo → 422 `LISTING_INCOMPLETE` détail `photos` ; suppression de l'unique photo d'une annonce en ligne → 422.
- [ ] **Step 2: Implémenter.**
- [ ] **Step 3: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 4: Commit** `feat(api): photos d'annonces`

### Task 6: Consultation publique et recherche

**Files:**
- Create: `src/search/*`, `src/search/search-query.dto.ts`, `src/search/search.service.spec.ts`, `test/search.e2e-spec.ts`
- Modify: migration `…-SearchIndex.ts` (index `f_unaccent(lower(title || ' ' || district || ' ' || city || ' ' || description))` en trigram ou `to_tsvector('simple', f_unaccent(...))`, au choix)

**Interfaces:**
- Consumes: `Listing`, `ListingPhoto`, `OptionalAuthGuard`, `@InstallationId`, curseurs.
- Produces:
  - `SearchService.hiddenListingIdsFor(userId?: string, installationId?: string)` — **sous-requête** réutilisée (alimentée par Task 7 ; renvoie vide tant que `reports` n'existe pas — Task 7 la complète).
  - `ListingCardDto = { id, title, propertyType, city, district, coverThumbUrl, offers, rooms, distanceMeters: number|null, publishedAt }` (pas de coordonnées exactes).
  - `PublicListingDto = ListingCardDto + { description, bedrooms, bathrooms, surfaceM2, amenities, address, location: { lat, lng }, photos: PhotoDto[], seller: { id, name, avatarUrl, memberSince, onlineListingsCount, phone, whatsappPhone } }` — `whatsappPhone` retombe sur `phone` si null.

Routes (publiques, `OptionalAuthGuard`) :
- `GET /v1/listings` — query : `lat`, `lng` (ensemble ou aucun), `radiusKm` (déf. 10, max 100), `q`, `offerType`, `propertyType` (multi), `city`, `district`, `priceMin`, `priceMax` (exigent `offerType`), `roomsMin`, `bedroomsMin`, `amenities` (multi, toutes requises), `checkIn`/`checkOut` (exigent `offerType=nightly` ; exclut les annonces avec nuits bloquées qui chevauchent — la table arrive en Task 8 : la condition est ajoutée en Task 8), `sort` = `distance` (déf. si lat/lng) | `recent` (déf. sinon) | `price_asc` | `price_desc` (prix ⇒ `offerType` requis), `cursor`, `limit`. → paginé `ListingCardDto`.
- `GET /v1/listings/:id` → `PublicListingDto` ; 404 `LISTING_NOT_FOUND` si pas `online`, supprimée ou masquée pour l'appelant ; incrémente `viewCount` (une seule fois par installation et par jour n'est **pas** requis : incrément simple).
- `POST /v1/listings/:id/contact-clicks` `{ channel: 'whatsapp'|'call' }` → 204, incrémente `contactClickCount`.
- `GET /v1/locations` → `{ cities: [{ city, districts: string[] }] }` à partir des annonces `online`.

Pagination : curseur = valeurs de la clé de tri + `id` (keyset), stable avec égalités.

- [ ] **Step 1: Test unitaire (échoue).** `search.service.spec.ts` (validation DTO) : `priceMin` sans `offerType` → erreur sur `offerType` ; `lat` sans `lng` → erreur ; `sort=price_asc` sans `offerType` → erreur.
- [ ] **Step 2: Tests e2e (échouent).** Jeu : 3 annonces en ligne (Cocody 5.3599,-3.9873 offre mois 650000 ; Riviera 5.3667,-3.9500 offres mois 350000 + nuit 30000 ; Assinie 5.1333,-3.4667 offre nuit 90000) + 1 brouillon. Recherche autour de Cocody rayon 10 km → Cocody puis Riviera (Assinie exclue), `distanceMeters` croissant ; `offerType=nightly` → Riviera et Assinie seulement ; `offerType=monthly&priceMax=400000` → Riviera seule ; `q=cocody` et `q=COCODY` et `q=côcody` → même résultat ; brouillon jamais visible (liste et fiche 404) ; pagination `limit=1` parcourt les 3 sans doublon ; fiche contient `seller.phone` et `location`, la carte de liste ne contient pas `location` ; `contact-clicks` incrémente le compteur vu dans `GET /v1/me/listings/:id`.
- [ ] **Step 3: Implémenter** (requêtes via `QueryBuilder` + `ST_DWithin`/`ST_Distance` sur `geography`).
- [ ] **Step 4: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 5: Commit** `feat(api): recherche et fiche publique`

### Task 7: Favoris et signalements

**Files:**
- Create: `src/favorites/*`, `src/reports/*`, migration `…-FavoritesReports.ts`, `test/favorites.e2e-spec.ts`, `test/reports.e2e-spec.ts`
- Modify: `src/search/search.service.ts` (`hiddenListingIdsFor` lit `reports`)

**Interfaces:**
- Consumes: `SearchService`, `ListingCardDto`, `@InstallationId`, `OptionalAuthGuard`.
- Produces: entités `Favorite { userId; listingId; createdAt }` (PK composite) et `Report { id; listingId; userId|null; installationId|null; reason: 'scam'|'misleading_price'|'misleading_photos'|'unavailable'|'other'; comment|null; createdAt }`.

Routes :
- Favoris (`JwtAuthGuard`) : `GET /v1/me/favorites?cursor&limit` → paginé `ListingCardDto` (n'inclut que les annonces encore `online` et non masquées) ; `PUT /v1/me/favorites/:listingId` → 204 (idempotent) ; `DELETE /v1/me/favorites/:listingId` → 204 ; `POST /v1/me/favorites/merge` `{ listingIds: string[] (max 200) }` → 204 (ignore les ids inconnus).
- Signalement (`OptionalAuthGuard`) : `POST /v1/listings/:id/reports` `{ reason, comment? (max 500) }` → 201. Sans jeton **et** sans `X-Installation-Id` valide → 400 `INSTALLATION_ID_REQUIRED`. Signaler sa propre annonce → 422 `CANNOT_REPORT_OWN_LISTING`. Re-signaler = idempotent (pas de doublon pour le même couple annonce/(utilisateur|installation)).
- Masquage : une annonce est masquée si un signalement existe avec `userId` = appelant **ou** `installationId` = en-tête de l'appelant.

- [ ] **Step 1: Tests e2e (échouent).** Favoris : ajouter deux fois → une seule entrée ; `merge` avec un id inexistant → 204 et seuls les valides ajoutés ; une annonce passée `closed` disparaît de la liste des favoris. Signalements (Review Focus 4) : installation A signale → `GET /v1/listings` avec en-tête A n'a plus l'annonce et `GET /v1/listings/:id` → 404, avec en-tête B l'annonce est visible ; utilisateur connecté qui signale depuis le téléphone A → masquée aussi quand il se connecte depuis l'installation C ; signalement sans jeton ni en-tête → 400 `INSTALLATION_ID_REQUIRED`.
- [ ] **Step 2: Implémenter.**
- [ ] **Step 3: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 4: Commit** `feat(api): favoris et signalements`

### Task 8: Demandes (mois, nuit, achat) et blocage des nuits

**Files:**
- Create: `src/requests/*`, migration `…-Requests.ts`, `src/requests/stay-dates.spec.ts`, `test/requests.e2e-spec.ts`
- Modify: `src/search/search.service.ts` (filtre `checkIn`/`checkOut` contre `blocked_stays`)

**Interfaces:**
- Consumes: `ListingsService`, `NotificationsService.notify`, `LISTING_UNAVAILABLE`, `JwtAuthGuard`.
- Produces:
  - Entité `ListingRequest { id; listingId; buyerId; offerType: OfferType; checkIn: date|null; checkOut: date|null; moveInDate: date|null; wantsVisit: boolean; message: string|null (max 1000); status: 'pending'|'accepted'|'refused'|'cancelled'; refusalReason: 'seller'|'dates_unavailable'|'listing_unavailable'|null; sellerMessage: string|null; createdAt; decidedAt|null }`.
  - Entité `BlockedStay { id; listingId; requestId (unique); nights: daterange }` + contrainte `EXCLUDE USING gist (listing_id WITH =, nights WITH &&)`. `nights = daterange(checkIn, checkOut, '[)')`.
  - `validateStay(checkIn: string, checkOut: string, minNights: number | null, today: string): void` — lève `AppError(400, 'INVALID_STAY_DATES', …)` si `checkOut <= checkIn` ou `checkIn < today` ; `AppError(422, 'MIN_NIGHTS_NOT_MET', 'Ce logement demande au moins N nuits.')`.
  - `RequestsService.refusePendingForListing(listingId: string, reason: 'listing_unavailable', offerTypes?: OfferType[]): Promise<void>` (écouteur de `listing.unavailable`).

Routes (`JwtAuthGuard`) :
- `POST /v1/requests` `{ listingId, offerType, checkIn?, checkOut?, moveInDate?, wantsVisit?, message? }` → 201. Erreurs : annonce pas `online` → 422 `LISTING_NOT_AVAILABLE` ; offre absente de l'annonce → 422 `OFFER_NOT_AVAILABLE` ; sa propre annonce → 422 `CANNOT_REQUEST_OWN_LISTING` ; demande `pending` déjà existante sur l'annonce → 409 `REQUEST_ALREADY_PENDING` ; `nightly` sans dates → 400 ; nuits déjà bloquées → 409 `STAY_DATES_UNAVAILABLE`. Effets : `requestCount++`, notification `request_received` au vendeur.
- `GET /v1/me/requests?status&cursor&limit` (acheteur) → `{ id, status, refusalReason, sellerMessage, offerType, checkIn, checkOut, moveInDate, wantsVisit, message, createdAt, listing: ListingCardDto }`.
- `GET /v1/me/received-requests?status&listingId&cursor&limit` (vendeur) → même forme + `buyer: { id, name, phone }`.
- `POST /v1/requests/:id/accept` `{ message? }` (vendeur ; seulement `pending`, sinon 422 `REQUEST_NOT_PENDING`) — pour `nightly`, dans **une transaction** : insérer `BlockedStay` (violation de contrainte → 409 `STAY_DATES_UNAVAILABLE`), passer en `accepted`, puis refuser les autres `pending` `nightly` qui chevauchent (`dates_unavailable`) et notifier leurs acheteurs. Notification `request_accepted`.
- `POST /v1/requests/:id/refuse` `{ message? }` (vendeur) → `refused`/`seller`, notification `request_refused`.
- `POST /v1/requests/:id/cancel` (acheteur ; `pending` ou `accepted`) → `cancelled` ; supprime le `BlockedStay` éventuel ; notification `request_cancelled` au vendeur.
- Un tiers sur n'importe laquelle de ces routes → 404 `REQUEST_NOT_FOUND`.

- [ ] **Step 1: Test unitaire (échoue).** `stay-dates.spec.ts` : `validateStay('2026-12-10','2026-12-10',null,'2026-11-04')` → `INVALID_STAY_DATES` ; checkIn passé → `INVALID_STAY_DATES` ; 2 nuits avec `minNights` 3 → `MIN_NIGHTS_NOT_MET`.
- [ ] **Step 2: Tests e2e (échouent).** Parcours mois : demande → vendeur voit `buyer.phone` ; l'acheteur ne voit jamais de `phone` d'autres acheteurs ; vendeur reçoit `request_received`. Nuit : A demande 10→13 déc., B demande 12→14 déc. ; accept A → B passe `refused`/`dates_unavailable` et B reçoit `request_refused` ; nouvelle demande C 11→12 → 409 `STAY_DATES_UNAVAILABLE` ; recherche `offerType=nightly&checkIn=2026-12-11&checkOut=2026-12-12` n'inclut plus l'annonce ; A annule → nuits libérées, C peut demander. **Concurrent accept** (Review Focus 1) : deux demandes qui se chevauchent, `Promise.all` de deux `accept` → exactement un 200 et un 409. Annonce `deactivate` → ses demandes `pending` passent `refused`/`listing_unavailable`, une demande `accepted` reste `accepted`. Retrait de l'offre `nightly` → seules les `pending` `nightly` sont refusées. Doublon `pending` → 409.
- [ ] **Step 3: Implémenter.**
- [ ] **Step 4: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 5: Commit** `feat(api): demandes et blocage des nuits`

### Task 9: Expiration automatique des annonces

**Files:**
- Create: `src/jobs/expiry.job.ts`, `src/jobs/jobs.module.ts`, `test/expiry.e2e-spec.ts`

**Interfaces:**
- Consumes: `NotificationsService.notify`, `LISTING_UNAVAILABLE`, `Listing`.
- Produces: `ExpiryJob.run(now: Date = new Date()): Promise<{ expired: number; reminded: number }>` — appelé au démarrage (sans bloquer le boot) et par `@Cron('0 6 * * *', { timeZone: 'Africa/Abidjan' })`.

Algorithme figé :
1. `SELECT pg_try_advisory_lock(<constante 7346201>)` ; si `false` → retourne `{ expired: 0, reminded: 0 }`. Toujours `pg_advisory_unlock` en `finally` (même connexion : utiliser un `QueryRunner` dédié).
2. Expiration : `UPDATE listings SET status='expired' WHERE status='online' AND published_until IS NOT NULL AND published_until < :today RETURNING id, owner_id, title` ; pour chaque ligne : `emitAsync(LISTING_UNAVAILABLE)` puis notification `listing_expired` (« Votre annonce « <titre> » a expiré. Réactivez-la quand vous voulez. »).
3. Rappel : `UPDATE listings SET expiry_reminder_sent_at=now() WHERE status='online' AND published_until IS NOT NULL AND published_until <= :today + 3 AND published_until >= :today AND expiry_reminder_sent_at IS NULL RETURNING …` ; notification `listing_expiring_soon`.
L'`UPDATE … RETURNING` garantit l'idempotence même sans verrou.

- [ ] **Step 1: Tests e2e (échouent).** Annonce `publishedUntil` = hier → après `run()` : `status: 'expired'`, une notification `listing_expired`, ses demandes `pending` refusées ; deuxième `run()` → aucune nouvelle notification. Annonce à J+2 → une notification `listing_expiring_soon`, une seule après deux `run()`. **Parallèle** (Review Focus 5) : `Promise.all([job.run(), job.run()])` → somme des `expired` = 1 et une seule notification. Annonce permanente → jamais expirée. `reactivate` après expiration remet le rappel à zéro.
- [ ] **Step 2: Implémenter** (désactiver le cron et l'exécution au démarrage quand `NODE_ENV=test`).
- [ ] **Step 3: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 4: Commit** `feat(api): expiration automatique des annonces`

### Task 10: Suppression de compte

**Files:**
- Create: `test/account-deletion.e2e-spec.ts`
- Modify: `src/users/me.controller.ts`, `src/users/users.service.ts`

**Interfaces:**
- Consumes: `ListingsService`, `RequestsService`, `LISTING_UNAVAILABLE`, refresh tokens, devices.
- Produces: `DELETE /v1/me` → 204. `UsersService.deleteAccount(userId: string): Promise<void>`.

Effets, dans une transaction (événements émis après commit) : chaque annonce non supprimée du vendeur → `deletedAt = now()` + `LISTING_UNAVAILABLE` ; demandes `pending`/`accepted` **de l'utilisateur en tant qu'acheteur** → `cancelled` (nuits libérées, vendeurs notifiés) ; favoris supprimés ; refresh tokens révoqués ; appareils supprimés ; utilisateur anonymisé : `name = 'Utilisateur supprimé'`, `phone = null`, `whatsappPhone = null`, `avatarUrl = null`, `isSeller = false`, `deletedAt = now()`. Signalements et notifications conservés.

- [ ] **Step 1: Tests e2e (échouent).** Vendeur avec une annonce en ligne et une demande reçue en attente → après `DELETE /v1/me` : l'annonce est 404 publiquement, la demande est `refused`/`listing_unavailable` ; son ancien refresh → 401 ; le même numéro peut refaire `otp/request` → `isNewUser: true` et obtient un **nouvel** `id`. Acheteur avec un séjour accepté → après suppression, nuits libérées et le vendeur reçoit `request_cancelled`.
- [ ] **Step 2: Implémenter.**
- [ ] **Step 3: Vérifier** `npm test && npm run test:e2e` → PASS.
- [ ] **Step 4: Commit** `feat(api): suppression de compte`

### Task 11: Données de démonstration, documentation, CI

**Files:**
- Create: `src/seed/seed.ts`, `src/seed/demo-photos/*.webp` (5 photos, réutiliser `dev-project/public/images/{villa-contemporaine,appartement-lumineux,chambre,maison-jardin,villa-piscine}.webp`)
- Modify: `api_project/README.md`, `README.md` (section backend : auth gérée par l'API, plus par Neon), `AGENTS.md` (section API : commandes, Docker, migrations, e2e), `.github/workflows/ci.yml` (job backend : service `postgis/postgis:16-3.4`, `npm run lint`, `npm test`, `npm run test:e2e`), `Dockerfile` (exécuter les migrations au démarrage est déjà assuré par `migrationsRun`), `.env.example`

**Interfaces:**
- Consumes: entités et services de toutes les tasks.
- Produces: `npm run seed` (idempotent : ne fait rien si le vendeur de démo existe) — 1 vendeur de démo `+2250700000001` « WELLY Démo », 5 annonces en ligne permanentes reprenant `dev-project/utils/content.ts` (Villa contemporaine – Cocody, Angré – 650 000/mois ; Appartement lumineux – Riviera Palmeraie – 350 000/mois ; Studio meublé – Marcory, Zone 4 – 25 000/nuit ; Maison familiale – Bingerville – 400 000/mois ; Maison de vacances – Assinie – 90 000/nuit) avec coordonnées réalistes et une photo chacune.

- [ ] **Step 1:** Écrire `seed.ts` ; vérifier `npm run build && npm run seed` deux fois sur la base Docker `db` → 5 annonces, pas de doublon ; `curl "localhost:3000/v1/listings?lat=5.36&lng=-3.98"` renvoie les annonces d'Abidjan triées par distance.
- [ ] **Step 2:** Mettre à jour README / AGENTS / `.env.example` (chaque variable de Task 1 Step 4 avec exemple) ; documenter : `npm run db:up`, migrations, seed, e2e, où brancher Twilio/FCM/R2.
- [ ] **Step 3:** CI : job backend avec service PostGIS et `TEST_DATABASE_URL`. Vérifier localement l'enchaînement exact des commandes du workflow.
- [ ] **Step 4: Vérifier** `npm run lint && npm run build && npm test && npm run test:e2e` → PASS ; ouvrir `/docs` et constater que toutes les routes des tasks 1–10 y figurent avec leurs DTO.
- [ ] **Step 5: Commit** `docs(api): seed, documentation et CI`

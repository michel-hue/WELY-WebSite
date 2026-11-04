# WELLY — API

API REST (NestJS) de l'application mobile WELLY : mise en relation entre personnes qui cherchent un logement et personnes qui en proposent, en Côte d'Ivoire. **Aucun paiement** ne passe par l'API.

Conception : [`docs/superpowers/specs/2026-11-04-api-design.md`](../docs/superpowers/specs/2026-11-04-api-design.md)

## En bref

- **Consultation sans compte** : recherche autour de moi, texte, filtres, fiche avec le contact du vendeur.
- **Connexion sans mot de passe** : code à 6 chiffres par SMS ou WhatsApp, session longue (jeton d'accès 15 min + jeton de rafraîchissement 180 jours, renouvelé à chaque usage).
- **Un compte, deux modes** : acheteur par défaut, mode vendeur activable.
- **Annonces** : offres location au mois / à la nuit / vente ; brouillon → en ligne → expirée / désactivée / close ; expiration automatique chaque matin avec rappel 3 jours avant.
- **Demandes** : le vendeur reçoit le nom et le numéro de l'acheteur ; à la nuit, les dates acceptées sont bloquées et les demandes qui chevauchent sont refusées automatiquement.
- **Favoris**, **signalements** (l'annonce est masquée pour celui qui la signale), **notifications** (liste + push FCM).

## Démarrer

```bash
cd api_project
npm install
cp .env.example .env          # renseigner DATABASE_URL (Neon) et JWT_SECRET
npm run start:dev             # http://localhost:3000 — documentation : http://localhost:3000/docs
```

Les migrations s'appliquent automatiquement au démarrage (`migrationsRun`). Les codes de connexion s'affichent dans les logs tant que `OTP_PROVIDER=console`.

Données de démonstration (5 annonces du site vitrine, vendeur `+225 07 00 00 00 01`) :

```bash
npm run build && npm run seed
```

## Commandes

| Commande | Rôle |
|---|---|
| `npm run start:dev` | API en mode watch |
| `npm run build` / `npm run start:prod` | Build puis production (`node dist/main`) |
| `npm test` | Tests unitaires (Vitest) |
| `npm run test:e2e` | Tests de bout en bout contre une vraie base (voir ci-dessous) |
| `npm run typecheck` | Vérification TypeScript (sources + tests) |
| `npm run lint` / `npm run format` | oxlint / Prettier |
| `npm run seed` | Données de démonstration (après `build`) |
| `npm run migration:create -- src/database/migrations/Nom` | Nouvelle migration (SQL écrit à la main) |

## Tests de bout en bout

Ils démarrent l'application complète et utilisent une base PostgreSQL **avec PostGIS** :

- par défaut, la `DATABASE_URL` du `.env` (Neon), dans un **schéma isolé `welly_test`** vidé à chaque fichier de test — le schéma `public` n'est jamais touché ;
- ou `TEST_DATABASE_URL` (+ `TEST_DATABASE_SSL=false`) pour une base locale, par exemple `docker compose up -d db-test` → `postgres://postgres:postgres@localhost:5434/welly_test` (nécessite Docker/WSL).

Contre Neon, la suite complète prend une dizaine de minutes (latence réseau).

## Brancher les services réels

| Besoin | Variables | Par défaut |
|---|---|---|
| Codes SMS / WhatsApp | `OTP_PROVIDER=twilio`, `TWILIO_*` | codes dans les logs |
| Notifications push | `PUSH_PROVIDER=fcm`, `FCM_SERVICE_ACCOUNT_JSON` (+ `npm i firebase-admin`) | push journalisés |
| Photos | `STORAGE_DRIVER=s3`, `S3_*`, `PUBLIC_MEDIA_BASE_URL` (Cloudflare R2, S3…) | disque local servi sur `/media` |

Toutes les variables sont décrites dans [`.env.example`](.env.example).

## Conventions de l'API

- Préfixe `/v1` (sauf `GET /health` et `/docs`).
- Erreurs : `{ "error": { "code": "LISTING_NOT_FOUND", "message": "Annonce introuvable.", "details"?: [...] } }` — messages en français, codes stables pour l'app.
- Listes paginées : `{ "data": [...], "nextCursor": "…" | null }` ; `?limit=` (20 par défaut, 50 max) et `?cursor=`.
- Montants en FCFA (entiers), téléphones en E.164, dates de séjour `AAAA-MM-JJ` (date de fin incluse pour la publication, nuit de départ exclue pour les séjours).
- En-tête facultatif `X-Installation-Id` (UUID généré par l'app) : sert à masquer les annonces signalées sans compte.

## Structure

```
src/
  app.factory.ts        paramétrage HTTP commun (préfixe, validation, erreurs, Swagger, /media)
  auth/                 codes OTP, sessions, envoi Twilio
  users/                profil, mode vendeur, suppression de compte
  listings/             annonces côté vendeur et cycle de vie
  photos/               upload, redimensionnement (sharp), stockage local / S3
  search/               recherche publique, fiche, villes et quartiers
  favorites/ reports/   favoris, signalements
  requests/             demandes, nuits bloquées, refus automatiques
  notifications/        notifications en base + push
  jobs/                 expiration quotidienne des annonces
  database/migrations/  schéma (SQL), une migration par domaine
  seed/                 données de démonstration
test/                   tests e2e (un fichier par domaine) et utilitaires
```

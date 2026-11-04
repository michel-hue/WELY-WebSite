# WELY — Backend (itération 1)

API REST développée avec **NestJS**, utilisée par l'application mobile WELY (acheteurs et vendeurs). Base de données **PostgreSQL** hébergée sur Neon.

> État : itération 1 en cours. Fonctionnalités couvertes : authentification (inscription/connexion) et gestion des annonces (listings). Les réservations ne sont pas encore exposées.

## Prérequis

- Node.js (version récente, compatible avec les dépendances du projet)
- Un compte Neon avec une base PostgreSQL

## Installation

```bash
cd api_project
cp .env.example .env
# Renseigner DATABASE_URL avec la chaîne de connexion Neon
npm install
```

## Variables d'environnement

| Variable | Description | Exemple |
|---|---|---|
| `DATABASE_URL` | Chaîne de connexion PostgreSQL (Neon) | `postgresql://user:password@host.neon.tech/dbname?sslmode=require` |
| `DB_SYNCHRONIZE` | Synchronisation automatique du schéma TypeORM (`true` en dev) | `true` |
| `JWT_SECRET` | Secret de signature des tokens JWT | `change-me-in-prod` |
| `PORT` | Port d'écoute de l'API | `3000` |

## Commandes

```bash
# Développement
npm run start:dev       # mode watch
npm run start:debug     # watch + debug
npm run start           # démarrage simple

# Build / production
npm run build
npm run start:prod      # node dist/main

# Tests
npm run test            # unitaires
npm run test:watch
npm run test:cov        # couverture
npm run test:e2e        # end-to-end

# Lint / format
npm run lint
npm run format
```

## Endpoints principaux

Base URL : `http://localhost:PORT` (par défaut `http://localhost:3000`). Les routes protégées nécessitent un header `Authorization: Bearer <token>`.

### Santé

- `GET /` — message de bienvenue

### Authentification (`/auth`)

- `POST /auth/register` — inscription. Body : `{ email, password, role? }` (`role` : `BUYER` par défaut ou `SELLER`).
- `POST /auth/login` — connexion. Body : `{ email, password }`. Retourne un token JWT.

### Annonces (`/listings`)

- `GET /listings` — liste toutes les annonces
- `GET /listings/:id` — détail d'une annonce
- `POST /listings` — créer une annonce (authentifié). Body : `{ title, description, price, city, type, rooms, photos?, status? }`
- `PUT /listings/:id` — modifier une annonce (authentifié, propriétaire)
- `DELETE /listings/:id` — supprimer une annonce (authentifié, propriétaire)

## Informations manquantes / à préciser

- URL Neon réelle de la base de données (à renseigner dans `.env`, non versionné).
- Stratégie de déploiement de l'API (aucune cible définie pour l'instant ; script `deploy` présent mais non configuré).
- Endpoints réservations à implémenter dans les prochaines itérations.
- Gestion des images (upload/storage) non encore implémentée.
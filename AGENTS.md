    # AGENTS.md

## Repo layout

One repo holds three mostly independent parts:

- **`dev-project/`** — the active Nuxt 4 app (WELY marketing site: index, about, contact, login, register). Has its own `package.json` and lockfile; it is not a workspace. Run all npm commands from inside `dev-project/`.
- **`assets/scss/`** — shared SCSS partials at the **repo root**, outside the Nuxt app (see quirk below). `assets/css/main.css` is a compiled artifact of `main.scss` from a pre-Nuxt version of the site; nothing references it — treat the `.scss` partials as the source of truth and don't hand-edit the CSS.
- **`mobile_project/`** — the WELLY Flutter app (Riverpod, go_router, dio), tracked in git on the `mobile-refonte` branch. `lib/core/` = theme, API/session, router, shared widgets, push; `lib/features/*` = auth, explore, listing(s), favorites, requests, profile, seller, notifications. Light theme only, French UI.

## Key quirk: Nuxt components import SCSS from the repo root

Every component/page pulls its styles from `../../assets/scss/*` — i.e., from outside `dev-project/` — via plain relative `@import` in `<style lang="scss">`:

```scss
@import "../../assets/scss/header";
```

- New components should follow this same pattern (add a `_partial.scss` at repo root, import it relatively).
- Do **not** move `assets/` into `dev-project/` or "fix" the relative imports without asking; the cross-directory layout is deliberate.
- Styles are unscoped, so class names are global — use BEM-ish prefixes per component (`.hero__*`, `.ex-card__*`…) and check for collisions.
- Design tokens (palette « Nuit & laiton », fonts, breakpoints, mixins) live in `assets/scss/_tokens.scss`; every partial starts with `@import "tokens";` (variables/mixins only, so importing it repeatedly duplicates nothing).
- Global styles (reset, `.container`, `.section`, `.eyebrow`, `.title`, `.serif`, `.btn`, reveal animation) are in `_base.scss`, imported **once** in `dev-project/app.vue` together with FontAwesome. Don't import `_base` from components.
- One partial per component/page; don't import the same non-token partial from several components (it duplicates CSS).
- The logo is an inline SVG component (`components/WellyLogo.vue`, favicon in `public/favicon.svg`) — there is no logo image anymore.
- Editorial content (steps, example listings, FAQ, store links) lives in `dev-project/utils/content.ts`. Example listings are fictional and labelled « Exemple »; photos are Unsplash illustrations in `public/images/`.
- Scroll-reveal is the `v-reveal` directive (`plugins/reveal.ts`); content stays visible without JS (`.js` class set in `nuxt.config.ts`).
- The site has no user area: login/register pages were removed on purpose.

## Commands

```bash
cd dev-project
npm install        # postinstall runs `nuxt prepare`, which generates .nuxt/tsconfig.*.json
npm run dev        # dev server on http://localhost:3000
npm run build      # production build
npm run preview    # preview production build
```

There is **no lint, typecheck, or test setup** for the Nuxt app — `npm run build` is the only verification step. `tsconfig.json` is just references into the generated `.nuxt/` configs, so typecheck/IDE support breaks until `npm install` has run at least once.

To recompile root CSS (only needed if touching `main.scss`):

```bash
# from repo root; root package.json provides the sass CLI
npx sass assets/scss/main.scss assets/css/main.css
```

API (`api_project/`, NestJS 12 ESM + TypeORM + PostgreSQL/PostGIS on Neon) — see `api_project/README.md`:

```bash
cd api_project
npm run start:dev      # migrations run automatically on boot; /docs = Swagger
npm test               # unit (Vitest + SWC)
npm run test:e2e       # e2e against a real DB: .env DATABASE_URL, isolated schema welly_test (~10 min on Neon)
npm run typecheck && npm run lint
```

- Schema changes = hand-written SQL migrations in `src/database/migrations/` (no `synchronize`); columns are snake_case (custom naming strategy), properties camelCase.
- Extensions (postgis, btree_gist, unaccent, pg_trgm, pgcrypto) live in `public`; `DATABASE_SCHEMA` lets tests use their own schema with `search_path=<schema>,public`.
- Errors always go through `AppError` → `{ error: { code, message } }` (French messages). Paginated lists use keyset cursors compared at millisecond precision (`date_trunc('milliseconds', …)`).
- External services sit behind interfaces with dev defaults: `OTP_SENDER` (console), `PUSH_SENDER` (log), `STORAGE` (local `/media`). e2e tests override OTP with `InMemoryOtpSender`.
- Docker/WSL is not available on the dev machine; `docker-compose.yml` exists for machines that have it.

Flutter (`mobile_project/`, run from inside it): `flutter pub get`, `flutter analyze` (must be clean), `flutter test`, `flutter run --dart-define=API_URL=http://<host>:3000/v1` (default `10.0.2.2` on Android emulator, `localhost` elsewhere). Push (Firebase) is optional: without `google-services.json` / `GoogleService-Info.plist` the app falls back to a no-op push service. Icons/splash: `flutter test tool/render_branding_test.dart` then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`. CI runs analyze + test in the `mobile` job.

## Git gotchas

- **Root `node_modules/` is committed** (~5.9k tracked files) and there is no root `.gitignore` — only `dev-project/.gitignore` exists. Running `npm install`/upgrading `sass` or FontAwesome at the root creates a massive diff; don't commit dependency changes unless the user asks.
- `dev-project/node_modules/` is properly ignored — don't add it back.
- History shows GitHub Pages was used before (a `CNAME` was created then deleted); deployment flow is currently unspecified.

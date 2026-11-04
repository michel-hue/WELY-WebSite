    # AGENTS.md

## Repo layout

One repo holds three mostly independent parts:

- **`dev-project/`** — the active Nuxt 4 app (WELY marketing site: index, about, contact, login, register). Has its own `package.json` and lockfile; it is not a workspace. Run all npm commands from inside `dev-project/`.
- **`assets/scss/`** — shared SCSS partials at the **repo root**, outside the Nuxt app (see quirk below). `assets/css/main.css` is a compiled artifact of `main.scss` from a pre-Nuxt version of the site; nothing references it — treat the `.scss` partials as the source of truth and don't hand-edit the CSS.
- **`mobile_project/`** — a near-default Flutter starter app (`lib/main.dart` only). Currently **untracked in git** (`git status` shows `?? mobile_project/`); changing that is a decision for the user.

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

Flutter (only if working on `mobile_project/`): `flutter pub get`, `flutter run`, `flutter analyze` (uses `flutter_lints` via `analysis_options.yaml`).

## Git gotchas

- **Root `node_modules/` is committed** (~5.9k tracked files) and there is no root `.gitignore` — only `dev-project/.gitignore` exists. Running `npm install`/upgrading `sass` or FontAwesome at the root creates a massive diff; don't commit dependency changes unless the user asks.
- `dev-project/node_modules/` is properly ignored — don't add it back.
- History shows GitHub Pages was used before (a `CNAME` was created then deleted); deployment flow is currently unspecified.

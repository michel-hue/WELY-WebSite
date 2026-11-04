# WELY Web — Nuxt 4 marketing site

Marketing site (index, about, contact, login, register) built with Nuxt 4.
Styles live in shared SCSS partials at the repo root (`../../assets/scss/*`).

## Setup

```bash
cd dev-project
npm install        # postinstall runs `nuxt prepare`
```

Copy env template and adjust if needed:

```bash
cp .env.example .env
```

## Configuration (API base URL)

The web API base URL is configured through `runtimeConfig.public.apiBase`
(`nuxt.config.ts`), sourced from `NUXT_PUBLIC_API_BASE`:

- `dev-project/.env` (or environment): `NUXT_PUBLIC_API_BASE=http://localhost:3000`
- Default fallback: `http://localhost:3000`

In code, use `useApiBase()` (see `composables/useApiBase.ts`).

## Development

```bash
npm run dev        # http://localhost:3000
```

## Production

```bash
npm run build      # production build
npm run preview    # preview production build
```

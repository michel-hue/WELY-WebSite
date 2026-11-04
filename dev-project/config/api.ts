// Centralized API base URL.
//
// Source of truth: runtimeConfig.public.apiBase (nuxt.config.ts),
// overridable via the NUXT_PUBLIC_API_BASE env var.
// In components/pages, prefer `useApiBase()` (composables/useApiBase.ts).
// This constant is a fallback for non-runtime contexts (e.g. config files).
//
// Example usage in a component/page:
//   const apiBase = useApiBase()
//   const data = await $fetch(`${apiBase}/api/foo`)
export const API_BASE_URL =
  (typeof process !== 'undefined' && process.env?.NUXT_PUBLIC_API_BASE) ||
  'http://localhost:3000'

// Source de vérité : runtimeConfig.public.apiBase (nuxt.config.ts),
// surchargé par NUXT_PUBLIC_API_BASE. Ce composable expose la valeur résolue.
export const useApiBase = () => {
  const config = useRuntimeConfig()
  return config.public.apiBase as string
}

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'http://localhost:3000'
    }
  },
  app: {
    head: {
      htmlAttrs: { lang: 'fr' },
      title: 'WELLY — Maisons & appartements, une seule app',
      meta: [
        { name: 'description', content: "WELLY réunit ceux qui cherchent un logement et ceux qui en proposent, dans une seule application mobile." },
        { name: 'theme-color', content: '#13161B' }
      ],
      link: [
        // Logo WELLY dans l'onglet : SVG (navigateurs récents), ICO (repli), icône iOS
        { rel: 'icon', href: '/favicon.ico', sizes: '48x48' },
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500&family=Instrument+Serif:ital@0;1&display=swap' }
      ],
      // Active les animations d'apparition uniquement si JS est disponible.
      script: [{ innerHTML: "document.documentElement.classList.add('js')" }]
    }
  }
})

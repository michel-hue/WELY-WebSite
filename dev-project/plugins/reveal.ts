// Directive v-reveal : fondu doux à l'apparition au défilement.
// Usage : <div v-reveal>…</div> ou <div v-reveal="120"> (délai en ms).
// Le style correspondant est dans assets/scss/_base.scss ([data-reveal]).
export default defineNuxtPlugin((nuxtApp) => {
  let observer: IntersectionObserver | null = null

  const getObserver = () => {
    if (!observer) {
      observer = new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            if (entry.isIntersecting) {
              entry.target.classList.add('is-visible')
              observer!.unobserve(entry.target)
            }
          }
        },
        { rootMargin: '0px 0px -8% 0px', threshold: 0.12 }
      )
    }
    return observer
  }

  nuxtApp.vueApp.directive<HTMLElement, number | undefined>('reveal', {
    getSSRProps: (binding) => ({
      'data-reveal': '',
      style: binding.value ? `--reveal-delay:${binding.value}ms` : undefined
    }),
    mounted(el, binding) {
      el.setAttribute('data-reveal', '')
      if (binding.value) el.style.setProperty('--reveal-delay', `${binding.value}ms`)
      if (!('IntersectionObserver' in window)) {
        el.classList.add('is-visible')
        return
      }
      getObserver().observe(el)
    },
    unmounted(el) {
      observer?.unobserve(el)
    }
  })
})

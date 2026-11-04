<template>
  <header class="site-header" :class="{ 'is-solid': solid && !menuOpen }">
    <div class="site-header__inner container">
      <NuxtLink to="/" class="site-header__brand" aria-label="WELLY, accueil" @click="menuOpen = false">
        <WellyLogo tone="light" :size="26" />
      </NuxtLink>

      <nav id="site-nav" class="site-nav" :class="{ 'is-open': menuOpen }" aria-label="Navigation principale">
        <ul>
          <li v-for="link in links" :key="link.to">
            <NuxtLink :to="link.to" :class="{ 'is-current': route.path === link.to }" @click="menuOpen = false">{{ link.label }}</NuxtLink>
          </li>
        </ul>
        <NuxtLink to="/telechargement" class="btn btn--ghost site-nav__cta" @click="menuOpen = false">Télécharger</NuxtLink>
      </nav>

      <button
        type="button"
        class="burger"
        :class="{ 'is-open': menuOpen }"
        :aria-expanded="menuOpen"
        aria-controls="site-nav"
        @click="menuOpen = !menuOpen"
      >
        <span class="visually-hidden">Menu</span>
        <i></i><i></i>
      </button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

const links = [
  { to: '/fonctionnement', label: 'Fonctionnement' },
  { to: '/#exemples', label: 'Exemples' },
  { to: '/about', label: 'À propos' },
  { to: '/contact', label: 'Contact' }
]

const route = useRoute()
const solid = ref(false)
const menuOpen = ref(false)

const onScroll = () => { solid.value = window.scrollY > 24 }

onMounted(() => {
  onScroll()
  window.addEventListener('scroll', onScroll, { passive: true })
})
onBeforeUnmount(() => window.removeEventListener('scroll', onScroll))

// Bloque le défilement de la page quand le menu mobile est ouvert
watch(menuOpen, (open) => {
  document.documentElement.style.overflow = open ? 'hidden' : ''
})
</script>

<style lang="scss">
@import "../../assets/scss/header";
</style>

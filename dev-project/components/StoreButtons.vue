<template>
  <div class="store-buttons" :class="`store-buttons--${tone}`">
    <a :href="storeLinks.appStore" class="store-btn" aria-label="Télécharger sur l'App Store">
      <i class="fa-brands fa-apple" aria-hidden="true"></i>
      <span><small>Télécharger sur</small>App Store</span>
    </a>
    <a :href="storeLinks.googlePlay" class="store-btn" aria-label="Disponible sur Google Play">
      <i class="fa-brands fa-google-play" aria-hidden="true"></i>
      <span><small>Disponible sur</small>Google Play</span>
    </a>
  </div>
</template>

<script setup lang="ts">
import { storeLinks } from '~/utils/content'

withDefaults(defineProps<{
  /** light = boutons clairs (sur fond sombre), dark = boutons sombres (sur fond clair) */
  tone?: 'light' | 'dark'
}>(), { tone: 'dark' })
</script>

<style lang="scss">
@import "../../assets/scss/store";
</style>

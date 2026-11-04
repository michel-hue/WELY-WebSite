<template>
  <span class="welly-logo" :class="`welly-logo--${tone}`">
    <svg :width="size" :height="size" viewBox="0 0 48 48" aria-hidden="true" focusable="false">
      <path class="welly-logo__house" d="M24 3 L45 20 V41 a4 4 0 0 1 -4 4 H7 a4 4 0 0 1 -4 -4 V20 Z" />
      <path
        class="welly-logo__w"
        d="M12 22 L17 37 L24 28 L31 37 L36 22"
        fill="none"
        :stroke-width="size < 28 ? 3.6 : 2.6"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    <span v-if="wordmark" class="welly-logo__word">WELLY</span>
    <span v-else class="visually-hidden">WELLY</span>
  </span>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  /** light = maison claire (sur fond sombre), dark = maison sombre (sur fond clair) */
  tone?: 'light' | 'dark'
  size?: number
  wordmark?: boolean
}>(), { tone: 'light', size: 26, wordmark: true })
</script>

<style lang="scss">
@import "../../assets/scss/logo";
</style>

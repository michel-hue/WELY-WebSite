<template>
  <section class="page-hero">
    <div class="container page-hero__inner">
      <p class="eyebrow" v-reveal>{{ eyebrow }}</p>
      <h1 class="page-hero__title" v-reveal="80"><slot name="title" /></h1>
      <p v-if="$slots.default" class="page-hero__lead" v-reveal="160"><slot /></p>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{ eyebrow: string }>()
</script>

<style lang="scss">
@import "../../assets/scss/page-hero";
</style>

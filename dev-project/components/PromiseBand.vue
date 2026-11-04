<template>
  <section id="promesse" class="promise">
    <div class="container promise__grid">
      <div v-for="(p, i) in promises" :key="p.big" class="promise__item" v-reveal="i * 90">
        <span class="promise__big serif">{{ p.big }}</span>
        <span class="promise__small">{{ p.small }}</span>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { promises } from '~/utils/content'
</script>

<style lang="scss">
@import "../../assets/scss/promise";
</style>

<template>
  <section id="faq" class="section faq">
    <div class="container faq__grid">
      <div v-reveal>
        <p class="eyebrow">Questions fréquentes</p>
        <h2 class="title">Vos questions,<br /><span class="serif">nos réponses.</span></h2>
        <p class="lead faq__lead">
          Une autre question ? <NuxtLink to="/contact" class="faq__contact">Écrivez-nous</NuxtLink>.
        </p>
      </div>

      <div class="faq__list" v-reveal="120">
        <details v-for="item in faq" :key="item.q" class="faq__item">
          <summary>
            <span>{{ item.q }}</span>
            <i aria-hidden="true"></i>
          </summary>
          <p>{{ item.a }}</p>
        </details>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { faq } from '~/utils/content'
</script>

<style lang="scss">
@import "../../assets/scss/faq";
</style>

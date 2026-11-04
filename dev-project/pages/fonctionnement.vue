<template>
  <div>
    <PageHero eyebrow="Fonctionnement">
      <template #title>Un seul compte, <span class="serif">deux façons</span> d'utiliser WELLY.</template>
      Tout le monde commence en mode acheteur. Quand vous le souhaitez, vous passez en mode vendeur
      pour publier vos propres biens, sans créer de nouveau compte.
    </PageHero>

    <section class="section journeys">
      <div class="container">
        <div v-for="(j, ji) in journeys" :key="j.role" class="journey" :class="{ 'journey--flip': ji % 2 }">
          <div class="journey__media" v-reveal>
            <img :src="j.img" alt="" loading="lazy" />
            <PhoneMockup :screen="j.screen" class="journey__phone" />
          </div>

          <div class="journey__text">
            <p class="eyebrow" v-reveal>{{ j.eyebrow }}</p>
            <h2 class="title" v-reveal="80" v-html="j.title"></h2>
            <ol class="journey__steps">
              <li v-for="(step, i) in steps[j.role]" :key="step.title" v-reveal="140 + i * 80">
                <span class="journey__num serif">0{{ i + 1 }}</span>
                <div>
                  <h3>{{ step.title }}</h3>
                  <p>{{ step.text }}</p>
                </div>
              </li>
            </ol>
          </div>
        </div>
      </div>
    </section>

    <AppShowcase />
    <FaqList />
    <DownloadCta />
  </div>
</template>

<script setup lang="ts">
import { steps } from '~/utils/content'

useHead({ title: 'Fonctionnement — WELLY' })

const journeys = [
  {
    role: 'buyer',
    eyebrow: 'Côté acheteur',
    title: 'Trouver, comparer, <span class="serif">réserver.</span>',
    img: '/images/appartement-sejour.webp',
    screen: 'search'
  },
  {
    role: 'seller',
    eyebrow: 'Côté vendeur',
    title: 'Publier et gérer <span class="serif">en toute simplicité.</span>',
    img: '/images/maison-facade.webp',
    screen: 'seller'
  }
] as const
</script>

<style lang="scss">
@import "../../assets/scss/fonctionnement";
</style>

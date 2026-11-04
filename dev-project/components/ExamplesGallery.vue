<template>
  <section id="exemples" class="section section--sand examples">
    <div class="container">
      <div class="examples__head">
        <div v-reveal>
          <p class="eyebrow">Exemples</p>
          <h2 class="title">Un aperçu de <span class="serif">ce que vous trouverez.</span></h2>
        </div>
        <p class="lead" v-reveal="120">
          Villas, appartements, studios ou maisons de vacances : voici le type de biens que vous découvrirez dans l'application.
        </p>
      </div>

      <div class="examples__grid">
        <article
          v-for="(ex, i) in examples"
          :key="ex.title"
          class="ex-card"
          :class="{ 'ex-card--wide': i === 0 }"
          v-reveal="(i % 3) * 100"
        >
          <div class="ex-card__img">
            <img :src="ex.img" :alt="`${ex.title}, ${ex.place} (photo d'illustration)`" loading="lazy" />
            <span class="ex-card__tag">Exemple</span>
          </div>
          <div class="ex-card__body">
            <div>
              <h3>{{ ex.title }}</h3>
              <p class="ex-card__place"><LineIcon name="pin" :size="14" /> {{ ex.place }} · {{ ex.meta }}</p>
            </div>
            <p class="ex-card__price"><strong>{{ ex.price }}</strong> {{ ex.unit }}</p>
          </div>
        </article>
      </div>

      <p class="examples__note">Annonces fictives présentées à titre d'exemple. Photos d'illustration.</p>
    </div>
  </section>
</template>

<script setup lang="ts">
import { examples } from '~/utils/content'
</script>

<style lang="scss">
@import "../../assets/scss/examples";
</style>

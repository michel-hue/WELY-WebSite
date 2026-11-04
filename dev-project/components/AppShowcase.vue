<template>
  <section class="section section--dark showcase">
    <div class="container showcase__grid">
      <div class="showcase__text">
        <p class="eyebrow" v-reveal>L'application</p>
        <h2 class="title" v-reveal="80">
          Acheteur aujourd'hui,<br />
          <span class="serif showcase__accent">vendeur demain.</span>
        </h2>
        <p class="lead" v-reveal="160">
          Passez en mode vendeur depuis votre compte pour publier vos biens et gérer les demandes,
          sans jamais créer de second compte.
        </p>
        <ul class="showcase__list">
          <li v-for="(f, i) in features" :key="f.title" v-reveal="200 + i * 80">
            <LineIcon :name="f.icon" :size="24" />
            <div><strong>{{ f.title }}</strong><span>{{ f.text }}</span></div>
          </li>
        </ul>
      </div>

      <div class="showcase__phones" v-reveal="150">
        <PhoneMockup screen="search" class="showcase__phone showcase__phone--side" />
        <PhoneMockup screen="detail" class="showcase__phone showcase__phone--main" float />
        <PhoneMockup screen="seller" class="showcase__phone showcase__phone--side" />
        <div class="showcase__glow" aria-hidden="true"></div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
const features = [
  { icon: 'search', title: 'Recherche & favoris', text: 'Filtrez par quartier, prix et pièces, gardez vos coups de cœur.' },
  { icon: 'calendar', title: 'Réservation suivie', text: 'Envoyez une demande et suivez sa réponse en temps réel.' },
  { icon: 'camera', title: 'Publication avec photos', text: 'Mettez votre bien en ligne en quelques minutes.' }
] as const
</script>

<style lang="scss">
@import "../../assets/scss/showcase";
</style>

<template>
  <section class="hero">
    <div class="hero__frame">
      <img
        class="hero__img"
        src="/images/hero-salon.webp"
        alt=""
        width="1920"
        height="1280"
        fetchpriority="high"
      />
      <div class="hero__shade" aria-hidden="true"></div>

      <div class="hero__content container">
        <div class="hero__text">
          <p class="hero__eyebrow" v-reveal>Maisons &amp; appartements · Côte d'Ivoire</p>
          <h1 class="hero__title" v-reveal="100">
            Se sentir chez soi,<br />
            <span class="serif">avant même d'arriver.</span>
          </h1>
          <p class="hero__lead" v-reveal="200">
            WELLY réunit ceux qui cherchent et ceux qui proposent, dans une seule application.
          </p>
        </div>

        <div class="hero__card" v-reveal="320">
          <RoleToggle variant="glass" />
          <Transition name="fade-swap" mode="out-in">
            <p :key="role" class="hero__pitch">{{ roleCopy[role].pitch }}</p>
          </Transition>
          <NuxtLink to="/telechargement" class="btn btn--brass hero__btn">
            Télécharger l'application
          </NuxtLink>
          <NuxtLink to="/fonctionnement" class="hero__more">Voir comment ça marche →</NuxtLink>
        </div>
      </div>

      <a href="#promesse" class="hero__scroll" aria-label="Défiler vers la suite">
        <span></span>
      </a>
    </div>
  </section>
</template>

<script setup lang="ts">
import { roleCopy } from '~/utils/content'

const role = useRole()
</script>

<style lang="scss">
@import "../../assets/scss/hero";
</style>

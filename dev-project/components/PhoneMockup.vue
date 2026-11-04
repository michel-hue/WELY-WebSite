<template>
  <div class="phone" :class="{ 'phone--float': float }" aria-hidden="true">
    <div class="phone__screen">
      <div class="phone__status"><span>9:41</span><span class="phone__notch"></span><span>●●●</span></div>

      <!-- Écran : recherche -->
      <div v-if="screen === 'search'" class="ps">
        <p class="ps__hello">Bonjour Awa</p>
        <p class="ps__title">Où souhaitez-vous vivre ?</p>
        <div class="ps__search"><LineIcon name="search" :size="13" /> Cocody, Abidjan</div>
        <div class="ps__chips"><span class="on">Maison</span><span>Appart.</span><span>Studio</span></div>
        <div class="ps__card">
          <img src="/images/villa-contemporaine.webp" alt="" loading="lazy" />
          <div><b>Villa contemporaine</b><small>Angré · 5 pièces</small><em>650 000 F</em></div>
        </div>
        <div class="ps__card">
          <img src="/images/appartement-lumineux.webp" alt="" loading="lazy" />
          <div><b>Appartement lumineux</b><small>Riviera · 3 pièces</small><em>350 000 F</em></div>
        </div>
      </div>

      <!-- Écran : fiche d'un bien -->
      <div v-else-if="screen === 'detail'" class="pd">
        <div class="pd__img"><img src="/images/maison-jardin.webp" alt="" loading="lazy" /><span class="pd__fav"><LineIcon name="heart" :size="12" /></span></div>
        <div class="pd__body">
          <p class="pd__title">Maison familiale</p>
          <p class="pd__place"><LineIcon name="pin" :size="11" /> Bingerville</p>
          <div class="pd__specs"><span>4 pièces</span><span>Terrasse</span><span>Parking</span></div>
          <p class="pd__desc">Maison calme et lumineuse, proche des écoles et des commerces.</p>
          <div class="pd__foot"><span><b>400 000 F</b> / mois</span><span class="pd__btn">Réserver</span></div>
        </div>
      </div>

      <!-- Écran : mode vendeur -->
      <div v-else class="pv">
        <div class="pv__mode"><span>Mode vendeur</span><i></i></div>
        <p class="ps__title">Mes annonces</p>
        <div class="pv__item">
          <img src="/images/villa-piscine.webp" alt="" loading="lazy" />
          <div><b>Maison de vacances</b><small>Assinie</small><span class="pv__badge">2 demandes</span></div>
        </div>
        <div class="pv__item">
          <img src="/images/chambre.webp" alt="" loading="lazy" />
          <div><b>Studio meublé</b><small>Marcory</small><span class="pv__badge pv__badge--ok">En ligne</span></div>
        </div>
        <div class="pv__add">+ Publier un bien</div>
      </div>

      <div class="phone__tabbar"><LineIcon name="search" :size="14" /><LineIcon name="heart" :size="14" /><LineIcon name="calendar" :size="14" /><LineIcon name="house" :size="14" /></div>
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  screen?: 'search' | 'detail' | 'seller'
  float?: boolean
}>(), { screen: 'search', float: false })
</script>

<style lang="scss">
@import "../../assets/scss/phone";
</style>

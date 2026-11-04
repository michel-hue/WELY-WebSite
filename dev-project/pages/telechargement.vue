<template>
  <div>
    <section class="download">
      <div class="container download__grid">
        <div class="download__text">
          <p class="eyebrow" v-reveal>Télécharger</p>
          <h1 class="download__title" v-reveal="80">WELLY, <span class="serif">dans votre poche.</span></h1>
          <p class="download__lead" v-reveal="160">
            Une seule application pour chercher, réserver et proposer des maisons et des appartements.
            Disponible sur iPhone et Android.
          </p>
          <div v-reveal="240"><StoreButtons tone="light" /></div>

          <div class="download__qr" v-reveal="320">
            <div class="download__qr-box" aria-hidden="true">
              <WellyLogo tone="light" :size="34" :wordmark="false" />
            </div>
            <p>Le QR code sera disponible au lancement de l'application.<br />Scannez-le avec votre téléphone pour l'installer.</p>
          </div>
        </div>

        <div class="download__phones" v-reveal="200">
          <PhoneMockup screen="search" class="download__phone download__phone--back" />
          <PhoneMockup screen="detail" class="download__phone" float />
        </div>
      </div>
    </section>

    <HowItWorks :show-link="true" />
    <FaqList />
  </div>
</template>

<script setup lang="ts">
useHead({ title: 'Télécharger l’application — WELLY' })
</script>

<style lang="scss">
@import "../../assets/scss/download";
</style>

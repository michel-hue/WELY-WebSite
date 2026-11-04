<template>
  <section class="cta-band">
    <div class="container">
      <div class="cta-band__box">
        <div class="cta-band__text" v-reveal>
          <WellyLogo tone="light" :size="40" :wordmark="false" class="cta-band__logo" />
          <h2 class="title">Votre prochain chez-vous<br /><span class="serif">commence ici.</span></h2>
          <p class="lead">Téléchargez WELLY sur iPhone et Android.</p>
          <StoreButtons tone="light" />
        </div>
        <img class="cta-band__img" src="/images/interieur-cuisine.webp" alt="" loading="lazy" />
      </div>
    </div>
  </section>
</template>

<style lang="scss">
@import "../../assets/scss/cta";
</style>

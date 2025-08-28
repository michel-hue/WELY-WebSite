<template>
      <section class="presentation-mission">
    <!-- Présentation -->
    <div class="intro fade-up">
      <div class="text">
        <h2>Bienvenue sur Wely</h2>
        <p>
        Parcourez notre sélection de résidences exclusives en Côte d’Ivoire, conçues pour allier confort, sérénité et authenticité.
        </p>
      </div>
      <div class="image">
        <img src="/image1.jpg" alt="Illustration logement" />
      </div>
    </div>
  </section>
   <!-- Mission -->
  <section class="mission">
    <h2>Notre mission</h2>
    <p class="mission-intro">
      Vous offrir un logement sûr, moderne et confortable.
    </p>

    <div class="features-row">
      <div class="features-track">
        <div class="feature">
          <img src="/image6.jpg" alt="Sécurité" />
          <h3>Sécurité</h3>
          <p>Chaque résidence est entièrement sécurisée.</p>
        </div>
        <div class="feature">
          <img src="/image4.jpg" alt="Confort" />
          <h3>Confort</h3>
          <p>Des residences pensés pour votre bien-être.</p>
        </div>
        <div class="feature">
          <img src="/image5.jpg" alt="Emplacement" />
          <h3>Emplacement</h3>
          <p>À proximité des services essentiels.</p>
        </div>

        <!-- Duplication pour défilement fluide -->
        <div class="feature">
          <img src="/image7.jpg" alt="Sécurité" />
          <h3>Sécurité</h3>
          <p>Chaque résidence est entièrement sécurisée.</p>
        </div>
        <div class="feature">
          <img src="/image1.jpg" alt="Confort" />
          <h3>Confort</h3>
          <p>Des appartements pensés pour votre bien-être.</p>
        </div>
        <div class="feature">
          <img src="/image2.jpg" alt="Emplacement" />
          <h3>Emplacement</h3>
          <p>À proximité des services essentiels.</p>
        </div>
      </div>
    </div>
  </section>
</template>
<script setup>
import { onMounted } from "vue";

// Animation fade-up simple
onMounted(() => {
  const elements = document.querySelectorAll(".fade-up");
  elements.forEach((el, i) => {
    setTimeout(() => {
      el.classList.add("show");
    }, 200 * (i + 1)); // petit délai en cascade
  });
});
</script>
<style lang="scss">
@import "../../assets/scss/services";
</style>
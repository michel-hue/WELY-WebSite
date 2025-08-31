<template>
  <section class="presentation-mission">
    <!-- Présentation -->
    <div class="intro fade-up">
      <div class="text">
        <h2>Bienvenue sur Wely</h2>
        <p>
          Wely est la plateforme qui connecte les propriétaires aux locataires. 
          Les visiteurs peuvent découvrir et réserver des résidences, 
          mais notre priorité est de vous aider, en tant que propriétaire, 
          à valoriser vos biens et à toucher plus de clients.
        </p>
      </div>
      <div class="image">
        <img src="/image10.jpg" alt="Illustration logement" />
      </div>
    </div>
  </section>

  <!-- Mission -->
  <section class="mission">
    <h2>Notre mission</h2>
    <p class="mission-intro">
      Offrir aux locataires des logements fiables tout en permettant aux propriétaires 
      de générer des revenus en toute simplicité.
    </p>

    <div class="features-row">
      <div class="features-track">
        <div class="feature">
          <img src="/image6.jpg" alt="Sécurité" />
          <h3>Sécurité</h3>
          <p>Nous garantissons que chaque bien publié est protégé et sécurisé.</p>
        </div>
        <div class="feature">
          <img src="/image4.jpg" alt="Confort" />
          <h3>Visibilité</h3>
          <p>Vos maisons sont mises en avant pour attirer davantage de locataires.</p>
        </div>
        <div class="feature">
          <img src="/image5.jpg" alt="Revenus" />
          <h3>Revenus</h3>
          <p>Transformez vos résidences en une source de bénéfices réguliers.</p>
        </div>

        <!-- Duplication pour défilement fluide -->
        <div class="feature">
          <img src="/image7.jpg" alt="Sécurité" />
          <h3>Sécurité</h3>
          <p>Nous garantissons que chaque bien publié est protégé et sécurisé.</p>
        </div>
        <div class="feature">
          <img src="/image1.jpg" alt="Visibilité" />
          <h3>Visibilité</h3>
          <p>Vos maisons sont mises en avant pour attirer davantage de locataires.</p>
        </div>
        <div class="feature">
          <img src="/image2.jpg" alt="Revenus" />
          <h3>Revenus</h3>
          <p>Transformez vos résidences en une source de bénéfices réguliers.</p>
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
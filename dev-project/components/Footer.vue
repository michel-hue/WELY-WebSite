<template>
  <footer class="site-footer">
    <div class="container">
      <div class="site-footer__top">
        <div class="site-footer__brand">
          <WellyLogo tone="light" :size="30" />
          <p>Maisons et appartements : chercher, réserver ou proposer, depuis une seule application.</p>
        </div>

        <nav class="site-footer__cols" aria-label="Pied de page">
          <div>
            <h4>Découvrir</h4>
            <ul>
              <li><NuxtLink to="/fonctionnement">Fonctionnement</NuxtLink></li>
              <li><NuxtLink to="/#exemples">Exemples</NuxtLink></li>
              <li><NuxtLink to="/telechargement">Télécharger l'app</NuxtLink></li>
            </ul>
          </div>
          <div>
            <h4>WELLY</h4>
            <ul>
              <li><NuxtLink to="/about">À propos</NuxtLink></li>
              <li><NuxtLink to="/contact">Contact</NuxtLink></li>
              <li><NuxtLink to="/contact#faq">Questions fréquentes</NuxtLink></li>
            </ul>
          </div>
          <div>
            <h4>Suivez-nous</h4>
            <div class="site-footer__social">
              <a href="#" aria-label="Facebook"><i class="fa-brands fa-facebook-f"></i></a>
              <a href="#" aria-label="Instagram"><i class="fa-brands fa-instagram"></i></a>
              <a href="#" aria-label="TikTok"><i class="fa-brands fa-tiktok"></i></a>
              <a href="#" aria-label="LinkedIn"><i class="fa-brands fa-linkedin-in"></i></a>
            </div>
          </div>
        </nav>
      </div>

      <div class="site-footer__bottom">
        <p>&copy; {{ year }} WELLY. Tous droits réservés.</p>
        <p>Abidjan, Côte d'Ivoire · Photos d'illustration : Unsplash</p>
      </div>
    </div>
  </footer>
</template>

<script setup lang="ts">
const year = new Date().getFullYear()
</script>

<style lang="scss">
@import "../../assets/scss/footer";
</style>

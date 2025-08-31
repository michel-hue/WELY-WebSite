<template>
  <footer class="main-footer">
    <div class="footer-content">
      <div class="footer-brand">
        <div class="brand-info">
          <img src="/logo.png" class="logo" alt="Logo Wely" />
          <span class="brand-name">Wely</span>
        </div>
        <p class="brand-desc">
          Votre partenaire idéal pour trouver la maison de vos rêves,
          facilement et rapidement.
        </p>
      </div>

      <div class="footer-links">
        <div class="links-column">
          <h4>Entreprise</h4>
          <ul>
            <li><a href="/about">À propos de nous</a></li>
            <li><a href="#">Carrières</a></li>
            <li><a href="#">Actualités</a></li>
            <li><a href="#">Kit Presse</a></li>
          </ul>
        </div>

        <div class="links-column">
          <h4>Ressources</h4>
          <ul>
            <li><a href="#">Blog</a></li>
            <li><a href="/contact">Centre d’aide</a></li>
            <li><a href="#">FAQ</a></li>
            <li><a href="/contact">Contact</a></li>
          </ul>
        </div>
      </div>

      <div class="footer-social">
        <h4>Suivez-nous</h4>
        <div class="social-icons">
          <a href="#" aria-label="Facebook"><i class="fa-brands fa-facebook"></i></a>
          <a href="#" aria-label="Instagram"><i class="fa-brands fa-instagram"></i></a>
          <a href="#" aria-label="X (Twitter)"><i class="fa-brands fa-x-twitter"></i></a>
          <a href="#" aria-label="LinkedIn"><i class="fa-brands fa-linkedin"></i></a>
        </div>
      </div>
    </div>

    <div class="footer-copyright">
      <p>&copy; {{ new Date().getFullYear() }} Wely. Tous droits réservés.</p>
    </div>
  </footer>
</template>

<style lang="scss">
@import '../../assets/scss/footer'
</style>

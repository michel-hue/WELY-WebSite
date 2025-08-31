<template>
    <div class="contenaires">
     <header>
        <Header/>
     </header>
     <section><PresentServices/></section>
     <section><Offres /></section>
     <section><App/></section>
     <section><Temoignages/></section>
      <section><BecomeOwner/></section>
     <footer><Footer/></footer>
    </div>
</template>
<script setup>
import App from '~/components/App.vue';
import Footer from '~/components/Footer.vue';
import Header from '~/components/Header.vue';
import Offres from '~/components/Offres.vue';
import Temoignages from '~/components/Temoignages.vue';
import PresentServices from '~/components/PresentServices.vue';
import BecomeOwner from '~/components/BecomeOwner.vue';
</script>
<style lang="scss">
/* Reset global */
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  overflow-x: hidden; 
  box-sizing: border-box;
}

/* Conteneur principal */
.contenaires {
  width: 100%;
  overflow-x: hidden; // sécurité supplémentaire
}

/* Toutes les sections et composants */
section, header, footer, .contenaires > * {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
}

/* Images */
img {
  max-width: 100%;
  height: auto;
  display: block;
}


* {
  box-sizing: border-box;
}

</style>
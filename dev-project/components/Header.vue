<template>
    <!-- MINI-BAR EN HAUT -->
     <div class="Headers">
    <div class="top-bar">
      <p>Bienvenue sur Wely, trouvez la résidence idéal rapidement !</p>
      <div class="top-actions">
        <a href="#" >Sign in</a>
        <a href="#" class="lien">Sign up</a>
      </div>
    </div>

    <!-- HEADER PRINCIPAL -->
    <header :class="['header', { 'fixed-header': isFixed }]">
      <div class="logo">
        <img src="/logo.png" alt="logo" />
        <h1>Wely</h1>
      </div>

      <!-- Navigation -->
      <nav>
        <ul :class="['nav', { 'active': mobileMenu }]">
          <li><a href="#" class="active">Home</a></li>
          <li class="dropdown">
            <a href="#">About</a>
          </li>
          <li><a href="#">Contact</a></li>
        </ul>
      </nav>

      <!-- Hamburger Mobile -->
      <div class="hamburger" @click="mobileMenu = !mobileMenu">
        <span></span>
        <span></span>
        <span></span>
      </div>
    </header>
</div>   

    <!-- BANNIÈRE -->
    <section class="banner">
      <div class="overlay">
        <div class="accroche">
          <h1>Réservez  <br> la Residence de vos rêves</h1>
          <span>Choisissez parmi nos résidences confortables et adaptées à vos besoins</span>
          <button class="cta3">Decouvrir</button>
        </div>
      </div>
    </section>
</template>

<script setup>
import { ref, onMounted } from 'vue'

const isFixed = ref(false)
const mobileMenu = ref(false)

onMounted(() => {
  const topBarHeight = document.querySelector('.top-bar').offsetHeight

  window.addEventListener('scroll', () => {
    isFixed.value = window.scrollY >= topBarHeight
  })
})
</script>
<style lang="scss" scoped>
@import "../../assets/scss/header";
</style>








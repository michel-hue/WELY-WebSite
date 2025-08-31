<template>
    <div class="container-contact">
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
    <li>
      <router-link to="/" exact-active-class="active"><i class="far fa-house"></i> Home</router-link>
    </li>
    <li class="dropdown">
      <router-link to="/about" exact-active-class="active"><i class="far fa-question-circle"></i> About</router-link>
    </li>
    <li>
      <router-link to="/contact" exact-active-class="active"><i class="far fa-address-book"></i> Contact</router-link>
    </li>
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
<section><Contact/></section>
<section><Footer/></section>

 
    </div>
</template>

<script setup lang="ts">
import Footer from '~/components/Footer.vue';
import { ref, onMounted } from 'vue'
import Contact from '~/components/contact.vue';

const isFixed = ref(false)
const mobileMenu = ref(false)

onMounted(() => {
  const topBarHeight = document.querySelector('.top-bar').offsetHeight

  window.addEventListener('scroll', () => {
    isFixed.value = window.scrollY >= topBarHeight
  })
})

</script>
<style lang="scss">
@import '../../assets/scss/header'
</style>
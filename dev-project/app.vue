<template>
  <div class="site">
    <NuxtRouteAnnouncer />
    <a href="#contenu" class="skip-link">Aller au contenu</a>
    <Header />
    <main id="contenu">
      <NuxtPage />
    </main>
    <Footer />
  </div>
</template>

<script setup lang="ts">
// Le menu mobile bloque le défilement : on le rétablit à chaque navigation.
const router = useRouter()
router.afterEach(() => {
  if (import.meta.client) document.documentElement.style.overflow = ''
})
</script>

<style lang="scss">
@import "@fortawesome/fontawesome-free/css/all.min.css";
@import "../assets/scss/base";

.skip-link {
  position: absolute;
  left: 16px;
  top: -60px;
  z-index: 100;
  background: #EFEBE4;
  color: #13161B;
  padding: 10px 16px;
  border-radius: 8px;
  &:focus { top: 16px; }
}
</style>

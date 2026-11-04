<template>
  <div>
    <PageHero eyebrow="À propos">
      <template #title>Nous sommes <span class="serif">WELLY.</span></template>
      Nous aidons chacun à trouver le logement qui lui correspond, partout en Côte d'Ivoire,
      directement depuis son téléphone.
    </PageHero>

    <section class="section about-story">
      <div class="container about-story__grid">
        <div class="about-story__text">
          <p class="eyebrow" v-reveal>Notre histoire</p>
          <h2 class="title" v-reveal="80">Rendre la recherche de logement <span class="serif">simple et équitable.</span></h2>
          <p v-reveal="160">
            WELLY est né d'une idée claire : faire de la location et de la réservation de logements une
            expérience fluide, transparente et accessible, aussi bien pour ceux qui cherchent que pour
            ceux qui proposent.
          </p>
          <p v-reveal="220">
            Familles, étudiants, travailleurs, voyageurs ou retraités : chacun doit pouvoir trouver et
            réserver le bien qui lui convient, sans intermédiaire compliqué. Et chacun doit pouvoir
            proposer son bien aussi facilement, depuis le même compte.
          </p>
        </div>

        <div class="about-story__media">
          <img src="/images/appartement-sejour.webp" alt="" class="about-story__img about-story__img--a" loading="lazy" v-reveal />
          <img src="/images/maison-facade.webp" alt="" class="about-story__img about-story__img--b" loading="lazy" v-reveal="150" />
        </div>
      </div>
    </section>

    <section class="section section--dark about-values">
      <div class="container">
        <p class="eyebrow" v-reveal>Nos valeurs</p>
        <h2 class="title" v-reveal="80">Ce qui nous <span class="serif">guide.</span></h2>
        <div class="about-values__grid">
          <article v-for="(v, i) in values" :key="v.title" v-reveal="120 + i * 90">
            <LineIcon :name="v.icon" :size="36" />
            <h3>{{ v.title }}</h3>
            <p>{{ v.text }}</p>
          </article>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container about-quote" v-reveal>
        <p class="serif">« Chez WELLY, nous voulons rendre le logement plus accessible, plus transparent et plus adapté aux besoins de chacun. »</p>
      </div>
    </section>

    <DownloadCta />
  </div>
</template>

<script setup lang="ts">
useHead({ title: 'À propos — WELLY' })

const values = [
  { icon: 'leaf', title: 'Simplicité', text: 'Une seule application, un seul compte, quelques gestes pour réserver ou publier.' },
  { icon: 'eye', title: 'Transparence', text: 'Des annonces claires, avec photos, description, localisation et prix affichés.' },
  { icon: 'pin', title: 'Proximité', text: 'Un service pensé pour la Côte d’Ivoire et pour la réalité de ses quartiers.' }
] as const
</script>

<style lang="scss">
@import "../../assets/scss/about";
</style>

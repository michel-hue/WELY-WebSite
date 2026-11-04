<template>
  <section class="section how">
    <div class="container">
      <div class="how__head">
        <div v-reveal>
          <p class="eyebrow">Fonctionnement</p>
          <h2 class="title">Trois gestes, <span class="serif">c'est tout.</span></h2>
        </div>
        <RoleToggle v-reveal="120" variant="light" />
      </div>

      <Transition name="fade-swap" mode="out-in">
        <ol :key="role" class="how__steps">
          <li v-for="(step, i) in steps[role]" :key="step.title" class="how__step">
            <span class="how__num serif">0{{ i + 1 }}</span>
            <LineIcon :name="step.icon" :size="38" class="how__icon" />
            <h3>{{ step.title }}</h3>
            <p>{{ step.text }}</p>
          </li>
        </ol>
      </Transition>

      <NuxtLink v-if="showLink" to="/fonctionnement" class="link-arrow how__link">
        Tout savoir sur le fonctionnement <span aria-hidden="true">→</span>
      </NuxtLink>
    </div>
  </section>
</template>

<script setup lang="ts">
import { steps } from '~/utils/content'

withDefaults(defineProps<{ showLink?: boolean }>(), { showLink: true })

const role = useRole()
</script>

<style lang="scss">
@import "../../assets/scss/how";
</style>

<template>
  <div class="role-toggle" :class="`role-toggle--${variant}`" role="group" aria-label="Choisir votre profil">
    <span class="role-toggle__thumb" :class="{ 'is-right': role === 'seller' }" aria-hidden="true"></span>
    <button
      v-for="r in (['buyer', 'seller'] as const)"
      :key="r"
      type="button"
      :aria-pressed="role === r"
      :class="{ 'is-active': role === r }"
      @click="role = r"
    >
      {{ roleCopy[r].label }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { roleCopy } from '~/utils/content'

withDefaults(defineProps<{ variant?: 'glass' | 'light' }>(), { variant: 'light' })

const role = useRole()
</script>

<style lang="scss">
@import "../../assets/scss/role-toggle";
</style>

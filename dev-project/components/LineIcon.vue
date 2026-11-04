<template>
  <svg
    class="line-icon"
    :width="size"
    :height="size"
    viewBox="0 0 32 32"
    fill="none"
    stroke="currentColor"
    stroke-width="1.3"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
    focusable="false"
  >
    <template v-if="name === 'search'">
      <circle cx="14" cy="14" r="8" /><path d="M20 20 L27 27" />
    </template>
    <template v-else-if="name === 'house'">
      <path d="M5 14 L16 5 L27 14 V27 H5 Z" /><path d="M13 27 V19 H19 V27" />
    </template>
    <template v-else-if="name === 'calendar'">
      <rect x="5" y="7" width="22" height="20" rx="2" /><path d="M5 13 H27 M11 4 V9 M21 4 V9 M12 20 L15 23 L21 17" />
    </template>
    <template v-else-if="name === 'switch'">
      <path d="M6 11 H25 L20 6 M26 21 H7 L12 26" />
    </template>
    <template v-else-if="name === 'camera'">
      <rect x="4" y="9" width="24" height="17" rx="2" /><circle cx="16" cy="17.5" r="5" /><path d="M11 9 L13 5 H19 L21 9" />
    </template>
    <template v-else-if="name === 'inbox'">
      <path d="M4 18 L8 6 H24 L28 18 V26 H4 Z" /><path d="M4 18 H11 L13 21 H19 L21 18 H28" />
    </template>
    <template v-else-if="name === 'pin'">
      <path d="M16 28 C16 28 25 19.5 25 13 A9 9 0 0 0 7 13 C7 19.5 16 28 16 28 Z" /><circle cx="16" cy="13" r="3" />
    </template>
    <template v-else-if="name === 'mail'">
      <rect x="4" y="7" width="24" height="18" rx="2" /><path d="M4 9 L16 18 L28 9" />
    </template>
    <template v-else-if="name === 'phone'">
      <rect x="9" y="3" width="14" height="26" rx="3" /><path d="M14 25 H18" />
    </template>
    <template v-else-if="name === 'heart'">
      <path d="M16 26 C16 26 5 19 5 12 A5.5 5.5 0 0 1 16 9.5 A5.5 5.5 0 0 1 27 12 C27 19 16 26 16 26 Z" />
    </template>
    <template v-else-if="name === 'eye'">
      <path d="M3 16 C6 10 10.5 7 16 7 C21.5 7 26 10 29 16 C26 22 21.5 25 16 25 C10.5 25 6 22 3 16 Z" /><circle cx="16" cy="16" r="4" />
    </template>
    <template v-else-if="name === 'leaf'">
      <path d="M6 26 C6 14 13 6 27 5 C26 19 18 26 6 26 Z" /><path d="M6 26 L18 14" />
    </template>
  </svg>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  name: 'search' | 'house' | 'calendar' | 'switch' | 'camera' | 'inbox' | 'pin' | 'mail' | 'phone' | 'heart' | 'eye' | 'leaf'
  size?: number
}>(), { size: 32 })
</script>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  // what failed to load, e.g. "listings"
  what: { type: String, default: 'this page' },
  error: { type: Object, default: null },
  retry: { type: Boolean, default: true },
})
defineEmits(['retry'])

// Network failures (status 0) get the generic hint; API errors show their message
const detail = computed(() =>
  props.error?.status
    ? props.error.message
    : 'Check your connection and try again. If it keeps happening, the server may be down.',
)
</script>

<template>
  <div class="alert alert-danger d-flex flex-wrap gap-3 align-items-start" role="alert">
    <i class="bi bi-exclamation-octagon fs-4" aria-hidden="true"></i>
    <div class="flex-grow-1">
      <strong>We couldn't load {{ what }}.</strong>
      <div>{{ detail }}</div>
    </div>
    <button
      v-if="retry"
      class="btn btn-outline-danger btn-sm"
      type="button"
      @click="$emit('retry')"
    >
      <i class="bi bi-arrow-clockwise" aria-hidden="true"></i>Try again
    </button>
  </div>
</template>

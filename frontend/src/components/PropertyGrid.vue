<script setup>
import PropertyCard from './PropertyCard.vue'
import CardSkeleton from './CardSkeleton.vue'
import ErrorAlert from './ErrorAlert.vue'

// A grid of property cards with loading, error and empty states.
// Put the empty state in the default slot.
defineProps({
  properties: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  error: { type: Object, default: null },
  what: { type: String, default: 'the listings' },
  skeletons: { type: Number, default: 6 },
  cols: { type: String, default: 'row-cols-1 row-cols-sm-2 row-cols-lg-3' },
})
defineEmits(['retry'])
</script>

<template>
  <ErrorAlert v-if="error" :what="what" :error="error" @retry="$emit('retry')" />
  <div v-else-if="loading" class="row g-4" :class="cols" aria-busy="true">
    <div v-for="n in skeletons" :key="n" class="col"><CardSkeleton /></div>
    <span class="visually-hidden" role="status">Loading {{ what }}…</span>
  </div>
  <slot v-else-if="!properties.length"></slot>
  <div v-else class="row g-4" :class="cols">
    <div v-for="property in properties" :key="property.property_id" class="col">
      <PropertyCard :property="property" />
    </div>
  </div>
</template>

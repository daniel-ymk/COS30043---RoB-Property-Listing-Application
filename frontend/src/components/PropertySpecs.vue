<script setup>
import { bedsLabel } from '@/utils/format'

defineProps({
  property: { type: Object, required: true },
})
</script>

<template>
  <ul class="specs">
    <li><i class="bi bi-door-closed" aria-hidden="true"></i>{{ bedsLabel(property.bedrooms) }}</li>
    <li><i class="bi bi-droplet" aria-hidden="true"></i>{{ property.bathrooms }} bath</li>
    <li v-if="property.parking_spaces">
      <i class="bi bi-car-front" aria-hidden="true"></i>{{ property.parking_spaces }} parking
    </li>
    <li>
      <i class="bi bi-arrows-angle-expand" aria-hidden="true"></i>{{ property.floor_area_sqm }} m²
    </li>
  </ul>
</template>

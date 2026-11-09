<script setup>
import { RouterLink } from 'vue-router'
import { imageUrl } from '@/api/client'
import PriceLabel from './PriceLabel.vue'
import PropertySpecs from './PropertySpecs.vue'

// Compact row used in the map page's result list.
defineProps({
  property: { type: Object, required: true },
  active: { type: Boolean, default: false },
})
</script>

<template>
  <RouterLink
    class="mini-card"
    :class="{ active }"
    :to="{ name: 'property-detail', params: { id: property.property_id } }"
  >
    <img v-if="property.cover_image" :src="imageUrl(property.cover_image)" alt="" loading="lazy" />
    <span v-else class="no-photo"><i class="bi bi-image" aria-hidden="true"></i></span>
    <span class="info">
      <PriceLabel :price="property.price" :listing-type="property.listing_type" />
      <span class="name">{{ property.title }}</span>
      <PropertySpecs class="small" :property="property" />
    </span>
  </RouterLink>
</template>

<style scoped>
.mini-card {
  display: flex;
  gap: 0.75rem;
  padding: 0.625rem;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius);
  text-decoration: none;
  color: inherit;
  background: #fff;
}
.mini-card:hover,
.mini-card.active {
  border-color: var(--rob-primary);
  background: var(--rob-surface);
}
img,
.no-photo {
  width: 96px;
  height: 72px;
  object-fit: cover;
  border-radius: 6px;
  flex-shrink: 0;
}
.no-photo {
  display: grid;
  place-items: center;
  background: var(--rob-surface);
  color: #94a3b8;
}
.info {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}
.name {
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>

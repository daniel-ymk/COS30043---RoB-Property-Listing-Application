<script setup>
import { computed } from 'vue'
import { RouterLink } from 'vue-router'
import { imageUrl } from '@/api/client'
import { typeLabel } from '@/utils/format'
import LikeButton from './LikeButton.vue'
import CompareToggle from './CompareToggle.vue'
import PriceLabel from './PriceLabel.vue'
import PropertySpecs from './PropertySpecs.vue'
import { useLikesStore } from '@/stores/likes'

// Property card object from docs/api.md section 2.
const props = defineProps({
  property: { type: Object, required: true },
  // Listing form preview: no links or buttons, cover may be a local file
  preview: { type: Boolean, default: false },
  coverUrl: { type: String, default: '' },
})

const likes = useLikesStore()

const unavailable = computed(() => props.property.status !== 'available')
const cover = computed(() => props.coverUrl || imageUrl(props.property.cover_image))
</script>

<template>
  <article class="prop-card" :class="{ 'is-unavailable': unavailable }">
    <div class="media">
      <img v-if="cover" :src="cover" alt="" loading="lazy" width="400" height="300" />
      <div v-else class="no-photo"><i class="bi bi-image" aria-hidden="true"></i></div>
      <span
        class="badge-listing"
        :class="property.listing_type === 'sale' ? 'badge-sale' : 'badge-rent'"
      >
        For {{ property.listing_type }}
      </span>
      <div v-if="unavailable" class="status-flag">{{ property.status }}</div>
    </div>
    <LikeButton v-if="!preview" class="card-like" :property="property" />
    <div class="body">
      <PriceLabel
        v-if="property.price > 0"
        class="card-price"
        :price="property.price"
        :listing-type="property.listing_type"
      />
      <span v-else class="card-price text-muted">Add a price</span>
      <span v-if="preview" class="title">{{ property.title }}</span>
      <RouterLink
        v-else
        class="title"
        :to="{ name: 'property-detail', params: { id: property.property_id } }"
      >
        {{ property.title }}
      </RouterLink>
      <div class="loc">
        <i class="bi bi-geo-alt" aria-hidden="true"></i>
        {{ property.city }} · {{ typeLabel(property.property_type)
        }}<template v-if="property.is_furnished"> · Furnished</template>
      </div>
      <PropertySpecs :property="property" />
      <div class="footer-row">
        <CompareToggle v-if="!preview" :property-id="property.property_id" />
        <span v-else class="text-muted small">Preview</span>
        <span class="text-muted small">
          <i class="bi bi-heart-fill text-danger" aria-hidden="true"></i>
          {{ likes.likeCount(property) }}
          <span class="visually-hidden">likes</span>
        </span>
      </div>
    </div>
  </article>
</template>

<style scoped>
.prop-card {
  position: relative;
  background: #fff;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius-lg);
  overflow: hidden;
  height: 100%;
  display: flex;
  flex-direction: column;
  transition:
    box-shadow 0.2s var(--rob-ease),
    transform 0.2s var(--rob-ease);
}
.prop-card:hover {
  box-shadow: var(--rob-shadow-hover);
  transform: translateY(-2px);
}
.media {
  position: relative;
  aspect-ratio: 4 / 3;
  overflow: hidden;
  background: var(--rob-surface);
}
.media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s var(--rob-ease);
}
.prop-card:hover .media img {
  transform: scale(1.03);
}
.no-photo {
  height: 100%;
  display: grid;
  place-items: center;
  font-size: 2.5rem;
  color: #94a3b8;
}
.media .badge-listing {
  position: absolute;
  top: 12px;
  left: 12px;
}
.card-like {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 2;
}
.body {
  padding: 1rem 1.125rem 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  flex: 1;
}
.card-price {
  font-size: 1.25rem;
}
.title {
  font-weight: 600;
  font-size: 1.0625rem;
  color: var(--rob-ink);
  text-decoration: none;
  line-height: 1.35;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
/* the whole card is the link; like and compare sit above it */
.title::after {
  content: '';
  position: absolute;
  inset: 0;
}
.title:focus-visible {
  outline: none;
}
.prop-card:has(.title:focus-visible) {
  outline: 3px solid var(--rob-primary);
  outline-offset: 2px;
}
.loc {
  color: var(--rob-muted);
  font-size: 0.9375rem;
}
.footer-row {
  margin-top: auto;
  padding-top: 0.25rem;
  border-top: 1px solid var(--rob-line);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}
.is-unavailable .media img {
  filter: grayscale(0.7);
}
.status-flag {
  position: absolute;
  inset: auto 0 0 0;
  background: rgb(15 23 42 / 0.75);
  color: #fff;
  text-align: center;
  font-weight: 700;
  padding: 0.4rem;
  letter-spacing: 0.06em;
  font-size: 0.8125rem;
  text-transform: uppercase;
}
@media (prefers-reduced-motion: reduce) {
  .prop-card,
  .media img {
    transition: none;
  }
  .prop-card:hover {
    transform: none;
  }
  .prop-card:hover .media img {
    transform: none;
  }
}
</style>

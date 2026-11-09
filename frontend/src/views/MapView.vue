<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { searchMap } from '@/api/properties'
import { useAsync } from '@/composables/useAsync'
import LeafletMap from '@/components/LeafletMap.vue'
import MiniCard from '@/components/MiniCard.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const KL_CENTER = [3.139, 101.6869]

const router = useRouter()
const result = useAsync(searchMap)

const listingType = ref('')
const moved = ref(false) // show "Search this area" after the user pans or zooms
const hoverId = ref(null)
let lastBounds = null

const shown = computed(() =>
  (result.data.value ?? []).filter(
    (p) => !listingType.value || p.listing_type === listingType.value,
  ),
)
const countText = computed(() => {
  if (result.loading.value) return 'Searching this area…'
  if (!result.data.value) return ''
  const n = shown.value.length
  return n === 1 ? '1 home in this area' : `${n} homes in this area`
})

function search(bounds) {
  lastBounds = bounds
  moved.value = false
  result.run(bounds)
}

function onMoved(bounds) {
  lastBounds = bounds
  moved.value = true
}

function openListing(id) {
  router.push({ name: 'property-detail', params: { id } })
}
</script>

<template>
  <div class="map-layout">
    <section class="results" aria-labelledby="map-title">
      <h1 id="map-title" class="h4 mb-1">Map search</h1>
      <p class="text-muted small mb-3" aria-live="polite">{{ countText }}</p>
      <div class="segmented w-100 mb-3" role="radiogroup" aria-label="Listing type">
        <template
          v-for="option in [
            { value: '', label: 'All' },
            { value: 'rent', label: 'Rent' },
            { value: 'sale', label: 'Buy' },
          ]"
          :key="option.value"
        >
          <input
            :id="`m-${option.value || 'all'}`"
            v-model="listingType"
            type="radio"
            class="btn-check"
            name="m-listing-type"
            :value="option.value"
          />
          <label class="btn" :for="`m-${option.value || 'all'}`">{{ option.label }}</label>
        </template>
      </div>

      <ErrorAlert
        v-if="result.error.value"
        what="map results"
        :error="result.error.value"
        @retry="search(lastBounds)"
      />
      <div v-else-if="result.loading.value" aria-hidden="true">
        <div v-for="n in 4" :key="n" class="mini-skeleton">
          <div class="skeleton" style="width: 96px; height: 72px"></div>
          <div class="flex-grow-1">
            <div class="skeleton mb-2" style="height: 18px; width: 50%"></div>
            <div class="skeleton" style="height: 16px"></div>
          </div>
        </div>
      </div>
      <EmptyState
        v-else-if="result.data.value && !shown.length"
        icon="map"
        title="No homes in this area"
        text='Zoom out or move the map, then press "Search this area".'
      />
      <ul v-else class="list-unstyled d-flex flex-column gap-2 mb-0">
        <li
          v-for="p in shown"
          :key="p.property_id"
          @mouseenter="hoverId = p.property_id"
          @mouseleave="hoverId = null"
          @focusin="hoverId = p.property_id"
          @focusout="hoverId = null"
        >
          <MiniCard :property="p" :active="hoverId === p.property_id" />
        </li>
      </ul>
    </section>

    <div class="map-pane">
      <button
        v-if="moved"
        class="btn btn-light map-search-btn"
        type="button"
        @click="search(lastBounds)"
      >
        <i class="bi bi-arrow-repeat" aria-hidden="true"></i>Search this area
      </button>
      <LeafletMap
        :center="KL_CENTER"
        :zoom="12"
        :properties="shown"
        :highlight-id="hoverId"
        label="Map of listings"
        @ready="search"
        @moved="onMoved"
        @hover="hoverId = $event"
        @select="openListing"
      />
    </div>
  </div>
</template>

<style scoped>
/* phones and tablets: map on top, list below */
.map-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr); /* let long titles shrink, not widen the page */
}
.map-pane {
  position: relative;
  height: 55vh;
  order: -1;
}
.results {
  padding: 1rem;
}
.map-search-btn {
  position: absolute;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 500;
  box-shadow: var(--rob-shadow-hover);
}
.mini-skeleton {
  display: flex;
  gap: 0.75rem;
  padding: 0.625rem;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius);
  margin-bottom: 0.5rem;
}
@media (min-width: 992px) {
  .map-layout {
    grid-template-columns: 400px minmax(0, 1fr);
    height: calc(100vh - var(--rob-nav-height));
  }
  .map-pane {
    height: auto;
    order: 0;
  }
  .results {
    overflow-y: auto;
    border-right: 1px solid var(--rob-line);
  }
}
</style>

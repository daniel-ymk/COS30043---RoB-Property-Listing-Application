<script setup>
import { computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { compareProperties } from '@/api/properties'
import { imageUrl } from '@/api/client'
import { useAsync } from '@/composables/useAsync'
import { useCompareStore, COMPARE_MAX } from '@/stores/compare'
import { money, typeLabel } from '@/utils/format'
import PriceLabel from '@/components/PriceLabel.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const compare = useCompareStore()

const result = useAsync(() => compareProperties(compare.ids))

// Keep the store's order, and follow removals without another request
const items = computed(() => {
  const byId = new Map((result.data.value ?? []).map((p) => [p.property_id, p]))
  return compare.ids.map((id) => byId.get(id)).filter(Boolean)
})
const freeSlots = computed(() => COMPARE_MAX - items.value.length)

// Rent and sale prices can't be ranked against each other
const sameType = computed(() =>
  items.value.every((p) => p.listing_type === items.value[0]?.listing_type),
)
const ranked = computed(() => items.value.length > 1)

const perSqm = (p) => (p.floor_area_sqm ? Math.round(p.price / p.floor_area_sqm) : null)

// Highest (or lowest) value of a column, for the green "best" mark
function best(values, lowest = false) {
  const numbers = values.filter((v) => v !== null && v !== undefined)
  if (!numbers.length) return null
  return lowest ? Math.min(...numbers) : Math.max(...numbers)
}
const bests = computed(() => ({
  price: best(
    items.value.map((p) => p.price),
    true,
  ),
  perSqm: best(items.value.map(perSqm), true),
  bedrooms: best(items.value.map((p) => p.bedrooms)),
  bathrooms: best(items.value.map((p) => p.bathrooms)),
  parking_spaces: best(items.value.map((p) => p.parking_spaces)),
  floor_area_sqm: best(items.value.map((p) => p.floor_area_sqm)),
}))
const isBest = (key, value, needsSameType = false) =>
  ranked.value && (!needsSameType || sameType.value) && value !== null && value === bests.value[key]

const numberRows = [
  { key: 'bedrooms', label: 'Bedrooms' },
  { key: 'bathrooms', label: 'Bathrooms' },
  { key: 'parking_spaces', label: 'Parking' },
  { key: 'floor_area_sqm', label: 'Floor area (m²)' },
]

async function load() {
  if (!compare.ids.length) return
  await result.run()
  // Listings deleted since they were ticked drop out of the store
  if (result.data.value) {
    const found = new Set(result.data.value.map((p) => p.property_id))
    compare.ids.filter((id) => !found.has(id)).forEach(compare.remove)
  }
}

onMounted(load)
</script>

<template>
  <div class="container">
    <div class="page-head d-flex flex-wrap justify-content-between align-items-end gap-3">
      <div>
        <h1 class="h2 mb-1">Compare homes</h1>
        <p class="text-muted mb-0">
          Up to {{ COMPARE_MAX }} listings side by side. The best value in each row is marked
          <span class="best-word">green</span>.
        </p>
      </div>
      <button
        v-if="compare.count"
        class="btn btn-outline-secondary"
        type="button"
        @click="compare.clear()"
      >
        <i class="bi bi-x-circle" aria-hidden="true"></i>Clear all
      </button>
    </div>

    <EmptyState
      v-if="!compare.count"
      icon="layout-three-columns"
      title="Nothing to compare yet"
      text='Tick "Compare" on up to 4 listings, then come back here to see them side by side.'
    >
      <RouterLink class="btn btn-primary" :to="{ name: 'properties' }"
        >Browse properties</RouterLink
      >
    </EmptyState>

    <ErrorAlert
      v-else-if="result.error.value"
      what="the listings to compare"
      :error="result.error.value"
      @retry="load"
    />

    <div
      v-else-if="result.loading.value || !result.data.value"
      class="skeleton compare-skeleton"
      aria-busy="true"
    >
      <span class="visually-hidden" role="status">Loading listings…</span>
    </div>

    <template v-else>
      <div v-if="ranked && !sameType" class="alert alert-info d-flex gap-2 small">
        <i class="bi bi-info-circle" aria-hidden="true"></i>
        You are comparing rent and sale listings, so prices are not ranked. Compare listings of one
        type to see the best price.
      </div>

      <div class="table-responsive border rounded-3">
        <table
          class="table compare-table mb-0"
          :style="{ minWidth: `${180 + items.length * 220}px` }"
        >
          <caption class="visually-hidden">
            Comparison of
            {{
              items.length
            }}
            listings
          </caption>
          <thead>
            <tr>
              <td class="corner"></td>
              <th v-for="p in items" :key="p.property_id" scope="col" class="head-cell">
                <div class="position-relative mb-2">
                  <img v-if="p.cover_image" :src="imageUrl(p.cover_image)" alt="" />
                  <div v-else class="no-photo"><i class="bi bi-image" aria-hidden="true"></i></div>
                  <button
                    class="btn btn-light btn-sm remove"
                    type="button"
                    :aria-label="`Remove ${p.title} from compare`"
                    @click="compare.remove(p.property_id)"
                  >
                    <i class="bi bi-x-lg" aria-hidden="true"></i>
                  </button>
                </div>
                <div class="d-flex flex-wrap gap-1">
                  <span
                    class="badge-listing"
                    :class="p.listing_type === 'sale' ? 'badge-sale' : 'badge-rent'"
                  >
                    For {{ p.listing_type }}
                  </span>
                  <StatusBadge v-if="p.status !== 'available'" :status="p.status" />
                </div>
                <RouterLink
                  class="d-block fw-semibold text-body text-decoration-none mt-2"
                  :to="{ name: 'property-detail', params: { id: p.property_id } }"
                >
                  {{ p.title }}
                </RouterLink>
              </th>
              <td v-if="freeSlots" class="align-middle text-center add-cell">
                <RouterLink class="add-home" :to="{ name: 'properties' }">
                  <i class="bi bi-plus-circle fs-3 text-primary" aria-hidden="true"></i>
                  <span class="fw-semibold mt-2">Add a home</span>
                  <span class="small text-muted"
                    >{{ freeSlots }} {{ freeSlots === 1 ? 'slot' : 'slots' }} left</span
                  >
                </RouterLink>
              </td>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th scope="row">Price</th>
              <td
                v-for="p in items"
                :key="p.property_id"
                :class="{ best: isBest('price', p.price, true) }"
              >
                <PriceLabel :price="p.price" :listing-type="p.listing_type" />
              </td>
              <td v-if="freeSlots"></td>
            </tr>
            <tr>
              <th scope="row">Price per m²</th>
              <td
                v-for="p in items"
                :key="p.property_id"
                :class="{ best: isBest('perSqm', perSqm(p), true) }"
              >
                <template v-if="perSqm(p)">
                  {{ money(perSqm(p)) }}<span v-if="p.listing_type === 'rent'"> /month</span>
                </template>
                <span v-else class="text-muted">–</span>
              </td>
              <td v-if="freeSlots"></td>
            </tr>
            <tr>
              <th scope="row">Location</th>
              <td v-for="p in items" :key="p.property_id">
                {{ p.address }}<br /><span class="text-muted">{{ p.city }}</span>
              </td>
              <td v-if="freeSlots"></td>
            </tr>
            <tr>
              <th scope="row">Type</th>
              <td v-for="p in items" :key="p.property_id">{{ typeLabel(p.property_type) }}</td>
              <td v-if="freeSlots"></td>
            </tr>
            <tr v-for="row in numberRows" :key="row.key">
              <th scope="row">{{ row.label }}</th>
              <td
                v-for="p in items"
                :key="p.property_id"
                :class="{ best: isBest(row.key, p[row.key]) }"
              >
                {{ p[row.key] ?? '–' }}
              </td>
              <td v-if="freeSlots"></td>
            </tr>
            <tr>
              <th scope="row">Furnished</th>
              <td v-for="p in items" :key="p.property_id">
                <template v-if="p.is_furnished">
                  <i class="bi bi-check-lg text-success" aria-hidden="true"></i> Yes
                </template>
                <span v-else class="text-muted">No</span>
              </td>
              <td v-if="freeSlots"></td>
            </tr>
            <tr>
              <th scope="row">Saved by</th>
              <td v-for="p in items" :key="p.property_id">
                {{ p.like_count }} {{ p.like_count === 1 ? 'person' : 'people' }}
              </td>
              <td v-if="freeSlots"></td>
            </tr>
            <tr>
              <th scope="row"><span class="visually-hidden">Open listing</span></th>
              <td v-for="p in items" :key="p.property_id">
                <RouterLink
                  class="btn btn-primary w-100"
                  :to="{ name: 'property-detail', params: { id: p.property_id } }"
                >
                  View listing<span class="visually-hidden">: {{ p.title }}</span>
                </RouterLink>
              </td>
              <td v-if="freeSlots"></td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>

<style scoped>
.compare-skeleton {
  height: 420px;
}
.compare-table th[scope='row'] {
  color: var(--rob-muted);
  font-weight: 600;
  width: 150px;
  background: var(--rob-surface);
  position: sticky;
  left: 0;
  z-index: 1;
}
.compare-table td,
.compare-table th {
  padding: 0.875rem 1rem;
  vertical-align: top;
}
.corner {
  background: var(--rob-surface);
  position: sticky;
  left: 0;
  z-index: 1;
}
.head-cell {
  font-weight: 400;
}
.compare-table img,
.no-photo {
  width: 100%;
  aspect-ratio: 4 / 3;
  object-fit: cover;
  border-radius: var(--rob-radius);
}
.no-photo {
  display: grid;
  place-items: center;
  background: var(--rob-surface);
  color: #94a3b8;
  font-size: 2rem;
}
.remove {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  width: 36px;
  min-height: 36px;
  padding: 0;
}
.compare-table .best {
  color: var(--rob-success);
  font-weight: 700;
}
.compare-table .best :deep(.price) {
  color: var(--rob-success);
}
/* mark "best" with an icon too, not only colour */
.compare-table td.best::after {
  content: '\F26B'; /* bi-check-circle-fill */
  font-family: bootstrap-icons;
  margin-left: 0.35rem;
  font-weight: 400;
}
.best-word {
  color: var(--rob-success);
  font-weight: 700;
}
.add-cell {
  width: 200px;
}
.add-home {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1.5rem 1rem;
  border: 1px dashed #cbd5e1;
  border-radius: var(--rob-radius-lg);
  background: var(--rob-surface);
  text-decoration: none;
}
</style>

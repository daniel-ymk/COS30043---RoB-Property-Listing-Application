<script setup>
import { computed, watch, onMounted } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { listProperties, listCities } from '@/api/properties'
import { useAsync } from '@/composables/useAsync'
import {
  filtersFromQuery,
  filtersToQuery,
  filterChips,
  emptyFilters,
  SORT_OPTIONS,
} from '@/utils/filters'
import FilterPanel from '@/components/FilterPanel.vue'
import PropertyGrid from '@/components/PropertyGrid.vue'
import EmptyState from '@/components/EmptyState.vue'
import AppPagination from '@/components/AppPagination.vue'

const PER_PAGE = 12

const route = useRoute()
const router = useRouter()

// The URL is the single source of truth for filters, sort and page
const filters = computed(() => filtersFromQuery(route.query))
const sort = computed(() =>
  SORT_OPTIONS.some((o) => o.value === route.query.sort) ? route.query.sort : 'newest',
)
const page = computed(() => Math.max(1, Number.parseInt(route.query.page, 10) || 1))
const chips = computed(() => filterChips(filters.value))

const results = useAsync(() =>
  listProperties({
    ...filtersToQuery(filters.value),
    sort: sort.value,
    page: page.value,
    per_page: PER_PAGE,
  }),
)
const cities = useAsync(listCities)

const heading = computed(() => {
  const what = { rent: 'Homes for rent', sale: 'Homes for sale' }[filters.value.listing_type]
  const where = filters.value.city ? ` in ${filters.value.city}` : ''
  return (what ?? 'Homes for rent and sale') + where
})
const countText = computed(() => {
  const total = results.meta.value?.total
  if (total === undefined) return ''
  return total === 1 ? '1 home found' : `${total} homes found`
})

// New filters start again from page 1; sort is kept
function applyFilters(next) {
  const query = filtersToQuery(next)
  if (sort.value !== 'newest') query.sort = sort.value
  router.push({ query })
}

function changeSort(event) {
  const query = { ...route.query, sort: event.target.value }
  if (query.sort === 'newest') delete query.sort
  delete query.page
  router.push({ query })
}

// Only while this page is shown (not on the way out to a listing)
watch(
  () => route.query,
  () => route.name === 'properties' && results.run(),
)
onMounted(() => {
  results.run()
  cities.run()
})
</script>

<template>
  <div class="container">
    <div class="page-head">
      <nav aria-label="breadcrumb">
        <ol class="breadcrumb small mb-2">
          <li class="breadcrumb-item"><RouterLink :to="{ name: 'home' }">Home</RouterLink></li>
          <li class="breadcrumb-item active" aria-current="page">Properties</li>
        </ol>
      </nav>
      <h1 class="h2 mb-1">{{ heading }}</h1>
      <p class="text-muted mb-0" aria-live="polite">
        {{ results.loading.value ? 'Searching…' : countText }}
      </p>
    </div>

    <div class="row g-4">
      <aside class="col-lg-3">
        <FilterPanel
          :filters="filters"
          :cities="cities.data.value ?? []"
          :active-count="chips.length"
          @apply="applyFilters"
        />
      </aside>

      <section class="col-lg-9" aria-label="Results">
        <div class="toolbar mb-3">
          <ul v-if="chips.length" class="chip-list list-unstyled mb-0" aria-label="Active filters">
            <li v-for="chip in chips" :key="chip.key">
              <button class="chip" type="button" @click="applyFilters(chip.without)">
                {{ chip.label }} <i class="bi bi-x" aria-hidden="true"></i>
                <span class="visually-hidden">(remove filter)</span>
              </button>
            </li>
          </ul>
          <div class="d-flex align-items-center gap-2 ms-auto">
            <label class="text-muted text-nowrap" for="sort">Sort by</label>
            <select id="sort" class="form-select w-auto" :value="sort" @change="changeSort">
              <option v-for="option in SORT_OPTIONS" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
            <RouterLink class="btn btn-outline-secondary" :to="{ name: 'map' }">
              <i class="bi bi-map" aria-hidden="true"></i
              ><span class="d-none d-md-inline">Map</span>
              <span class="visually-hidden d-md-none">Show on map</span>
            </RouterLink>
          </div>
        </div>

        <PropertyGrid
          :properties="results.data.value ?? []"
          :loading="results.loading.value"
          :error="results.error.value"
          cols="row-cols-1 row-cols-sm-2 row-cols-xl-3"
          @retry="results.run"
        >
          <EmptyState
            icon="search"
            title="No homes match these filters"
            text="Try a wider price range, another city, or fewer property types."
          >
            <button
              v-if="chips.length"
              class="btn btn-primary"
              type="button"
              @click="applyFilters(emptyFilters())"
            >
              Clear all filters
            </button>
          </EmptyState>
        </PropertyGrid>

        <AppPagination
          v-if="results.meta.value && !results.loading.value && !results.error.value"
          class="mt-5"
          :meta="results.meta.value"
          label="home"
        />
      </section>
    </div>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem 1rem;
  justify-content: space-between;
  align-items: center;
}
</style>

<script setup>
import { ref, reactive, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { Offcanvas } from 'bootstrap'
import { TYPE_LABELS } from '@/utils/format'
import { emptyFilters, PROPERTY_TYPES } from '@/utils/filters'

// Listing filters: a sidebar on desktop, a slide-in panel on phones and
// tablets. Edits stay local until "Show results" emits them.
const props = defineProps({
  filters: { type: Object, required: true },
  cities: { type: Array, default: () => [] },
  activeCount: { type: Number, default: 0 },
})
const emit = defineEmits(['apply'])

const draft = reactive(emptyFilters())
const panel = ref(null)
let offcanvas = null

// Reload the form whenever the URL's filters change (chips, back button)
watch(
  () => props.filters,
  (filters) => Object.assign(draft, { ...filters, property_type: [...filters.property_type] }),
  { immediate: true },
)

const priceError = computed(() =>
  draft.min_price !== '' &&
  draft.max_price !== '' &&
  Number(draft.min_price) > Number(draft.max_price)
    ? 'Maximum price must be higher than the minimum'
    : '',
)

onMounted(() => (offcanvas = Offcanvas.getOrCreateInstance(panel.value)))
onBeforeUnmount(() => offcanvas?.dispose())

// Keep only digits so "RM 3,000" still works
function cleanPrice(key) {
  draft[key] = String(draft[key]).replace(/\D/g, '')
}

function apply() {
  if (priceError.value) return
  emit('apply', { ...draft, property_type: [...draft.property_type] })
  offcanvas?.hide()
}

function clearAll() {
  Object.assign(draft, emptyFilters())
  apply()
}
</script>

<template>
  <div>
    <button
      class="btn btn-outline-secondary w-100 d-lg-none"
      type="button"
      aria-controls="filters"
      @click="offcanvas.show()"
    >
      <i class="bi bi-sliders" aria-hidden="true"></i>Filters
      <span v-if="activeCount" class="badge rounded-pill text-bg-primary">
        {{ activeCount }}<span class="visually-hidden"> active</span>
      </span>
    </button>

    <div
      id="filters"
      ref="panel"
      class="offcanvas-lg offcanvas-start"
      tabindex="-1"
      aria-labelledby="filters-title"
    >
      <div class="offcanvas-header">
        <h2 id="filters-title" class="offcanvas-title h5">Filters</h2>
        <button
          type="button"
          class="btn-close"
          aria-label="Close"
          @click="offcanvas.hide()"
        ></button>
      </div>
      <div class="offcanvas-body">
        <form
          class="panel-surface w-100 d-grid gap-3"
          aria-label="Filter listings"
          novalidate
          @submit.prevent="apply"
        >
          <div>
            <span id="f-type-label" class="form-label d-block">Looking to</span>
            <div class="segmented w-100" role="radiogroup" aria-labelledby="f-type-label">
              <template
                v-for="option in [
                  { value: '', label: 'Any' },
                  { value: 'rent', label: 'Rent' },
                  { value: 'sale', label: 'Buy' },
                ]"
                :key="option.value"
              >
                <input
                  :id="`f-lt-${option.value || 'any'}`"
                  v-model="draft.listing_type"
                  type="radio"
                  class="btn-check"
                  name="f-listing-type"
                  :value="option.value"
                />
                <label class="btn" :for="`f-lt-${option.value || 'any'}`">{{ option.label }}</label>
              </template>
            </div>
          </div>

          <div>
            <label class="form-label" for="f-q">Keyword</label>
            <input
              id="f-q"
              v-model="draft.q"
              class="form-control"
              type="search"
              placeholder="Area, street or title"
            />
          </div>

          <div>
            <label class="form-label" for="f-city">City</label>
            <select id="f-city" v-model="draft.city" class="form-select">
              <option value="">Any city</option>
              <option v-for="c in cities" :key="c.city" :value="c.city">
                {{ c.city }} ({{ c.listing_count }})
              </option>
              <!-- a city from an old link that has no listings now -->
              <option
                v-if="draft.city && !cities.some((c) => c.city === draft.city)"
                :value="draft.city"
              >
                {{ draft.city }}
              </option>
            </select>
          </div>

          <fieldset>
            <legend class="form-label fs-6">Property type</legend>
            <div class="row row-cols-2 g-1">
              <div v-for="type in PROPERTY_TYPES" :key="type" class="col">
                <div class="form-check">
                  <input
                    :id="`f-pt-${type}`"
                    v-model="draft.property_type"
                    class="form-check-input"
                    type="checkbox"
                    :value="type"
                  />
                  <label class="form-check-label" :for="`f-pt-${type}`">{{
                    TYPE_LABELS[type]
                  }}</label>
                </div>
              </div>
            </div>
          </fieldset>

          <fieldset>
            <legend class="form-label fs-6">Price (RM)</legend>
            <div class="row g-2">
              <div class="col">
                <label class="visually-hidden" for="f-min">Minimum price</label>
                <input
                  id="f-min"
                  v-model="draft.min_price"
                  class="form-control"
                  :class="{ 'is-invalid': priceError }"
                  inputmode="numeric"
                  placeholder="Min"
                  @input="cleanPrice('min_price')"
                />
              </div>
              <div class="col">
                <label class="visually-hidden" for="f-max">Maximum price</label>
                <input
                  id="f-max"
                  v-model="draft.max_price"
                  class="form-control"
                  :class="{ 'is-invalid': priceError }"
                  inputmode="numeric"
                  placeholder="Max"
                  :aria-describedby="priceError ? 'f-price-error' : undefined"
                  :aria-invalid="priceError ? 'true' : 'false'"
                  @input="cleanPrice('max_price')"
                />
              </div>
            </div>
            <div v-if="priceError" id="f-price-error" class="invalid-feedback d-block">
              {{ priceError }}
            </div>
          </fieldset>

          <fieldset>
            <legend class="form-label fs-6">Bedrooms</legend>
            <div class="btn-group w-100" role="group" aria-label="Bedrooms">
              <template v-for="beds in ['', '1', '2', '3']" :key="beds">
                <input
                  :id="`f-beds-${beds || 'any'}`"
                  v-model="draft.min_bedrooms"
                  type="radio"
                  class="btn-check"
                  name="f-beds"
                  :value="beds"
                />
                <label class="btn btn-outline-secondary" :for="`f-beds-${beds || 'any'}`">
                  {{ beds ? `${beds}+` : 'Any' }}
                </label>
              </template>
            </div>
          </fieldset>

          <div class="form-check form-switch">
            <input
              id="f-furn"
              v-model="draft.furnished"
              class="form-check-input"
              type="checkbox"
              role="switch"
            />
            <label class="form-check-label" for="f-furn">Furnished only</label>
          </div>

          <div class="d-grid gap-2">
            <button class="btn btn-primary" type="submit">Show results</button>
            <button class="btn btn-link" type="button" @click="clearAll">Clear all filters</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<style scoped>
.btn-group .btn-check:checked + .btn {
  background: var(--rob-primary);
  border-color: var(--rob-primary);
  color: #fff;
}
@media (min-width: 992px) {
  .offcanvas-header {
    display: none;
  }
  .offcanvas-body {
    padding: 0;
  }
}
</style>

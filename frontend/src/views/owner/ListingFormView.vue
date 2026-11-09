<script setup>
import { ref, computed, watch, nextTick, onMounted } from 'vue'
import { RouterLink, useRouter, onBeforeRouteLeave } from 'vue-router'
import { getProperty, createProperty, replaceProperty, listCities } from '@/api/properties'
import { imageUrl } from '@/api/client'
import { useAsync } from '@/composables/useAsync'
import { useForm } from '@/composables/useForm'
import { useToastStore } from '@/stores/toast'
import { useConfirmStore } from '@/stores/confirm'
import { listingRules } from '@/utils/validation'
import { TYPE_LABELS, MALAYSIAN_STATES, STATUS_LABELS } from '@/utils/format'
import FormField from '@/components/FormField.vue'
import ErrorSummary from '@/components/ErrorSummary.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'
import PropertyCard from '@/components/PropertyCard.vue'
import PhotoManager from '@/components/PhotoManager.vue'
import LeafletMap from '@/components/LeafletMap.vue'

// Create (/owner/listings/new) and edit (/owner/listings/:id/edit)
const props = defineProps({
  id: { type: Number, default: null },
})

const KL_CENTER = [3.139, 101.6869]
const BLANK = {
  title: '',
  description: '',
  listing_type: 'rent',
  property_type: 'condo',
  price: '',
  bedrooms: '1',
  bathrooms: '1',
  parking_spaces: '0',
  floor_area_sqm: '',
  is_furnished: false,
  address: '',
  city: '',
  state: '',
  postcode: '',
  status: 'available',
}

const router = useRouter()
const toast = useToastStore()
const confirm = useConfirmStore()

const isEdit = computed(() => props.id !== null)
const form = useForm(BLANK, listingRules)
const pin = ref(null) // [lat, lng] or null
const photos = ref([])
const savedImages = ref([]) // photos on the server, to see what changed
const photoManager = ref(null)
const photoError = ref('')
// A new listing whose photos partly failed becomes an edit page in place;
// this skips the reload so the failed files stay on screen for a retry
let keepStateFor = null
const sending = ref(false)
const failure = ref('')
const summary = ref(null)

const existing = useAsync(() => getProperty(props.id))
const cities = useAsync(listCities)
const notMine = computed(() => existing.data.value && !existing.data.value.is_mine)

// What a save would send; compared with the last save to spot unsaved edits
const snapshot = () =>
  JSON.stringify([
    form.values,
    pin.value,
    photos.value.map((p) => [p.key, p.caption, p.room_tag, p.is_hidden]),
  ])
let savedSnapshot = snapshot()
let leavingOnPurpose = false

const previewProperty = computed(() => ({
  property_id: 0,
  title: form.values.title.trim() || 'Your listing title',
  listing_type: form.values.listing_type,
  property_type: form.values.property_type,
  price: Number(form.values.price) || 0,
  bedrooms: Number(form.values.bedrooms) || 0,
  bathrooms: Number(form.values.bathrooms) || 0,
  parking_spaces: Number(form.values.parking_spaces) || 0,
  floor_area_sqm: Number(form.values.floor_area_sqm) || '–',
  is_furnished: form.values.is_furnished,
  city: form.values.city.trim() || 'City',
  status: form.values.status,
  cover_image: null,
  like_count: existing.data.value?.like_count ?? 0,
  liked_by_me: false,
  is_mine: true,
}))

function fillFrom(p) {
  form.reset({
    title: p.title,
    description: p.description,
    listing_type: p.listing_type,
    property_type: p.property_type,
    price: String(p.price),
    bedrooms: String(p.bedrooms),
    bathrooms: String(p.bathrooms),
    parking_spaces: String(p.parking_spaces),
    floor_area_sqm: p.floor_area_sqm === null ? '' : String(p.floor_area_sqm),
    is_furnished: p.is_furnished,
    address: p.address,
    city: p.city,
    state: p.state ?? '',
    postcode: p.postcode ?? '',
    status: p.status,
  })
  pin.value = p.latitude === null ? null : [p.latitude, p.longitude]
  photos.value = p.images.map((img) => ({
    key: `img-${img.image_id}`,
    image_id: img.image_id,
    url: imageUrl(img.file_path),
    caption: img.caption ?? '',
    room_tag: img.room_tag,
    is_hidden: img.is_hidden,
  }))
  savedImages.value = p.images
  savedSnapshot = snapshot()
}

function body() {
  const v = form.values
  const listing = {
    title: v.title.trim(),
    description: v.description.trim(),
    listing_type: v.listing_type,
    property_type: v.property_type,
    price: Number(v.price),
    bedrooms: Number(v.bedrooms),
    bathrooms: Number(v.bathrooms),
    parking_spaces: Number(v.parking_spaces),
    floor_area_sqm: v.floor_area_sqm === '' ? null : Number(v.floor_area_sqm),
    is_furnished: v.is_furnished,
    address: v.address.trim(),
    city: v.city.trim(),
    state: v.state || null,
    postcode: v.postcode.trim() || null,
    latitude: pin.value?.[0] ?? null,
    longitude: pin.value?.[1] ?? null,
  }
  if (isEdit.value) listing.status = v.status
  return listing
}

// What the server now holds, after a (partly) successful photo save
function photosOnServer() {
  return photos.value
    .filter((p) => p.image_id)
    .map((p) => ({
      image_id: p.image_id,
      caption: p.caption.trim() || null,
      room_tag: p.room_tag || null,
      is_hidden: p.is_hidden,
    }))
}

async function showErrors() {
  await nextTick()
  summary.value?.focus()
}

async function submit() {
  failure.value = ''
  photoError.value = ''
  if (!form.validateAll()) return showErrors()

  sending.value = true
  let saved
  try {
    saved = isEdit.value ? await replaceProperty(props.id, body()) : await createProperty(body())
  } catch (err) {
    sending.value = false
    if (err.status === 422) {
      form.setServerErrors(err.fields)
      return showErrors()
    }
    failure.value = err.message
    return
  }

  // The listing is saved; now the photos (PhotoManager does each step).
  // failed: photos that didn't upload, or -1 when another step went wrong
  let failed
  try {
    failed = (await photoManager.value.sync(saved.property_id, savedImages.value)).failed
  } catch (err) {
    failed = -1
    photoError.value = `Photos not fully saved: ${err.message}`
  }
  if (failed !== 0) {
    sending.value = false
    savedImages.value = photosOnServer()
    if (!isEdit.value) {
      // Carry on as the edit page of the new listing, keeping the photos here
      keepStateFor = saved.property_id
      existing.data.value = saved
      router.replace({ name: 'listing-edit', params: { id: saved.property_id } })
    }
    toast.error(
      failed > 0
        ? `Listing saved, but ${failed} ${failed === 1 ? 'photo' : 'photos'} didn't upload. They're marked below: save again to retry.`
        : 'Listing saved, but some photo changes failed. Save again to retry.',
    )
    return
  }

  leavingOnPurpose = true
  toast.show(isEdit.value ? 'Changes saved' : 'Listing published')
  router.push({ name: 'owner-listings' })
}

onBeforeRouteLeave(async () => {
  if (leavingOnPurpose || sending.value || snapshot() === savedSnapshot) return true
  return confirm.ask({
    title: 'Leave without saving?',
    text: 'Your changes to this listing will be lost.',
    confirmLabel: 'Leave page',
    cancelLabel: 'Keep editing',
  })
})

// Opening another listing's edit page reuses this component
watch(
  () => props.id,
  async (id) => {
    leavingOnPurpose = false
    if (id !== null && id === keepStateFor) {
      keepStateFor = null
      return
    }
    if (id === null) {
      form.reset(BLANK)
      pin.value = null
      photos.value = []
      savedImages.value = []
      savedSnapshot = snapshot()
      return
    }
    await existing.run()
    if (existing.data.value?.is_mine) fillFrom(existing.data.value)
  },
  { immediate: true },
)
onMounted(cities.run)
</script>

<template>
  <div class="container">
    <div class="page-head">
      <nav aria-label="breadcrumb">
        <ol class="breadcrumb small mb-2">
          <li class="breadcrumb-item">
            <RouterLink :to="{ name: 'owner-listings' }">My listings</RouterLink>
          </li>
          <li class="breadcrumb-item active text-truncate" aria-current="page">
            {{ isEdit ? (existing.data.value?.title ?? 'Edit listing') : 'New listing' }}
          </li>
        </ol>
      </nav>
      <h1 class="h2 mb-1">{{ isEdit ? 'Edit listing' : 'List a property' }}</h1>
      <p class="text-muted mb-0">Fields marked * are required.</p>
    </div>

    <ErrorAlert
      v-if="isEdit && existing.error.value"
      what="this listing"
      :error="existing.error.value"
      :retry="existing.error.value.status !== 404"
      @retry="existing.run"
    />
    <EmptyState
      v-else-if="notMine"
      icon="shield-lock"
      title="This isn't your listing"
      text="Only the owner who posted a listing can edit it."
    >
      <RouterLink class="btn btn-primary" :to="{ name: 'owner-listings' }">My listings</RouterLink>
    </EmptyState>
    <div v-else-if="isEdit && (existing.loading.value || !existing.data.value)" aria-busy="true">
      <span class="visually-hidden" role="status">Loading listing…</span>
      <div class="skeleton mb-3" style="height: 220px"></div>
      <div class="skeleton" style="height: 160px"></div>
    </div>

    <template v-else>
      <div v-if="failure" class="alert alert-danger d-flex gap-2" role="alert">
        <i class="bi bi-exclamation-octagon" aria-hidden="true"></i>
        <div>{{ failure }}</div>
      </div>
      <ErrorSummary ref="summary" :errors="form.submitted.value ? form.errorList.value : []" />

      <form class="row g-4" novalidate @submit.prevent="submit">
        <div class="col-lg-8 d-grid gap-4">
          <section class="panel" aria-labelledby="s1">
            <h2 id="s1" class="h5 mb-3">1. Basics</h2>
            <FormField
              v-slot="{ attrs }"
              id="title"
              class="mb-3"
              label="Listing title *"
              :error="form.errors.title"
            >
              <input
                v-bind="attrs"
                v-model="form.values.title"
                class="form-control"
                maxlength="150"
                placeholder="e.g. Fully furnished 2-bed condo in Mont Kiara"
                @blur="form.touch('title', $event)"
              />
            </FormField>
            <div class="row g-3">
              <div class="col-md-4">
                <span id="lt-label" class="form-label d-block">Listing type *</span>
                <div class="segmented w-100" role="radiogroup" aria-labelledby="lt-label">
                  <input
                    id="lt-rent"
                    v-model="form.values.listing_type"
                    type="radio"
                    class="btn-check"
                    value="rent"
                  />
                  <label class="btn" for="lt-rent">Rent</label>
                  <input
                    id="lt-sale"
                    v-model="form.values.listing_type"
                    type="radio"
                    class="btn-check"
                    value="sale"
                  />
                  <label class="btn" for="lt-sale">Sale</label>
                </div>
              </div>
              <div class="col-md-4">
                <label class="form-label" for="property_type">Property type *</label>
                <select id="property_type" v-model="form.values.property_type" class="form-select">
                  <option v-for="(label, value) in TYPE_LABELS" :key="value" :value="value">
                    {{ label }}
                  </option>
                </select>
              </div>
              <div class="col-md-4">
                <FormField
                  v-slot="{ attrs }"
                  id="price"
                  label="Price *"
                  prefix="RM"
                  :help="
                    form.values.listing_type === 'rent' ? 'Monthly rent.' : 'The full sale price.'
                  "
                  :error="form.errors.price"
                >
                  <input
                    v-bind="attrs"
                    v-model="form.values.price"
                    class="form-control"
                    inputmode="decimal"
                    @blur="form.touch('price', $event)"
                  />
                </FormField>
              </div>
            </div>
            <div v-if="isEdit" class="mt-3 status-field">
              <label class="form-label" for="status">Status</label>
              <select
                id="status"
                v-model="form.values.status"
                class="form-select"
                aria-describedby="status-help"
              >
                <option v-for="s in ['available', 'rented', 'sold']" :key="s" :value="s">
                  {{ STATUS_LABELS[s] }}
                </option>
              </select>
              <div id="status-help" class="form-text">
                Rented or sold hides it from search and closes its open viewing requests.
              </div>
            </div>
          </section>

          <section class="panel" aria-labelledby="s2">
            <h2 id="s2" class="h5 mb-3">2. Size and rooms</h2>
            <div class="row g-3">
              <div
                v-for="field in [
                  { key: 'bedrooms', label: 'Bedrooms *' },
                  { key: 'bathrooms', label: 'Bathrooms *' },
                  { key: 'parking_spaces', label: 'Parking *' },
                ]"
                :key="field.key"
                class="col-6 col-md-3"
              >
                <FormField
                  v-slot="{ attrs }"
                  :id="field.key"
                  :label="field.label"
                  :error="form.errors[field.key]"
                >
                  <input
                    v-bind="attrs"
                    v-model="form.values[field.key]"
                    class="form-control"
                    type="number"
                    min="0"
                    max="20"
                    step="1"
                    @blur="form.touch(field.key, $event)"
                  />
                </FormField>
              </div>
              <div class="col-6 col-md-3">
                <FormField
                  v-slot="{ attrs }"
                  id="floor_area_sqm"
                  label="Floor area (m²)"
                  :error="form.errors.floor_area_sqm"
                >
                  <input
                    v-bind="attrs"
                    v-model="form.values.floor_area_sqm"
                    class="form-control"
                    inputmode="decimal"
                    @blur="form.touch('floor_area_sqm', $event)"
                  />
                </FormField>
              </div>
            </div>
            <div class="form-check form-switch mt-3">
              <input
                id="is_furnished"
                v-model="form.values.is_furnished"
                class="form-check-input"
                type="checkbox"
                role="switch"
              />
              <label class="form-check-label" for="is_furnished">Furnished</label>
            </div>
          </section>

          <section class="panel" aria-labelledby="s3">
            <h2 id="s3" class="h5 mb-3">3. Description *</h2>
            <FormField
              v-slot="{ attrs }"
              id="description"
              label="Description"
              help="At least 20 characters. Mention transport, schools, shops and facilities."
              :error="form.errors.description"
            >
              <textarea
                v-bind="attrs"
                v-model="form.values.description"
                class="form-control"
                rows="5"
                maxlength="5000"
                @blur="form.touch('description', $event)"
              ></textarea>
            </FormField>
            <div class="form-text text-end" aria-live="polite">
              {{ form.values.description.length }} / 5000
            </div>
          </section>

          <section class="panel" aria-labelledby="s4">
            <h2 id="s4" class="h5 mb-3">4. Location</h2>
            <div class="row g-3">
              <div class="col-12">
                <FormField
                  v-slot="{ attrs }"
                  id="address"
                  label="Street address *"
                  :error="form.errors.address"
                >
                  <input
                    v-bind="attrs"
                    v-model="form.values.address"
                    class="form-control"
                    autocomplete="street-address"
                    maxlength="255"
                    @blur="form.touch('address', $event)"
                  />
                </FormField>
              </div>
              <div class="col-md-5">
                <FormField v-slot="{ attrs }" id="city" label="City *" :error="form.errors.city">
                  <input
                    v-bind="attrs"
                    v-model="form.values.city"
                    class="form-control"
                    list="city-list"
                    maxlength="100"
                    @blur="form.touch('city', $event)"
                  />
                </FormField>
                <datalist id="city-list">
                  <option
                    v-for="c in cities.data.value ?? []"
                    :key="c.city"
                    :value="c.city"
                  ></option>
                </datalist>
              </div>
              <div class="col-md-4">
                <label class="form-label" for="state">State</label>
                <select id="state" v-model="form.values.state" class="form-select">
                  <option value="">Choose…</option>
                  <option v-for="s in MALAYSIAN_STATES" :key="s" :value="s">{{ s }}</option>
                </select>
              </div>
              <div class="col-md-3">
                <FormField
                  v-slot="{ attrs }"
                  id="postcode"
                  label="Postcode"
                  :error="form.errors.postcode"
                >
                  <input
                    v-bind="attrs"
                    v-model="form.values.postcode"
                    class="form-control"
                    inputmode="numeric"
                    maxlength="10"
                    @blur="form.touch('postcode', $event)"
                  />
                </FormField>
              </div>
            </div>
            <div id="latitude" tabindex="-1" class="mt-3">
              <div class="d-flex flex-wrap justify-content-between align-items-baseline gap-2">
                <p class="form-label mb-1">
                  Pin on the map <span class="text-muted fw-normal">(optional)</span>
                </p>
                <button
                  v-if="pin"
                  class="btn btn-link btn-sm p-0"
                  type="button"
                  @click="pin = null"
                >
                  Remove pin
                </button>
              </div>
              <p class="form-text mt-0">
                Click the map to place the pin, then drag it to adjust. Renters use it for map
                search.
                <template v-if="pin"
                  >Pin at {{ pin[0].toFixed(5) }}, {{ pin[1].toFixed(5) }}.</template
                >
              </p>
              <div v-if="form.errors.latitude" class="invalid-feedback d-block mb-2">
                {{ form.errors.latitude }}
              </div>
              <div class="pick-map">
                <LeafletMap
                  v-model:pin="pin"
                  pick
                  :center="pin ?? KL_CENTER"
                  :zoom="pin ? 15 : 11"
                  :scroll-zoom="false"
                  label="Pick the property location on the map"
                />
              </div>
            </div>
          </section>

          <section class="panel" aria-labelledby="s5">
            <div class="d-flex justify-content-between align-items-baseline">
              <h2 id="s5" class="h5 mb-3">5. Photos</h2>
              <span class="text-muted small">{{ photos.length }} / 10</span>
            </div>
            <PhotoManager ref="photoManager" v-model="photos" :error="photoError" />
          </section>
        </div>

        <aside class="col-lg-4">
          <div class="side d-grid gap-3">
            <div>
              <p class="form-label mb-2">Card preview</p>
              <PropertyCard
                preview
                :property="previewProperty"
                :cover-url="photos.find((p) => !p.is_hidden)?.url ?? ''"
              />
            </div>
            <div class="panel d-grid gap-2">
              <button class="btn btn-primary btn-lg" type="submit" :disabled="sending">
                <span
                  v-if="sending"
                  class="spinner-border spinner-border-sm"
                  aria-hidden="true"
                ></span>
                {{ sending ? 'Saving…' : isEdit ? 'Save changes' : 'Publish listing' }}
              </button>
              <RouterLink class="btn btn-outline-secondary" :to="{ name: 'owner-listings' }">
                Cancel
              </RouterLink>
              <p class="small text-muted mb-0 text-center">You can edit or remove it any time.</p>
            </div>
          </div>
        </aside>
      </form>
    </template>
  </div>
</template>

<style scoped>
.pick-map {
  height: 260px;
  border-radius: var(--rob-radius-lg);
  overflow: hidden;
  border: 1px solid var(--rob-line);
}
.status-field {
  max-width: 320px;
}
#latitude:focus {
  outline: none;
}
@media (min-width: 992px) {
  .side {
    position: sticky;
    top: calc(var(--rob-nav-height) + 20px);
  }
}
</style>

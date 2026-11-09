<script setup>
import { computed, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { getProperty, listProperties } from '@/api/properties'
import { useAsync } from '@/composables/useAsync'
import { useListingActions } from '@/composables/useListingActions'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useCompareStore, COMPARE_MAX } from '@/stores/compare'
import { useLikesStore } from '@/stores/likes'
import { money, typeLabel, initials, daysAgo, formatPhone, whatsappLink } from '@/utils/format'
import PhotoGallery from '@/components/PhotoGallery.vue'
import PriceLabel from '@/components/PriceLabel.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import LeafletMap from '@/components/LeafletMap.vue'
import PropertyGrid from '@/components/PropertyGrid.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'
import BookingPanel from '@/components/BookingPanel.vue'

const props = defineProps({
  id: { type: Number, required: true },
})

const auth = useAuthStore()
const toast = useToastStore()
const compare = useCompareStore()
const likes = useLikesStore()
const route = useRoute()
const router = useRouter()
const { changeStatus, remove, busyId } = useListingActions()

const detail = useAsync(() => getProperty(props.id))
const similarRaw = useAsync((city) => listProperties({ city, per_page: 4 }))

const p = computed(() => detail.data.value)
const notFound = computed(() => detail.error.value?.status === 404)
const hasMap = computed(() => p.value?.latitude !== null && p.value?.longitude !== null)
const pricePerSqm = computed(() =>
  p.value?.floor_area_sqm ? Math.round(p.value.price / p.value.floor_area_sqm) : null,
)
const similar = computed(() =>
  (similarRaw.data.value ?? []).filter((x) => x.property_id !== props.id).slice(0, 3),
)
const fullAddress = computed(() =>
  [p.value.address, [p.value.postcode, p.value.city].filter(Boolean).join(' '), p.value.state]
    .filter(Boolean)
    .join(', '),
)
const facts = computed(() => [
  { label: 'Bedrooms', value: p.value.bedrooms || 'Studio' },
  { label: 'Bathrooms', value: p.value.bathrooms },
  { label: 'Parking', value: p.value.parking_spaces },
  { label: 'Floor area', value: p.value.floor_area_sqm ? `${p.value.floor_area_sqm} m²` : '–' },
  { label: 'Type', value: typeLabel(p.value.property_type) },
  { label: 'Furnishing', value: p.value.is_furnished ? 'Furnished' : 'Unfurnished' },
])
const whatsapp = computed(() =>
  whatsappLink(p.value.owner.phone, `Hi, I saw "${p.value.title}" on RoB Property.`),
)
const hiddenPhotos = computed(() => p.value?.images.filter((img) => img.is_hidden).length ?? 0)
const liked = computed(() => likes.isLiked(p.value))
const likeCount = computed(() => likes.likeCount(p.value))
const loginLink = computed(() => ({ name: 'login', query: { redirect: route.fullPath } }))

async function load() {
  await detail.run()
  if (p.value) {
    document.title = `${p.value.title} | RoB Property`
    similarRaw.run(p.value.city)
  }
}

async function markAs(status) {
  const updated = await changeStatus(p.value, status)
  if (updated) detail.data.value = updated
}

async function deleteListing() {
  if (await remove(p.value)) router.push({ name: 'owner-listings' })
}

async function share() {
  const url = window.location.href
  try {
    if (navigator.share) {
      await navigator.share({ title: p.value.title, url })
    } else {
      await navigator.clipboard.writeText(url)
      toast.show('Link copied', { icon: 'link-45deg' })
    }
  } catch {
    // the user closed the share sheet
  }
}

function toggleCompare() {
  if (compare.has(props.id)) {
    compare.remove(props.id)
  } else if (!compare.add(props.id)) {
    toast.show(`You can compare up to ${COMPARE_MAX} properties`, { icon: 'info-circle' })
  }
}

// Same component is reused when moving between listings ("More homes in …")
watch(() => props.id, load, { immediate: true })
</script>

<template>
  <div class="container">
    <ErrorAlert
      v-if="detail.error.value && !notFound"
      class="mt-4"
      what="this listing"
      :error="detail.error.value"
      @retry="load"
    />

    <div v-else-if="notFound" class="py-5">
      <EmptyState
        icon="house-x"
        title="This listing is not available"
        text="It may have been removed by the owner, or the link is wrong."
      >
        <RouterLink class="btn btn-primary" :to="{ name: 'properties' }"
          >Browse other homes</RouterLink
        >
      </EmptyState>
    </div>

    <div v-else-if="detail.loading.value || !p" class="py-4" aria-busy="true">
      <span class="visually-hidden" role="status">Loading listing…</span>
      <div class="skeleton mb-3" style="height: 28px; width: 40%"></div>
      <div class="skeleton gallery-skeleton"></div>
      <div class="row mt-4 g-4">
        <div class="col-lg-8">
          <div class="skeleton mb-2" style="height: 20px"></div>
          <div class="skeleton mb-2" style="height: 20px; width: 80%"></div>
        </div>
        <div class="col-lg-4"><div class="skeleton" style="height: 240px"></div></div>
      </div>
    </div>

    <template v-else>
      <nav aria-label="breadcrumb" class="pt-4">
        <ol class="breadcrumb small mb-3">
          <li class="breadcrumb-item"><RouterLink :to="{ name: 'home' }">Home</RouterLink></li>
          <li class="breadcrumb-item">
            <RouterLink :to="{ name: 'properties' }">Properties</RouterLink>
          </li>
          <li class="breadcrumb-item">
            <RouterLink :to="{ name: 'properties', query: { city: p.city } }">{{
              p.city
            }}</RouterLink>
          </li>
          <li class="breadcrumb-item active text-truncate" aria-current="page">{{ p.title }}</li>
        </ol>
      </nav>

      <div class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-3">
        <div class="min-w-0">
          <div class="d-flex gap-2 mb-2">
            <span
              class="badge-listing"
              :class="p.listing_type === 'sale' ? 'badge-sale' : 'badge-rent'"
            >
              For {{ p.listing_type }}
            </span>
            <StatusBadge v-if="p.status !== 'available'" :status="p.status" />
          </div>
          <h1 class="h2 mb-1">{{ p.title }}</h1>
          <p class="text-muted mb-0">
            <i class="bi bi-geo-alt" aria-hidden="true"></i> {{ p.address }}, {{ p.city }}
          </p>
        </div>
        <div class="d-flex flex-wrap gap-2">
          <RouterLink
            v-if="p.is_mine"
            class="btn btn-outline-secondary"
            :to="{ name: 'listing-edit', params: { id: p.property_id } }"
          >
            <i class="bi bi-pencil" aria-hidden="true"></i>Edit
          </RouterLink>
          <template v-if="!p.is_mine">
            <RouterLink v-if="!auth.isLoggedIn" class="btn btn-outline-secondary" :to="loginLink">
              <i class="bi bi-heart" aria-hidden="true"></i>Save
              <span class="visually-hidden">(log in first)</span>
            </RouterLink>
            <button
              v-else
              class="btn btn-outline-secondary"
              type="button"
              :aria-pressed="liked ? 'true' : 'false'"
              @click="likes.toggle(p)"
            >
              <i
                class="bi"
                :class="liked ? 'bi-heart-fill text-danger' : 'bi-heart'"
                aria-hidden="true"
              ></i>
              {{ liked ? 'Saved' : 'Save' }}
            </button>
          </template>
          <button class="btn btn-outline-secondary" type="button" @click="share">
            <i class="bi bi-share" aria-hidden="true"></i>Share
          </button>
          <button
            class="btn btn-outline-secondary"
            type="button"
            :aria-pressed="compare.has(p.property_id)"
            @click="toggleCompare"
          >
            <i
              class="bi"
              :class="compare.has(p.property_id) ? 'bi-check2-square' : 'bi-layout-three-columns'"
              aria-hidden="true"
            ></i>
            {{ compare.has(p.property_id) ? 'In compare' : 'Compare' }}
          </button>
        </div>
      </div>

      <PhotoGallery class="mb-4" :images="p.images" :title="p.title" />
      <!-- The API sends hidden photos only to the owner; say so, and where to change it -->
      <p v-if="p.is_mine && hiddenPhotos" class="small text-muted hidden-note">
        <i class="bi bi-eye-slash" aria-hidden="true"></i>
        {{ hiddenPhotos }} {{ hiddenPhotos === 1 ? 'photo is' : 'photos are' }} hidden from the
        public.
        <RouterLink :to="{ name: 'listing-edit', params: { id: p.property_id } }"
          >Manage photos</RouterLink
        >
      </p>

      <div class="row g-4 g-lg-5">
        <div class="col-lg-8">
          <div class="d-flex flex-wrap align-items-baseline gap-3 mb-3">
            <PriceLabel class="fs-2" :price="p.price" :listing-type="p.listing_type" />
            <span v-if="p.listing_type === 'sale' && pricePerSqm" class="text-muted">
              {{ money(pricePerSqm) }} per m²
            </span>
          </div>
          <a v-if="!p.is_mine" class="btn btn-primary w-100 mb-4 d-lg-none" href="#contact">
            {{ auth.isLoggedIn ? 'Book a viewing' : 'Contact owner'
            }}<i class="bi bi-arrow-down" aria-hidden="true"></i>
          </a>

          <dl class="fact-grid mb-4">
            <div v-for="fact in facts" :key="fact.label" class="fact">
              <dt class="k">{{ fact.label }}</dt>
              <dd class="v mb-0">{{ fact.value }}</dd>
            </div>
          </dl>

          <h2 class="h4">About this home</h2>
          <p class="description">{{ p.description }}</p>

          <template v-if="hasMap">
            <hr class="my-4" />
            <h2 class="h4">Location</h2>
            <p class="text-muted">{{ fullAddress }}</p>
            <div class="map-box">
              <LeafletMap
                :center="[p.latitude, p.longitude]"
                :zoom="15"
                circle
                :scroll-zoom="false"
                label="Map of the area around the property"
              />
            </div>
          </template>

          <hr class="my-4" />
          <p class="small text-muted mb-0">
            Listed {{ daysAgo(p.created_at) }} ·
            <i class="bi bi-heart-fill text-danger" aria-hidden="true"></i>
            {{ likeCount }} {{ likeCount === 1 ? 'person' : 'people' }} saved this · Listing #{{
              p.property_id
            }}
          </p>
        </div>

        <aside id="contact" class="col-lg-4">
          <div class="sticky-side">
            <!-- Owner viewing their own listing -->
            <div v-if="p.is_mine" class="panel">
              <div class="d-flex justify-content-between align-items-center mb-3">
                <h2 class="h5 mb-0">Your listing</h2>
                <StatusBadge :status="p.status" />
              </div>
              <div class="stat mb-3">
                <div class="n">{{ likeCount }}</div>
                <div class="k">
                  {{ likeCount === 1 ? 'person saved this' : 'people saved this' }}
                </div>
              </div>
              <div class="d-grid gap-2">
                <RouterLink class="btn btn-primary" :to="{ name: 'owner-requests' }">
                  Review viewing requests
                </RouterLink>
                <RouterLink class="btn btn-outline-secondary" :to="{ name: 'owner-availability' }">
                  Manage viewing days
                </RouterLink>
                <button
                  v-if="p.status === 'available'"
                  class="btn btn-outline-secondary"
                  type="button"
                  :disabled="busyId === p.property_id"
                  @click="markAs(p.listing_type === 'sale' ? 'sold' : 'rented')"
                >
                  <i class="bi bi-key" aria-hidden="true"></i>
                  Mark as {{ p.listing_type === 'sale' ? 'sold' : 'rented' }}
                </button>
                <button
                  v-else
                  class="btn btn-outline-secondary"
                  type="button"
                  :disabled="busyId === p.property_id"
                  @click="markAs('available')"
                >
                  <i class="bi bi-arrow-counterclockwise" aria-hidden="true"></i>Make available
                  again
                </button>
                <button
                  class="btn btn-outline-danger"
                  type="button"
                  :disabled="busyId === p.property_id"
                  @click="deleteListing"
                >
                  <i class="bi bi-trash3" aria-hidden="true"></i>Delete listing
                </button>
              </div>
            </div>

            <!-- Guest: the API hides the phone number -->
            <div v-else-if="!auth.isLoggedIn" class="panel text-center">
              <span class="avatar avatar-lg mx-auto mb-2" aria-hidden="true">{{
                initials(p.owner.full_name)
              }}</span>
              <div class="fw-semibold">{{ p.owner.full_name }}</div>
              <div class="text-muted small mb-3">Owner · replies on WhatsApp</div>
              <div class="panel-surface text-start mb-3 p-3">
                <i class="bi bi-lock me-2" aria-hidden="true"></i>Log in to see the owner's number
                and book a viewing.
              </div>
              <div class="d-grid gap-2">
                <RouterLink class="btn btn-primary btn-lg" :to="loginLink"
                  >Log in to contact</RouterLink
                >
                <RouterLink
                  class="btn btn-outline-secondary"
                  :to="{ name: 'register', query: loginLink.query }"
                >
                  Create a free account
                </RouterLink>
              </div>
            </div>

            <!-- Logged-in viewer or another owner -->
            <div v-else class="panel">
              <div class="d-flex align-items-center gap-3 mb-3">
                <span class="avatar avatar-md" aria-hidden="true">{{
                  initials(p.owner.full_name)
                }}</span>
                <div class="min-w-0">
                  <div class="fw-semibold">{{ p.owner.full_name }}</div>
                  <div v-if="p.owner.phone" class="text-muted small">
                    Owner · {{ formatPhone(p.owner.phone) }}
                  </div>
                </div>
              </div>
              <a
                v-if="p.owner.phone"
                class="btn btn-whatsapp w-100"
                :href="whatsapp"
                target="_blank"
                rel="noopener"
              >
                <i class="bi bi-whatsapp" aria-hidden="true"></i>Chat on WhatsApp
                <span class="visually-hidden">(opens in a new tab)</span>
              </a>
              <p v-else class="text-muted small mb-0">
                This owner hasn't added a WhatsApp number yet.
              </p>
              <hr v-if="p.status === 'available'" class="my-4" />
              <BookingPanel v-if="p.status === 'available'" :property-id="p.property_id" />
            </div>
          </div>
        </aside>
      </div>

      <section class="section pb-0" aria-labelledby="similar-title">
        <h2 id="similar-title" class="h4 mb-3">More homes in {{ p.city }}</h2>
        <PropertyGrid
          :properties="similar"
          :loading="similarRaw.loading.value"
          :error="similarRaw.error.value"
          :skeletons="3"
          what="similar homes"
          @retry="similarRaw.run(p.city)"
        >
          <EmptyState icon="buildings" :title="`No other homes in ${p.city} yet`" />
        </PropertyGrid>
      </section>
    </template>
  </div>
</template>

<style scoped>
.hidden-note {
  margin-top: -0.75rem;
}
.min-w-0 {
  min-width: 0;
}
.breadcrumb-item.active {
  max-width: 40ch;
}
.gallery-skeleton {
  height: 260px;
}
.fact-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}
.fact {
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius);
  padding: 0.875rem 1rem;
}
.fact .k {
  color: var(--rob-muted);
  font-size: 0.875rem;
  font-weight: 400;
}
.fact .v {
  font-weight: 700;
  font-size: 1.0625rem;
}
.description {
  font-size: 1.125rem;
  max-width: 65ch;
  white-space: pre-line; /* keep the owner's line breaks */
}
.map-box {
  height: 300px;
  border-radius: var(--rob-radius-lg);
  overflow: hidden;
  border: 1px solid var(--rob-line);
}
.avatar-md {
  width: 48px;
  height: 48px;
}
.stat {
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius-lg);
  padding: 1rem 1.25rem;
}
.stat .n {
  font-family: var(--rob-font-heading);
  font-size: 1.75rem;
  font-weight: 600;
  line-height: 1.1;
}
.stat .k {
  color: var(--rob-muted);
}
@media (min-width: 576px) {
  .fact-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
@media (min-width: 768px) {
  .gallery-skeleton {
    height: 448px;
  }
  .map-box {
    height: 340px;
  }
}
@media (min-width: 992px) {
  .sticky-side {
    position: sticky;
    top: calc(var(--rob-nav-height) + 20px);
  }
}
@media (min-width: 1200px) {
  .fact-grid {
    grid-template-columns: repeat(6, minmax(0, 1fr));
  }
}
</style>

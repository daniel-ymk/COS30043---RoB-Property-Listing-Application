<script setup>
import { reactive, computed, onMounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { listProperties, listCities } from '@/api/properties'
import { imageUrl } from '@/api/client'
import { useAsync } from '@/composables/useAsync'
import { useAuthStore } from '@/stores/auth'
import { TYPE_LABELS } from '@/utils/format'
import { filtersToQuery, emptyFilters } from '@/utils/filters'
import PropertyGrid from '@/components/PropertyGrid.vue'
import EmptyState from '@/components/EmptyState.vue'
import heroImage from '@/assets/img/hero.jpg'
import ownerImage from '@/assets/img/owner-promo.jpg'
import klImage from '@/assets/img/city-kuala-lumpur.jpg'
import kuchingImage from '@/assets/img/city-kuching.jpg'
import georgeTownImage from '@/assets/img/city-george-town.jpg'

const CITY_PHOTOS = {
  'Kuala Lumpur': klImage,
  Kuching: kuchingImage,
  'George Town': georgeTownImage,
}

const auth = useAuthStore()
const router = useRouter()

const search = reactive({ listing_type: 'rent', q: '', property_type: '', min_bedrooms: '' })

const featured = useAsync(() => listProperties({ sort: 'most_liked', per_page: 3 }))
// Fetch extra so the newest row can skip homes already shown as featured
const newestRaw = useAsync(() => listProperties({ sort: 'newest', per_page: 9 }))
const cities = useAsync(listCities)

const newest = computed(() => {
  const shown = new Set((featured.data.value ?? []).map((p) => p.property_id))
  return (newestRaw.data.value ?? []).filter((p) => !shown.has(p.property_id)).slice(0, 6)
})
const topCities = computed(() =>
  (cities.data.value ?? []).slice(0, 3).map((c) => ({
    ...c,
    photo: CITY_PHOTOS[c.city] ?? imageUrl(c.cover_image),
  })),
)

function submitSearch() {
  const query = filtersToQuery({
    ...emptyFilters(),
    ...search,
    property_type: search.property_type ? [search.property_type] : [],
  })
  router.push({ name: 'properties', query })
}

onMounted(() => {
  featured.run()
  newestRaw.run()
  cities.run()
})
</script>

<template>
  <section class="hero" aria-labelledby="hero-title">
    <img :src="heroImage" alt="" fetchpriority="high" />
    <div class="container py-5">
      <h1 id="hero-title" class="display-5 mb-3">Rent or buy your next home in Malaysia</h1>
      <p class="lead mb-4">
        Listings in Kuala Lumpur, Kuching and Penang, straight from the owner. Book a viewing
        online.
      </p>
      <form class="search-box" role="search" @submit.prevent="submitSearch">
        <div class="segmented mb-3" role="radiogroup" aria-label="Listing type">
          <input
            id="h-rent"
            v-model="search.listing_type"
            type="radio"
            class="btn-check"
            value="rent"
          />
          <label class="btn" for="h-rent">Rent</label>
          <input
            id="h-sale"
            v-model="search.listing_type"
            type="radio"
            class="btn-check"
            value="sale"
          />
          <label class="btn" for="h-sale">Buy</label>
        </div>
        <div class="row g-2 align-items-end">
          <div class="col-12 col-lg-5">
            <label class="form-label small" for="h-q">Location or property name</label>
            <div class="input-group">
              <span class="input-group-text bg-white"
                ><i class="bi bi-search" aria-hidden="true"></i
              ></span>
              <input
                id="h-q"
                v-model="search.q"
                class="form-control border-start-0"
                type="search"
                placeholder="e.g. Mont Kiara, Kuching"
              />
            </div>
          </div>
          <div class="col-6 col-lg-2">
            <label class="form-label small" for="h-type">Type</label>
            <select id="h-type" v-model="search.property_type" class="form-select">
              <option value="">Any</option>
              <option v-for="(label, value) in TYPE_LABELS" :key="value" :value="value">
                {{ label }}
              </option>
            </select>
          </div>
          <div class="col-6 col-lg-2">
            <label class="form-label small" for="h-beds">Bedrooms</label>
            <select id="h-beds" v-model="search.min_bedrooms" class="form-select">
              <option value="">Any</option>
              <option v-for="n in 4" :key="n" :value="String(n)">{{ n }}+</option>
            </select>
          </div>
          <div class="col-12 col-lg-3 d-grid">
            <button class="btn btn-primary btn-lg" type="submit">
              <i class="bi bi-search" aria-hidden="true"></i>Search homes
            </button>
          </div>
        </div>
      </form>
    </div>
  </section>

  <section class="section" aria-labelledby="featured-title">
    <div class="container">
      <div class="section-head">
        <div>
          <h2 id="featured-title" class="h3 mb-1">Most liked</h2>
          <p class="text-muted mb-0">The listings renters and buyers saved most.</p>
        </div>
        <RouterLink
          class="btn btn-outline-secondary"
          :to="{ name: 'properties', query: { sort: 'most_liked' } }"
        >
          See all<i class="bi bi-arrow-right" aria-hidden="true"></i>
        </RouterLink>
      </div>
      <PropertyGrid
        :properties="featured.data.value ?? []"
        :loading="featured.loading.value"
        :error="featured.error.value"
        :skeletons="3"
        @retry="featured.run"
      >
        <EmptyState
          icon="buildings"
          title="No listings yet"
          text="New homes appear here as soon as owners post them."
        />
      </PropertyGrid>
    </div>
  </section>

  <section v-if="topCities.length" class="section pt-0" aria-labelledby="cities-title">
    <div class="container">
      <h2 id="cities-title" class="h3 mb-4">Browse by city</h2>
      <div class="row g-4">
        <div v-for="city in topCities" :key="city.city" class="col-12 col-md-4">
          <RouterLink class="city-card" :to="{ name: 'properties', query: { city: city.city } }">
            <span class="media"
              ><img v-if="city.photo" :src="city.photo" alt="" loading="lazy"
            /></span>
            <span class="body">
              <span class="h5 mb-0">{{ city.city }}</span>
              <span class="text-muted">
                {{ city.listing_count }} {{ city.listing_count === 1 ? 'home' : 'homes' }}
                <i class="bi bi-arrow-right" aria-hidden="true"></i>
              </span>
            </span>
          </RouterLink>
        </div>
      </div>
    </div>
  </section>

  <section class="section bg-body-tertiary border-top border-bottom" aria-labelledby="new-title">
    <div class="container">
      <div class="section-head">
        <div>
          <h2 id="new-title" class="h3 mb-1">Newest listings</h2>
          <p class="text-muted mb-0">Just added by owners.</p>
        </div>
        <RouterLink class="btn btn-outline-secondary" :to="{ name: 'properties' }">
          See all<i class="bi bi-arrow-right" aria-hidden="true"></i>
        </RouterLink>
      </div>
      <PropertyGrid
        :properties="newest"
        :loading="newestRaw.loading.value || featured.loading.value"
        :error="newestRaw.error.value"
        @retry="newestRaw.run"
      >
        <EmptyState
          icon="buildings"
          title="No listings yet"
          text="New homes appear here as soon as owners post them."
        />
      </PropertyGrid>
    </div>
  </section>

  <section v-if="!auth.isLoggedIn || auth.isOwner" class="section" aria-labelledby="owner-title">
    <div class="container">
      <div class="row g-0 panel p-0 overflow-hidden align-items-stretch">
        <div class="col-lg-6 p-4 p-lg-5 d-flex flex-column justify-content-center">
          <h2 id="owner-title" class="h3">Own a property? List it free.</h2>
          <p class="text-muted">
            Add photos, set the days you can show the place, and approve viewing requests from one
            page.
          </p>
          <ul class="list-unstyled d-grid gap-2 mb-4">
            <li>
              <i class="bi bi-check-circle-fill text-primary me-2" aria-hidden="true"></i>Up to 10
              photos per listing
            </li>
            <li>
              <i class="bi bi-check-circle-fill text-primary me-2" aria-hidden="true"></i>Pick your
              own viewing days
            </li>
            <li>
              <i class="bi bi-check-circle-fill text-primary me-2" aria-hidden="true"></i>Renters
              reach you on WhatsApp
            </li>
          </ul>
          <div>
            <RouterLink
              v-if="auth.isOwner"
              class="btn btn-primary btn-lg"
              :to="{ name: 'listing-create' }"
            >
              List a property
            </RouterLink>
            <RouterLink v-else class="btn btn-primary btn-lg" :to="{ name: 'register' }">
              Register as an owner
            </RouterLink>
          </div>
        </div>
        <div class="col-lg-6 promo-photo">
          <img :src="ownerImage" alt="" loading="lazy" />
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.hero {
  position: relative;
  min-height: 520px;
  display: flex;
  align-items: center;
  color: #fff;
  overflow: hidden;
}
.hero > img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
/* phones: even dark wash so text stays readable over any part of the photo */
.hero::before {
  content: '';
  position: absolute;
  inset: 0;
  background: rgb(15 23 42 / 0.6);
  z-index: 1;
}
.hero .container {
  position: relative;
  z-index: 2;
}
.hero h1 {
  color: #fff;
  max-width: 14ch;
}
.hero .lead {
  color: rgb(255 255 255 / 0.92);
  max-width: 36ch;
}
.search-box {
  background: #fff;
  border-radius: var(--rob-radius-lg);
  padding: 1rem;
  box-shadow: 0 20px 40px rgb(15 23 42 / 0.25);
  color: var(--rob-ink);
  max-width: 860px;
}
@media (min-width: 992px) {
  .hero {
    min-height: 560px;
  }
  .hero::before {
    background: linear-gradient(
      90deg,
      rgb(15 23 42 / 0.72) 0%,
      rgb(15 23 42 / 0.35) 60%,
      rgb(15 23 42 / 0.1) 100%
    );
  }
}

.city-card {
  display: block;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius-lg);
  overflow: hidden;
  text-decoration: none;
  color: inherit;
  background: #fff;
  transition:
    box-shadow 0.2s var(--rob-ease),
    transform 0.2s var(--rob-ease);
}
.city-card:hover {
  box-shadow: var(--rob-shadow-hover);
  transform: translateY(-2px);
}
.city-card .media {
  display: block;
  aspect-ratio: 16 / 10;
  background: var(--rob-surface);
}
.city-card img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.city-card .body {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.125rem;
}
.promo-photo {
  min-height: 260px;
}
.promo-photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
@media (prefers-reduced-motion: reduce) {
  .city-card {
    transition: none;
  }
  .city-card:hover {
    transform: none;
  }
}
</style>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { listMine } from '@/api/properties'
import { listAppointments } from '@/api/viewings'
import { imageUrl } from '@/api/client'
import { useAsync } from '@/composables/useAsync'
import { useListingActions } from '@/composables/useListingActions'
import { typeLabel, STATUS_LABELS } from '@/utils/format'
import PriceLabel from '@/components/PriceLabel.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'
import AppPagination from '@/components/AppPagination.vue'

const PER_PAGE = 20
const STATUSES = ['available', 'rented', 'sold']

const route = useRoute()
const page = computed(() => Math.max(1, Number.parseInt(route.query.page, 10) || 1))
const result = useAsync(() => listMine({ page: page.value, per_page: PER_PAGE }))
const { changeStatus, remove, busyId } = useListingActions()
// Pending requests per listing (the request list is small, one page is enough)
const pendingRequests = useAsync(() =>
  listAppointments({ as: 'owner', status: 'pending', per_page: 48 }),
)
const pendingByListing = computed(() => {
  const counts = {}
  for (const a of pendingRequests.data.value ?? []) {
    counts[a.property.property_id] = (counts[a.property.property_id] ?? 0) + 1
  }
  return counts
})

// Edits made on this page, shown without reloading the list
const updates = ref({}) // property_id -> updated card fields
const deleted = ref(new Set())

const listings = computed(() =>
  (result.data.value ?? [])
    .filter((p) => !deleted.value.has(p.property_id))
    .map((p) => ({ ...p, ...updates.value[p.property_id] })),
)
const stats = computed(() => [
  {
    label: 'Available',
    icon: 'house-check',
    value: listings.value.filter((p) => p.status === 'available').length,
  },
  {
    label: 'Rented or sold',
    icon: 'key',
    value: listings.value.filter((p) => p.status !== 'available').length,
  },
  {
    label: 'Total likes',
    icon: 'heart',
    value: listings.value.reduce((n, p) => n + p.like_count, 0),
  },
  {
    label: 'Pending requests',
    icon: 'inbox',
    value: pendingRequests.meta.value?.total ?? 0,
    to: { name: 'owner-requests' },
  },
])

async function setStatus(property, status) {
  const updated = await changeStatus(property, status)
  if (updated) {
    updates.value = { ...updates.value, [property.property_id]: { status: updated.status } }
  }
}

// Phone select: show the old status until the change is confirmed and saved
function onStatusSelect(property, event) {
  const status = event.target.value
  event.target.value = property.status
  setStatus(property, status)
}

async function onDelete(property) {
  if (await remove(property)) deleted.value = new Set([...deleted.value, property.property_id])
}

function reload() {
  updates.value = {}
  deleted.value = new Set()
  result.run()
  pendingRequests.run()
}

watch(
  () => route.query.page,
  () => route.name === 'owner-listings' && reload(),
)
onMounted(reload)
</script>

<template>
  <div class="container">
    <div class="page-head d-flex flex-wrap justify-content-between align-items-end gap-3">
      <div>
        <h1 class="h2 mb-1">My listings</h1>
        <p class="text-muted mb-0">Edit, mark as rented or sold, or remove your properties.</p>
      </div>
      <RouterLink class="btn btn-primary" :to="{ name: 'listing-create' }">
        <i class="bi bi-plus-lg" aria-hidden="true"></i>New listing
      </RouterLink>
    </div>

    <ErrorAlert
      v-if="result.error.value"
      what="your listings"
      :error="result.error.value"
      @retry="reload"
    />

    <div v-else-if="result.loading.value" class="d-grid gap-2" aria-busy="true">
      <span class="visually-hidden" role="status">Loading your listings…</span>
      <div v-for="n in 5" :key="n" class="skeleton" style="height: 76px"></div>
    </div>

    <EmptyState
      v-else-if="!listings.length"
      icon="buildings"
      title="You haven't listed a property yet"
      text="Add photos, a price and the days you can show it. It takes about 5 minutes."
    >
      <RouterLink class="btn btn-primary" :to="{ name: 'listing-create' }">
        Create your first listing
      </RouterLink>
    </EmptyState>

    <template v-else>
      <ul class="row g-3 mb-4 list-unstyled" aria-label="Summary">
        <li v-for="stat in stats" :key="stat.label" class="col-6 col-lg-3">
          <component
            :is="stat.to ? RouterLink : 'div'"
            :to="stat.to"
            class="stat d-flex justify-content-between"
          >
            <div>
              <div class="n">{{ stat.value }}</div>
              <div class="k">{{ stat.label }}</div>
            </div>
            <i class="bi fs-3 text-primary" :class="`bi-${stat.icon}`" aria-hidden="true"></i>
          </component>
        </li>
      </ul>

      <!-- Tablet and desktop: table -->
      <div class="d-none d-md-block table-responsive">
        <table class="table table-rob">
          <caption class="visually-hidden">
            Your listings
          </caption>
          <thead>
            <tr>
              <th scope="col">Listing</th>
              <th scope="col">Price</th>
              <th scope="col">Status</th>
              <th scope="col">Likes</th>
              <th scope="col">Requests</th>
              <th scope="col"><span class="visually-hidden">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in listings" :key="p.property_id" :aria-busy="busyId === p.property_id">
              <td>
                <div class="d-flex align-items-center gap-3">
                  <img
                    v-if="p.cover_image"
                    class="list-thumb"
                    :src="imageUrl(p.cover_image)"
                    alt=""
                  />
                  <span v-else class="list-thumb no-photo"
                    ><i class="bi bi-image" aria-hidden="true"></i
                  ></span>
                  <div class="min-w-0">
                    <RouterLink
                      class="fw-semibold text-body text-decoration-none"
                      :to="{ name: 'property-detail', params: { id: p.property_id } }"
                    >
                      {{ p.title }}
                    </RouterLink>
                    <div class="small text-muted">
                      {{ p.city }} · {{ typeLabel(p.property_type) }} · For {{ p.listing_type }}
                    </div>
                  </div>
                </div>
              </td>
              <td class="text-nowrap">
                <PriceLabel :price="p.price" :listing-type="p.listing_type" />
              </td>
              <td>
                <div class="dropdown">
                  <button
                    class="btn btn-outline-secondary btn-sm dropdown-toggle status-btn"
                    type="button"
                    data-bs-toggle="dropdown"
                    aria-expanded="false"
                    :disabled="busyId === p.property_id"
                  >
                    <StatusBadge :status="p.status" />
                    <span class="visually-hidden">Change status of {{ p.title }}</span>
                  </button>
                  <ul class="dropdown-menu shadow-sm">
                    <li><h6 class="dropdown-header">Change status</h6></li>
                    <li v-for="s in STATUSES" :key="s">
                      <button
                        class="dropdown-item"
                        :class="{ active: s === p.status }"
                        type="button"
                        :aria-current="s === p.status ? 'true' : undefined"
                        @click="setStatus(p, s)"
                      >
                        {{ STATUS_LABELS[s] }}
                      </button>
                    </li>
                    <li><hr class="dropdown-divider" /></li>
                    <li>
                      <span class="dropdown-item-text small text-muted menu-note">
                        Rented or sold closes open viewing requests.
                      </span>
                    </li>
                  </ul>
                </div>
              </td>
              <td>{{ p.like_count }}</td>
              <td>
                <RouterLink
                  v-if="pendingByListing[p.property_id]"
                  class="badge rounded-pill text-bg-primary text-decoration-none"
                  :to="{ name: 'owner-requests' }"
                >
                  {{ pendingByListing[p.property_id] }} pending
                </RouterLink>
                <span v-else class="text-muted">–<span class="visually-hidden">none</span></span>
              </td>
              <td class="text-end text-nowrap">
                <div class="d-inline-flex gap-2">
                  <RouterLink
                    class="btn btn-outline-secondary btn-sm"
                    :to="{ name: 'listing-edit', params: { id: p.property_id } }"
                  >
                    <i class="bi bi-pencil" aria-hidden="true"></i>
                    <span class="d-none d-xl-inline">Edit</span>
                    <span class="visually-hidden">{{ p.title }}</span>
                  </RouterLink>
                  <button
                    class="btn btn-outline-danger btn-sm"
                    type="button"
                    :disabled="busyId === p.property_id"
                    @click="onDelete(p)"
                  >
                    <i class="bi bi-trash3" aria-hidden="true"></i>
                    <span class="visually-hidden">Delete {{ p.title }}</span>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Phones: one card per listing -->
      <ul class="d-md-none d-grid gap-3 list-unstyled">
        <li v-for="p in listings" :key="p.property_id" class="panel p-3">
          <div class="d-flex gap-3">
            <img v-if="p.cover_image" class="list-thumb" :src="imageUrl(p.cover_image)" alt="" />
            <span v-else class="list-thumb no-photo"
              ><i class="bi bi-image" aria-hidden="true"></i
            ></span>
            <div class="min-w-0">
              <RouterLink
                class="fw-semibold text-body text-decoration-none d-block"
                :to="{ name: 'property-detail', params: { id: p.property_id } }"
              >
                {{ p.title }}
              </RouterLink>
              <PriceLabel :price="p.price" :listing-type="p.listing_type" />
              <div class="small text-muted">
                <i class="bi bi-heart-fill text-danger" aria-hidden="true"></i> {{ p.like_count }}
                {{ p.like_count === 1 ? 'like' : 'likes' }}
              </div>
            </div>
          </div>
          <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3">
            <label class="visually-hidden" :for="`status-${p.property_id}`">
              Status of {{ p.title }}
            </label>
            <select
              :id="`status-${p.property_id}`"
              class="form-select form-select-sm w-auto"
              :value="p.status"
              :disabled="busyId === p.property_id"
              @change="onStatusSelect(p, $event)"
            >
              <option v-for="s in STATUSES" :key="s" :value="s">{{ STATUS_LABELS[s] }}</option>
            </select>
            <div class="d-flex gap-2">
              <RouterLink
                class="btn btn-outline-secondary btn-sm"
                :to="{ name: 'listing-edit', params: { id: p.property_id } }"
              >
                <i class="bi bi-pencil" aria-hidden="true"></i>Edit
                <span class="visually-hidden">{{ p.title }}</span>
              </RouterLink>
              <button
                class="btn btn-outline-danger btn-sm"
                type="button"
                :disabled="busyId === p.property_id"
                @click="onDelete(p)"
              >
                <i class="bi bi-trash3" aria-hidden="true"></i>
                <span class="visually-hidden">Delete {{ p.title }}</span>
              </button>
            </div>
          </div>
        </li>
      </ul>

      <AppPagination
        v-if="result.meta.value"
        class="mt-4"
        :meta="result.meta.value"
        label="listing"
      />
    </template>
  </div>
</template>

<style scoped>
.stat {
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius-lg);
  padding: 1rem 1.25rem;
  background: #fff;
}
.stat .n {
  font-family: var(--rob-font-heading);
  font-size: 1.75rem;
  font-weight: 600;
  line-height: 1.1;
}
a.stat {
  color: inherit;
  text-decoration: none;
}
a.stat:hover {
  border-color: var(--rob-primary);
}
.stat .k {
  color: var(--rob-muted);
  font-size: 0.9375rem;
}
.table-rob {
  --bs-table-bg: #fff;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius-lg);
  overflow: hidden;
  margin: 0;
}
.table-rob th {
  font-size: 0.8125rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--rob-muted);
  font-weight: 600;
  background: var(--rob-surface);
}
.table-rob td,
.table-rob th {
  padding: 0.875rem 1rem;
  vertical-align: middle;
}
.list-thumb {
  width: 72px;
  height: 54px;
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
.min-w-0 {
  min-width: 0;
}
.status-btn {
  border: 0;
  padding-left: 0;
}
.menu-note {
  display: block;
  max-width: 220px;
}
</style>

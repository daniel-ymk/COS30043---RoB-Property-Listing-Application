<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { listAppointments, setAppointmentStatus } from '@/api/viewings'
import { imageUrl } from '@/api/client'
import { useAsync } from '@/composables/useAsync'
import { useToastStore } from '@/stores/toast'
import { useConfirmStore } from '@/stores/confirm'
import { usePendingRequestsStore } from '@/stores/requests'
import { fmtDate, fmtTime, initials, daysAgo } from '@/utils/format'
import StatusBadge from '@/components/StatusBadge.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'
import AppPagination from '@/components/AppPagination.vue'

const TABS = [
  { key: 'pending', label: 'Pending' },
  { key: 'confirmed', label: 'Confirmed' },
  { key: 'declined', label: 'Declined' },
  { key: 'cancelled', label: 'Cancelled' },
  { key: 'all', label: 'All' },
]

const route = useRoute()
const toast = useToastStore()
const confirm = useConfirmStore()
const pending = usePendingRequestsStore()

// Tab and page live in the URL (?status=confirmed&page=2)
const tab = computed(() =>
  TABS.some((t) => t.key === route.query.status) ? route.query.status : 'pending',
)
const page = computed(() => Math.max(1, Number.parseInt(route.query.page, 10) || 1))
const result = useAsync(() =>
  listAppointments({
    as: 'owner',
    status: tab.value === 'all' ? undefined : tab.value,
    page: page.value,
    per_page: 10,
  }),
)
const busyId = ref(null)

const counts = computed(() => result.meta.value?.counts ?? {})
const countFor = (key) =>
  key === 'all' ? Object.values(counts.value).reduce((a, b) => a + b, 0) : (counts.value[key] ?? 0)
const isPast = (a) => new Date(`${a.viewing_date}T${a.viewing_time}`) < new Date()

async function decide(appointment, status) {
  if (status === 'declined') {
    const ok = await confirm.ask({
      title: `Decline ${appointment.viewer.full_name}'s request?`,
      text: `The day (${fmtDate(appointment.viewing_date)}) becomes free for other renters. This can't be undone.`,
      confirmLabel: 'Decline request',
      cancelLabel: 'Keep it',
    })
    if (!ok) return
  }
  busyId.value = appointment.appointment_id
  try {
    await setAppointmentStatus(appointment.appointment_id, status)
    toast.show(
      status === 'confirmed'
        ? `Viewing confirmed. ${appointment.viewer.full_name} can see it in My viewings.`
        : 'Request declined. The day is free again.',
      { icon: status === 'confirmed' ? 'check-circle' : 'x-circle' },
    )
  } catch (err) {
    // 409: someone (or the viewer) changed it first
    toast.error(err.message)
  } finally {
    busyId.value = null
    result.run()
    pending.refresh({ force: true })
  }
}

watch(
  () => route.query,
  () => route.name === 'owner-requests' && result.run(),
)
onMounted(result.run)
</script>

<template>
  <div class="container">
    <div class="page-head">
      <h1 class="h2 mb-1">Viewing requests</h1>
      <p class="text-muted mb-0">
        Confirm or decline requests on your listings. Declining frees the day for someone else.
      </p>
    </div>

    <ul class="nav nav-pills mb-4 gap-2" aria-label="Filter requests by status">
      <li v-for="t in TABS" :key="t.key" class="nav-item">
        <RouterLink
          class="nav-link"
          :class="{ active: t.key === tab }"
          :to="{ query: t.key === 'pending' ? {} : { status: t.key } }"
          :aria-current="t.key === tab ? 'true' : undefined"
        >
          {{ t.label }}
          <span
            v-if="result.meta.value"
            class="badge rounded-pill ms-1"
            :class="t.key === tab ? 'text-bg-light' : 'text-bg-secondary'"
          >
            {{ countFor(t.key) }}
          </span>
        </RouterLink>
      </li>
    </ul>

    <ErrorAlert
      v-if="result.error.value"
      what="viewing requests"
      :error="result.error.value"
      @retry="result.run"
    />

    <div
      v-else-if="result.loading.value && !result.data.value"
      class="d-grid gap-3"
      aria-busy="true"
    >
      <span class="visually-hidden" role="status">Loading requests…</span>
      <div v-for="n in 3" :key="n" class="skeleton" style="height: 132px"></div>
    </div>

    <EmptyState
      v-else-if="!result.data.value?.length"
      icon="inbox"
      :title="
        tab === 'pending' ? `You're all caught up` : `No ${tab === 'all' ? '' : tab + ' '}requests`
      "
      text="New viewing requests show up here and in the navbar badge."
    >
      <RouterLink class="btn btn-outline-primary" :to="{ name: 'owner-availability' }">
        Add more viewing days
      </RouterLink>
    </EmptyState>

    <ul v-else class="list-unstyled d-grid gap-3" :aria-busy="result.loading.value">
      <li
        v-for="a in result.data.value"
        :key="a.appointment_id"
        class="panel request"
        :aria-label="`Request from ${a.viewer.full_name}`"
      >
        <div class="row g-3 align-items-center">
          <div class="col-md-5 d-flex gap-3 align-items-center">
            <img
              v-if="a.property.cover_image"
              class="thumb"
              :src="imageUrl(a.property.cover_image)"
              alt=""
            />
            <span v-else class="thumb no-photo"
              ><i class="bi bi-image" aria-hidden="true"></i
            ></span>
            <div class="min-w-0">
              <RouterLink
                class="fw-semibold text-body text-decoration-none"
                :to="{ name: 'property-detail', params: { id: a.property.property_id } }"
              >
                {{ a.property.title }}
              </RouterLink>
              <div class="small text-muted">{{ a.property.city }}</div>
            </div>
          </div>
          <div class="col-md-4">
            <div class="d-flex align-items-center gap-2 mb-1">
              <span class="avatar avatar-sm" aria-hidden="true">{{
                initials(a.viewer.full_name)
              }}</span>
              <span class="fw-semibold">{{ a.viewer.full_name }}</span>
            </div>
            <div class="small">
              <i class="bi bi-calendar-event text-muted" aria-hidden="true"></i>
              {{ fmtDate(a.viewing_date) }} · {{ fmtTime(a.viewing_time) }}
            </div>
            <div v-if="a.message" class="small text-muted mt-1 message">"{{ a.message }}"</div>
          </div>
          <div class="col-md-3 d-flex flex-wrap gap-2 justify-content-md-end">
            <template v-if="a.status === 'pending' && !isPast(a)">
              <button
                class="btn btn-outline-secondary"
                type="button"
                :disabled="busyId === a.appointment_id"
                @click="decide(a, 'declined')"
              >
                Decline<span class="visually-hidden"> {{ a.viewer.full_name }}</span>
              </button>
              <button
                class="btn btn-primary"
                type="button"
                :disabled="busyId === a.appointment_id"
                @click="decide(a, 'confirmed')"
              >
                <i class="bi bi-check-lg" aria-hidden="true"></i>Confirm
                <span class="visually-hidden">{{ a.viewer.full_name }}</span>
              </button>
            </template>
            <span v-else-if="a.status === 'pending'" class="small text-muted">Date has passed</span>
            <StatusBadge v-else :status="a.status" />
          </div>
        </div>
        <div class="small text-muted mt-2">Requested {{ daysAgo(a.created_at) }}</div>
      </li>
    </ul>

    <AppPagination
      v-if="result.meta.value && result.data.value?.length"
      class="mt-4"
      :meta="result.meta.value"
      label="request"
    />
  </div>
</template>

<style scoped>
.request {
  padding: 1rem;
}
.thumb {
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
.avatar-sm {
  width: 28px;
  height: 28px;
  font-size: 0.75rem;
}
.min-w-0 {
  min-width: 0;
}
.message {
  overflow-wrap: anywhere;
}
@media (min-width: 768px) {
  .request {
    padding: 1.5rem;
  }
}
</style>

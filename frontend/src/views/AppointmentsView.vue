<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { listAppointments, setAppointmentStatus } from '@/api/viewings'
import { imageUrl } from '@/api/client'
import { useAsync } from '@/composables/useAsync'
import { useToastStore } from '@/stores/toast'
import { useConfirmStore } from '@/stores/confirm'
import { fmtDate, fmtTime, whatsappLink } from '@/utils/format'
import StatusBadge from '@/components/StatusBadge.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'
import AppPagination from '@/components/AppPagination.vue'

const TABS = [
  { key: 'upcoming', label: 'Upcoming' },
  { key: 'past', label: 'Past and cancelled' },
]

const route = useRoute()
const toast = useToastStore()
const confirm = useConfirmStore()

const tab = computed(() => (route.query.when === 'past' ? 'past' : 'upcoming'))
const page = computed(() => Math.max(1, Number.parseInt(route.query.page, 10) || 1))
const result = useAsync(() =>
  listAppointments({ as: 'viewer', when: tab.value, page: page.value, per_page: 10 }),
)
const busyId = ref(null)

const canCancel = (a) => ['pending', 'confirmed'].includes(a.status) && tab.value === 'upcoming'
const month = (a) => fmtDate(a.viewing_date, { month: 'short' })
const weekday = (a) => fmtDate(a.viewing_date, { weekday: 'short' })
const dayNumber = (a) => Number(a.viewing_date.slice(8, 10))

async function cancel(appointment) {
  const ok = await confirm.ask({
    title: 'Cancel this viewing?',
    text: `${appointment.property.title}, ${fmtDate(appointment.viewing_date)}. The owner is told, and the day becomes free for other people.`,
    confirmLabel: 'Cancel viewing',
    cancelLabel: 'Keep viewing',
    danger: true,
  })
  if (!ok) return
  busyId.value = appointment.appointment_id
  try {
    await setAppointmentStatus(appointment.appointment_id, 'cancelled')
    toast.show('Viewing cancelled', { icon: 'calendar-x' })
  } catch (err) {
    toast.error(err.message)
  } finally {
    busyId.value = null
    result.run()
  }
}

watch(
  () => route.query,
  () => route.name === 'appointments' && result.run(),
)
onMounted(result.run)
</script>

<template>
  <div class="container">
    <div class="page-head">
      <h1 class="h2 mb-1">My viewings</h1>
      <p class="text-muted mb-0">Viewings you've requested. Owners confirm or decline each one.</p>
    </div>

    <ul class="nav nav-pills mb-4 gap-2" aria-label="Filter viewings">
      <li v-for="t in TABS" :key="t.key" class="nav-item">
        <RouterLink
          class="nav-link"
          :class="{ active: t.key === tab }"
          :to="{ query: t.key === 'upcoming' ? {} : { when: t.key } }"
          :aria-current="t.key === tab ? 'true' : undefined"
        >
          {{ t.label }}
        </RouterLink>
      </li>
    </ul>

    <ErrorAlert
      v-if="result.error.value"
      what="your viewings"
      :error="result.error.value"
      @retry="result.run"
    />

    <div
      v-else-if="result.loading.value && !result.data.value"
      class="d-grid gap-3"
      aria-busy="true"
    >
      <span class="visually-hidden" role="status">Loading viewings…</span>
      <div v-for="n in 3" :key="n" class="skeleton" style="height: 120px"></div>
    </div>

    <EmptyState
      v-else-if="!result.data.value?.length"
      icon="calendar-event"
      :title="tab === 'upcoming' ? 'No upcoming viewings' : 'No past viewings yet'"
      text="Open any listing and pick a free day to book a viewing."
    >
      <RouterLink class="btn btn-primary" :to="{ name: 'properties' }">Find a home</RouterLink>
    </EmptyState>

    <ul v-else class="list-unstyled d-grid gap-3" :aria-busy="result.loading.value">
      <li v-for="a in result.data.value" :key="a.appointment_id" class="panel p-3">
        <div class="row g-3 align-items-center">
          <div class="col-auto">
            <div class="date-tile" aria-hidden="true">
              <div class="small text-muted text-uppercase fw-semibold">{{ month(a) }}</div>
              <div class="h3 mb-0">{{ dayNumber(a) }}</div>
              <div class="small text-muted">{{ weekday(a) }}</div>
            </div>
          </div>
          <div class="col-auto d-none d-sm-block">
            <img
              v-if="a.property.cover_image"
              class="thumb"
              :src="imageUrl(a.property.cover_image)"
              alt=""
            />
          </div>
          <div class="col min-w-0">
            <div class="d-flex flex-wrap gap-2 align-items-center mb-1">
              <StatusBadge :status="a.status" />
              <span class="text-muted small">
                <i class="bi bi-clock" aria-hidden="true"></i>
                <span class="visually-hidden">{{ fmtDate(a.viewing_date) }} at</span>
                {{ fmtTime(a.viewing_time) }}
              </span>
            </div>
            <RouterLink
              class="fw-semibold text-body text-decoration-none fs-5 d-block"
              :to="{ name: 'property-detail', params: { id: a.property.property_id } }"
            >
              {{ a.property.title }}
            </RouterLink>
            <div class="text-muted small">
              {{ a.property.address }}, {{ a.property.city }} · Owner {{ a.owner.full_name }}
            </div>
            <div v-if="a.message" class="small mt-1 message">
              <i class="bi bi-chat-left-text text-muted" aria-hidden="true"></i> "{{ a.message }}"
            </div>
          </div>
          <div class="col-12 col-md-auto d-flex flex-wrap gap-2">
            <a
              v-if="a.status === 'confirmed' && a.owner.phone"
              class="btn btn-whatsapp btn-sm"
              :href="
                whatsappLink(
                  a.owner.phone,
                  `Hi, about my viewing of &quot;${a.property.title}&quot; on ${fmtDate(a.viewing_date)}.`,
                )
              "
              target="_blank"
              rel="noopener"
            >
              <i class="bi bi-whatsapp" aria-hidden="true"></i>Message owner
              <span class="visually-hidden">(opens in a new tab)</span>
            </a>
            <button
              v-if="canCancel(a)"
              class="btn btn-outline-secondary btn-sm"
              type="button"
              :disabled="busyId === a.appointment_id"
              @click="cancel(a)"
            >
              Cancel<span class="visually-hidden"> viewing of {{ a.property.title }}</span>
            </button>
            <RouterLink
              v-if="a.status === 'declined'"
              class="btn btn-outline-primary btn-sm"
              :to="{ name: 'property-detail', params: { id: a.property.property_id } }"
            >
              Pick another day
            </RouterLink>
          </div>
        </div>
      </li>
    </ul>

    <AppPagination
      v-if="result.meta.value && result.data.value?.length"
      class="mt-4"
      :meta="result.meta.value"
      label="viewing"
    />
  </div>
</template>

<style scoped>
.date-tile {
  text-align: center;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius-lg);
  padding: 0.5rem 1rem;
  min-width: 76px;
}
.thumb {
  width: 120px;
  height: 90px;
  object-fit: cover;
  border-radius: 6px;
}
.min-w-0 {
  min-width: 0;
}
.message {
  overflow-wrap: anywhere;
}
</style>

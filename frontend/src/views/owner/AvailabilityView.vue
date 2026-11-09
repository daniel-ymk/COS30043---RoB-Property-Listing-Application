<script setup>
import { ref, computed, nextTick, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { listMySlots, addSlot, deleteSlot } from '@/api/viewings'
import { useAsync } from '@/composables/useAsync'
import { useToastStore } from '@/stores/toast'
import { fmtDate, fmtTime, isoDate } from '@/utils/format'
import ErrorAlert from '@/components/ErrorAlert.vue'

const MONTHS_AHEAD = 5 // the calendar shows this month and the next 5
const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

const toast = useToastStore()
const today = isoDate()
const now = new Date()
const monthOffset = ref(0)

const result = useAsync(async () => ({ data: await listMySlots() }))
const slots = ref([])
const byDate = computed(() => Object.fromEntries(slots.value.map((s) => [s.viewing_date, s])))

const date = ref('')
const time = ref('14:00')
const dateInput = ref(null)
const formError = ref('') // client check or 409 from the server
const sending = ref(false)

const month = computed(() => new Date(now.getFullYear(), now.getMonth() + monthOffset.value, 1))
const monthTitle = computed(() =>
  month.value.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' }),
)
const maxDate = computed(() =>
  isoDate(new Date(now.getFullYear(), now.getMonth() + MONTHS_AHEAD + 1, 0)),
)

// Day cells for the shown month, Monday first; null = blank before day 1
const cells = computed(() => {
  const first = month.value
  const blanks = (first.getDay() + 6) % 7
  const days = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
  const list = Array(blanks).fill(null)
  for (let d = 1; d <= days; d++) {
    const iso = isoDate(new Date(first.getFullYear(), first.getMonth(), d))
    const slot = byDate.value[iso]
    const past = iso < today
    list.push({
      day: d,
      iso,
      slot,
      past,
      kind: past ? 'past' : slot ? (slot.is_booked ? 'booked' : 'free') : '',
    })
  }
  return list
})

const upcoming = computed(() => slots.value.filter((s) => s.viewing_date >= today))

function cellLabel(cell) {
  const when = fmtDate(cell.iso, { weekday: 'long', day: 'numeric', month: 'long' })
  if (cell.past) return `${when}, past`
  if (!cell.slot) return `${when}, no viewing. Choose to add one.`
  const at = fmtTime(cell.slot.viewing_time)
  return cell.slot.is_booked
    ? `${when}, booked at ${at}. Open the request.`
    : `${when}, free at ${at}`
}

// Clicking a day fills the form so the owner only has to pick a time
async function pickDay(cell) {
  date.value = cell.iso
  formError.value = ''
  await nextTick()
  dateInput.value?.focus()
}

async function load() {
  await result.run()
  slots.value = result.data.value ?? []
}

function check() {
  if (!date.value || date.value < today) return 'Pick today or a later date'
  if (date.value > maxDate.value) return `Pick a date up to ${fmtDate(maxDate.value)}`
  if (!time.value || time.value < '08:00' || time.value > '20:00') {
    return 'Pick a time between 8:00 AM and 8:00 PM'
  }
  return ''
}

async function add(viewingDate = date.value, viewingTime = time.value, { quiet = false } = {}) {
  formError.value = quiet ? '' : check()
  if (formError.value) return
  sending.value = true
  try {
    const slot = await addSlot(viewingDate, viewingTime)
    slots.value = [...slots.value, slot].sort((a, b) =>
      a.viewing_date.localeCompare(b.viewing_date),
    )
    toast.show(`Viewing day added: ${fmtDate(slot.viewing_date)}`, { icon: 'calendar-plus' })
    if (!quiet) date.value = ''
  } catch (err) {
    if (err.status === 409) {
      const taken = byDate.value[viewingDate]
      formError.value = taken
        ? `You already have a viewing on this day (${fmtDate(viewingDate)}, ${fmtTime(taken.viewing_time)}). Pick another date.`
        : err.message
    } else {
      formError.value = Object.values(err.fields ?? {})[0] ?? err.message
    }
  } finally {
    sending.value = false
  }
}

async function remove(slot) {
  try {
    await deleteSlot(slot.slot_id)
    slots.value = slots.value.filter((s) => s.slot_id !== slot.slot_id)
    toast.show(`Removed ${fmtDate(slot.viewing_date)}`, {
      icon: 'calendar-x',
      delay: 6000,
      action: {
        label: 'Undo',
        run: () => add(slot.viewing_date, slot.viewing_time, { quiet: true }),
      },
    })
  } catch (err) {
    toast.error(err.message)
    if (err.status === 409) load() // it was booked meanwhile
  }
}

onMounted(load)
</script>

<template>
  <div class="container">
    <div class="page-head">
      <h1 class="h2 mb-1">Viewing days</h1>
      <p class="text-muted mb-0">
        Pick the days you can show your properties. Renters book one of these days; one viewing per
        day, across all your listings.
      </p>
    </div>

    <ErrorAlert
      v-if="result.error.value"
      what="your viewing days"
      :error="result.error.value"
      @retry="load"
    />

    <div v-else class="row g-4">
      <section class="col-lg-8" aria-labelledby="cal-title">
        <div class="panel">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <button
              class="btn btn-outline-secondary btn-icon"
              type="button"
              aria-label="Previous month"
              :disabled="monthOffset === 0"
              @click="monthOffset--"
            >
              <i class="bi bi-chevron-left" aria-hidden="true"></i>
            </button>
            <h2 id="cal-title" class="h5 mb-0" aria-live="polite">{{ monthTitle }}</h2>
            <button
              class="btn btn-outline-secondary btn-icon"
              type="button"
              aria-label="Next month"
              :disabled="monthOffset === MONTHS_AHEAD"
              @click="monthOffset++"
            >
              <i class="bi bi-chevron-right" aria-hidden="true"></i>
            </button>
          </div>

          <div
            v-if="result.loading.value && !slots.length"
            class="skeleton"
            style="height: 320px"
          ></div>
          <div v-else class="cal" role="group" aria-labelledby="cal-title">
            <div v-for="d in WEEKDAYS" :key="d" class="dow" aria-hidden="true">{{ d }}</div>
            <template v-for="(cell, i) in cells" :key="cell?.iso ?? `blank-${i}`">
              <div v-if="!cell" class="empty"></div>
              <RouterLink
                v-else-if="cell.kind === 'booked'"
                class="day booked"
                :to="{ name: 'owner-requests', query: { status: 'all' } }"
                :aria-label="cellLabel(cell)"
              >
                {{ cell.day }}<small>Booked</small>
              </RouterLink>
              <button
                v-else
                class="day"
                :class="[cell.kind, { today: cell.iso === today, picked: cell.iso === date }]"
                type="button"
                :disabled="cell.past"
                :aria-label="cellLabel(cell)"
                :aria-pressed="cell.iso === date ? 'true' : 'false'"
                @click="pickDay(cell)"
              >
                {{ cell.day }}<small v-if="cell.slot">{{ fmtTime(cell.slot.viewing_time) }}</small>
              </button>
            </template>
          </div>

          <div class="d-flex flex-wrap gap-3 mt-3 small text-muted">
            <span><span class="key free"></span>Free for viewings</span>
            <span><span class="key booked"></span>Booked</span>
            <span><span class="key past"></span>Past</span>
          </div>
        </div>
      </section>

      <aside class="col-lg-4 d-grid gap-3 align-content-start">
        <form class="panel" novalidate aria-labelledby="add-title" @submit.prevent="add()">
          <h2 id="add-title" class="h5">Add a viewing day</h2>
          <div v-if="formError" class="alert alert-warning small d-flex gap-2" role="alert">
            <i class="bi bi-exclamation-triangle" aria-hidden="true"></i>
            <div>{{ formError }}</div>
          </div>
          <div class="mb-3">
            <label class="form-label" for="slot-date">Date</label>
            <input
              id="slot-date"
              ref="dateInput"
              v-model="date"
              class="form-control"
              type="date"
              :min="today"
              :max="maxDate"
            />
          </div>
          <div class="mb-3">
            <label class="form-label" for="slot-time">Time</label>
            <input
              id="slot-time"
              v-model="time"
              class="form-control"
              type="time"
              min="08:00"
              max="20:00"
              step="900"
              aria-describedby="slot-time-help"
            />
            <div id="slot-time-help" class="form-text">Between 8:00 AM and 8:00 PM.</div>
          </div>
          <button class="btn btn-primary w-100" type="submit" :disabled="sending">
            <i class="bi bi-plus-lg" aria-hidden="true"></i>Add day
          </button>
        </form>

        <div class="panel">
          <h2 class="h5">Upcoming days</h2>
          <p v-if="!upcoming.length" class="text-muted small mb-0">
            No days yet. Renters can only book days you add here.
          </p>
          <ul v-else class="list-unstyled mb-0 d-grid gap-2">
            <li
              v-for="slot in upcoming"
              :key="slot.slot_id"
              class="d-flex justify-content-between align-items-center border rounded-3 px-3 py-2"
            >
              <div>
                <div class="fw-semibold">
                  {{
                    fmtDate(slot.viewing_date, { weekday: 'short', day: 'numeric', month: 'short' })
                  }}
                </div>
                <div class="small text-muted">{{ fmtTime(slot.viewing_time) }}</div>
              </div>
              <RouterLink
                v-if="slot.is_booked"
                class="badge-status status-confirmed text-decoration-none"
                :to="{ name: 'owner-requests', query: { status: 'all' } }"
              >
                Booked
              </RouterLink>
              <button
                v-else
                class="btn btn-outline-danger btn-sm"
                type="button"
                :aria-label="`Remove ${fmtDate(slot.viewing_date)}`"
                @click="remove(slot)"
              >
                <i class="bi bi-trash3" aria-hidden="true"></i>
              </button>
            </li>
          </ul>
        </div>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.cal {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 3px;
}
.dow {
  text-align: center;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--rob-muted);
  padding-bottom: 0.25rem;
}
.day {
  min-height: 44px;
  min-width: 0;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius);
  padding: 0.25rem;
  font-weight: 600;
  background: #fff;
  color: var(--rob-ink);
  text-decoration: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
}
.day:hover:not(:disabled) {
  border-color: var(--rob-primary);
}
.day.today {
  box-shadow: inset 0 0 0 2px var(--rob-ink);
}
.day.picked {
  box-shadow: inset 0 0 0 2px var(--rob-primary);
}
.day.past,
.day:disabled {
  color: #94a3b8;
  background: var(--rob-surface);
}
.day.free {
  background: var(--rob-primary-subtle);
  border-color: var(--rob-primary);
  color: var(--rob-primary-hover);
}
.day.booked {
  background: var(--rob-sale-subtle);
  border-color: var(--rob-sale);
  color: #075985;
}
/* phones: a dot instead of the time */
.day small {
  display: block;
  font-size: 0;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
  overflow: hidden;
}
.empty {
  visibility: hidden;
}
.key {
  display: inline-block;
  width: 14px;
  height: 14px;
  border-radius: 4px;
  margin-right: 0.35rem;
  vertical-align: middle;
  border: 1px solid var(--rob-line);
  background: var(--rob-surface);
}
.key.free {
  background: var(--rob-primary-subtle);
  border-color: var(--rob-primary);
}
.key.booked {
  background: var(--rob-sale-subtle);
  border-color: var(--rob-sale);
}
@media (min-width: 576px) {
  .cal {
    gap: 6px;
  }
  .day {
    aspect-ratio: 1 / 0.8;
    min-height: 56px;
    padding: 0.375rem 0.5rem;
    align-items: flex-start;
  }
  .day small {
    width: auto;
    height: auto;
    background: none;
    font-size: 0.6875rem;
    font-weight: 500;
  }
}
</style>

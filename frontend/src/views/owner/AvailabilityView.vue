<script setup>
// Owner's "Viewing days" page. Data flow:
//   API (listMySlots) -> slots -> events -> calendarOptions -> <FullCalendar>
//   -> owner clicks a day -> form -> API -> slots changes -> the calendar redraws
import { ref, computed, nextTick, onMounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
// FullCalendar's official Vue 3 component (v7). It is configured through one prop, `options`.
import FullCalendar from '@fullcalendar/vue3'
import classicThemePlugin from '@fullcalendar/vue3/themes/classic' // the look (theme)
import dayGridPlugin from '@fullcalendar/vue3/daygrid' // the month view
import interactionPlugin from '@fullcalendar/vue3/interaction' // makes dateClick work
// Theme CSS: without these files the calendar shows as an unstyled list of dates
import '@fullcalendar/vue3/skeleton.css'
import '@fullcalendar/vue3/themes/classic/theme.css'
import '@fullcalendar/vue3/themes/classic/palette.css'
import { listMySlots, addSlot, deleteSlot } from '@/api/viewings'
import { useAsync } from '@/composables/useAsync'
import { useToastStore } from '@/stores/toast'
import { fmtDate, fmtTime, isoDate } from '@/utils/format'
import ErrorAlert from '@/components/ErrorAlert.vue'

const MONTHS_AHEAD = 3 // owners can add days up to the end of the 3rd month from now

const router = useRouter()
const toast = useToastStore()
const today = isoDate()
const now = new Date()

const result = useAsync(async () => ({ data: await listMySlots() }))
const slots = ref([])
const byDate = computed(() => Object.fromEntries(slots.value.map((s) => [s.viewing_date, s])))

const date = ref('')
const time = ref('14:00')
const dateInput = ref(null)
const formError = ref('') // client check or 409 from the server
const sending = ref(false)

// First day the calendar shows, the last day the owner may pick, and the day after it
// (FullCalendar's range end is exclusive)
const monthStart = isoDate(new Date(now.getFullYear(), now.getMonth(), 1))
const maxDate = computed(() =>
  isoDate(new Date(now.getFullYear(), now.getMonth() + MONTHS_AHEAD + 1, 0)),
)
const rangeEnd = computed(() =>
  isoDate(new Date(now.getFullYear(), now.getMonth() + MONTHS_AHEAD + 1, 1)),
)

const upcoming = computed(() => slots.value.filter((s) => s.viewing_date >= today))

// ---------- FullCalendar ----------

// Each viewing day becomes one calendar event. The slot rides along in
// extendedProps so the click handler and the eventContent slot can read it.
const events = computed(() =>
  slots.value.map((slot) => ({
    id: String(slot.slot_id),
    start: `${slot.viewing_date}T${slot.viewing_time}`,
    title: slot.is_booked ? 'Booked' : 'Free',
    className: slot.is_booked ? 'slot-booked' : 'slot-free', // coloured in <style>
    extendedProps: { slot },
  })),
)

// All of FullCalendar's settings, passed as <FullCalendar :options="calendarOptions">.
// computed, so FullCalendar re-renders whenever `slots` changes (add, remove, undo)
const calendarOptions = computed(() => ({
  plugins: [classicThemePlugin, dayGridPlugin, interactionPlugin],
  initialView: 'dayGridMonth',
  firstDay: 1, // weeks start on Monday
  height: 'auto',
  fixedWeekCount: false,
  headerToolbar: { start: 'prev', center: 'title', end: 'next' }, // v7 shows none by default
  // Prev/next stop at this month and at maxDate; days outside the range are disabled
  validRange: { start: monthStart, end: rangeEnd.value },
  // Earlier days this month stay visible (greyed) but can't be picked
  dayCellClass: (info) => (info.isPast ? 'is-past' : ''),
  eventDisplay: 'block', // a filled box instead of a dot
  events: events.value,
  // Callbacks FullCalendar calls when the owner clicks
  dateClick: onDateClick, // needs interactionPlugin
  eventClick: onEventClick,
}))

// Clicking an empty day (or a free one) fills the form so the owner only picks a time.
// info.dateStr is the clicked day as "YYYY-MM-DD".
function onDateClick(info) {
  if (info.dateStr < today) return
  if (byDate.value[info.dateStr]?.is_booked) openRequests()
  else pickDay(info.dateStr)
}

// Clicking an event: info.event.extendedProps.slot is the slot we attached above
function onEventClick(info) {
  const { slot } = info.event.extendedProps
  if (slot.is_booked) openRequests()
  else pickDay(slot.viewing_date)
}

// A booked day belongs to a viewing request, so open the Requests page
function openRequests() {
  router.push({ name: 'owner-requests', query: { status: 'all' } })
}

// Put the chosen day in the form's date box and move the cursor there (after Vue updates the page)
async function pickDay(iso) {
  date.value = iso
  formError.value = ''
  await nextTick()
  dateInput.value?.focus()
}

// ---------- data ----------

// Fetch the owner's days (GET /me/slots); the calendar and the list update from `slots`
async function load() {
  await result.run()
  slots.value = result.data.value ?? []
}

// Browser-side form check: returns an error message, or '' if the date and time are valid.
// The PHP API checks the same rules again.
function check() {
  if (!date.value || date.value < today) return 'Pick today or a later date'
  if (date.value > maxDate.value) return `Pick a date up to ${fmtDate(maxDate.value)}`
  if (!time.value || time.value < '08:00' || time.value > '20:00') {
    return 'Pick a time between 8:00 AM and 8:00 PM'
  }
  return ''
}

// Save a viewing day (POST /me/slots). The form calls it with its own values; Undo calls it
// with the removed day and quiet: true (no form checks, form left as it is).
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

// Delete a free day (DELETE /me/slots/:id) and offer Undo in the pop-up message
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
          <h2 id="cal-title" class="visually-hidden">Calendar of your viewing days</h2>

          <div
            v-if="result.loading.value && !slots.length"
            class="skeleton"
            style="height: 320px"
          ></div>
          <div v-else class="availability-cal">
            <!-- The FullCalendar component: every setting and event comes in through :options -->
            <FullCalendar :options="calendarOptions">
              <!-- Vue named slot: how each viewing day is drawn inside its date cell.
                   FullCalendar passes `arg` for each event; arg.event.extendedProps.slot is
                   our slot data. -->
              <template #eventContent="arg">
                <span class="slot-pill">
                  <i
                    class="bi"
                    :class="arg.event.extendedProps.slot.is_booked ? 'bi-person-check' : 'bi-clock'"
                    aria-hidden="true"
                  ></i>
                  <span class="slot-time">{{
                    fmtTime(arg.event.extendedProps.slot.viewing_time)
                  }}</span>
                  <span class="slot-label">{{ arg.event.title }}</span>
                </span>
              </template>
            </FullCalendar>
          </div>

          <div class="d-flex flex-wrap gap-3 mt-3 small text-muted">
            <span><span class="key free"></span>Free for viewings</span>
            <span><span class="key booked"></span>Booked (opens the request)</span>
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
/* Map FullCalendar's classic theme onto the RoB colours. The theme reads these
   CSS variables, and custom properties inherit, so setting them here is enough. */
.availability-cal {
  --fc-classic-primary: var(--rob-primary);
  --fc-classic-button: var(--rob-primary);
  --fc-classic-button-border: var(--rob-primary);
  --fc-classic-button-strong: var(--rob-primary-hover);
  --fc-classic-button-strong-border: var(--rob-primary-hover);
  --fc-classic-today: color-mix(in srgb, var(--rob-primary-subtle) 45%, transparent);
  --fc-classic-border: var(--rob-line);
  --fc-classic-foreground: var(--rob-ink);
  --fc-classic-muted-foreground: var(--rob-muted);
}

/* Events are rendered by FullCalendar, outside this component's scope, so use :deep() */
.availability-cal :deep(.slot-free) {
  --fc-classic-event: var(--rob-primary-subtle);
  --fc-classic-event-contrast: var(--rob-primary-hover);
  border: 1px solid var(--rob-primary);
  cursor: pointer;
}
.availability-cal :deep(.is-past) {
  background: var(--rob-surface);
  color: #94a3b8;
  cursor: not-allowed;
}
.availability-cal :deep(.slot-booked) {
  --fc-classic-event: var(--rob-sale-subtle);
  --fc-classic-event-contrast: #075985;
  border: 1px solid var(--rob-sale);
  cursor: pointer;
}

.slot-pill {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.125rem 0.25rem;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
}
/* Phones show only the icon, wider screens add the time, the widest add "Free"/"Booked".
   Hidden text stays readable by screen readers (same idea as Bootstrap's .visually-hidden). */
.slot-time,
.slot-label {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}
@media (min-width: 576px) {
  .slot-time {
    position: static;
    width: auto;
    height: auto;
    clip: auto;
  }
}
@media (min-width: 1400px) {
  .slot-label {
    position: static;
    width: auto;
    height: auto;
    clip: auto;
    font-weight: 400;
  }
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
</style>

<script setup>
import { ref, computed, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { listPropertySlots, bookViewing } from '@/api/viewings'
import { useAsync } from '@/composables/useAsync'
import { useToastStore } from '@/stores/toast'
import { fmtDate, fmtTime } from '@/utils/format'

// "Book a viewing" on the property page: pick one of the owner's free days.
const props = defineProps({
  propertyId: { type: Number, required: true },
})

const MAX_MESSAGE = 500
const toast = useToastStore()

const slots = ref([])
const loader = useAsync(async () => ({ data: await listPropertySlots(props.propertyId) }))
const slotId = ref(null)
const message = ref('')
const sending = ref(false)
const problem = ref('') // 409 / 422 from the server, shown above the button
const booked = ref(null) // the appointment once requested

const tooLong = computed(() => message.value.length > MAX_MESSAGE)

async function loadSlots() {
  await loader.run()
  slots.value = loader.data.value ?? []
  if (!slots.value.some((s) => s.slot_id === slotId.value))
    slotId.value = slots.value[0]?.slot_id ?? null
}

async function submit() {
  problem.value = ''
  if (!slotId.value) {
    problem.value = 'Pick a viewing day'
    return
  }
  if (tooLong.value) return
  sending.value = true
  try {
    booked.value = await bookViewing(slotId.value, props.propertyId, message.value.trim())
    toast.show('Viewing requested. The owner will confirm soon.', { icon: 'calendar-check' })
  } catch (err) {
    // Someone booked the day first, or it already has a booking of yours
    problem.value = Object.values(err.fields ?? {})[0] ?? err.message
    if (err.status === 409) loadSlots()
  } finally {
    sending.value = false
  }
}

watch(
  () => props.propertyId,
  () => {
    booked.value = null
    message.value = ''
    loadSlots()
  },
  { immediate: true },
)
</script>

<template>
  <div v-if="booked" class="booked" role="status">
    <i class="bi bi-calendar-check fs-3 text-primary" aria-hidden="true"></i>
    <div>
      <div class="fw-semibold">Viewing requested</div>
      <div class="small text-muted">
        {{ fmtDate(booked.viewing_date) }} at {{ fmtTime(booked.viewing_time) }}. The owner will
        confirm or decline it.
      </div>
      <RouterLink class="small fw-semibold" :to="{ name: 'appointments' }"
        >See my viewings</RouterLink
      >
    </div>
  </div>

  <form v-else novalidate aria-labelledby="book-title" @submit.prevent="submit">
    <h2 id="book-title" class="h5 mb-1">Book a viewing</h2>
    <p class="text-muted small mb-3">Pick one of the owner's free days.</p>

    <div v-if="loader.loading.value && !slots.length" class="slot-grid mb-3" aria-busy="true">
      <div v-for="n in 3" :key="n" class="skeleton" style="height: 64px"></div>
    </div>
    <div v-else-if="loader.error.value" class="alert alert-danger small">
      We couldn't load the free days.
      <button class="btn btn-link btn-sm p-0 align-baseline" type="button" @click="loadSlots">
        Try again
      </button>
    </div>
    <p v-else-if="!slots.length" class="panel-surface small mb-3 p-3">
      <i class="bi bi-calendar-x me-1" aria-hidden="true"></i>No free days right now. Message the
      owner on WhatsApp to arrange a time.
    </p>
    <fieldset v-else class="mb-3">
      <legend class="visually-hidden">Viewing day</legend>
      <div class="slot-grid">
        <template v-for="slot in slots.slice(0, 9)" :key="slot.slot_id">
          <input
            :id="`slot-${slot.slot_id}`"
            v-model="slotId"
            type="radio"
            class="btn-check"
            name="slot"
            :value="slot.slot_id"
          />
          <label class="btn btn-outline-secondary" :for="`slot-${slot.slot_id}`">
            <span>{{
              fmtDate(slot.viewing_date, { weekday: 'short', day: 'numeric', month: 'short' })
            }}</span>
            <small>{{ fmtTime(slot.viewing_time) }}</small>
          </label>
        </template>
      </div>
    </fieldset>

    <template v-if="slots.length">
      <label class="form-label" for="book-message">
        Message <span class="text-muted fw-normal">(optional)</span>
      </label>
      <textarea
        id="book-message"
        v-model="message"
        class="form-control"
        :class="{ 'is-invalid': tooLong }"
        rows="3"
        placeholder="Hi, I'd like to view this home."
        aria-describedby="book-count"
      ></textarea>
      <div id="book-count" class="form-text mb-3 text-end" :class="{ 'text-danger': tooLong }">
        {{ message.length }} / {{ MAX_MESSAGE }}
      </div>

      <div v-if="problem" class="alert alert-warning small d-flex gap-2" role="alert">
        <i class="bi bi-exclamation-triangle" aria-hidden="true"></i>
        <div>{{ problem }}</div>
      </div>
      <button class="btn btn-primary w-100" type="submit" :disabled="sending || tooLong">
        <span v-if="sending" class="spinner-border spinner-border-sm" aria-hidden="true"></span>
        {{ sending ? 'Requesting…' : 'Request viewing' }}
      </button>
    </template>
  </form>
</template>

<style scoped>
.slot-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(92px, 1fr));
  gap: 0.5rem;
}
.slot-grid .btn {
  flex-direction: column;
  gap: 0;
  min-height: 64px;
  line-height: 1.2;
}
.slot-grid .btn small {
  font-weight: 400;
  font-size: 0.75rem;
}
.slot-grid .btn-check:checked + .btn {
  background: var(--rob-primary);
  border-color: var(--rob-primary);
  color: #fff;
}
.booked {
  display: flex;
  gap: 0.75rem;
  padding: 1rem;
  border-radius: var(--rob-radius);
  background: var(--rob-primary-subtle);
}
</style>

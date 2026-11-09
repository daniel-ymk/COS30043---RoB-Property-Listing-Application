<script setup>
import { ref, computed, nextTick, onBeforeUnmount } from 'vue'
import {
  PHOTO_TYPES,
  MAX_PHOTO_BYTES,
  MAX_PHOTOS,
  MAX_RAW_BYTES,
  reorderPhotos,
  deletePhoto,
  updatePhoto,
} from '@/api/images'
import { useFileUpload } from '@/composables/useFileUpload'
import { ROOM_LABELS, fileSize } from '@/utils/format'

// Photo manager for creating or editing a listing. v-model is the ordered
// list of photos; the first one that isn't hidden is the cover.
//   saved: { key, image_id, url, caption, room_tag, is_hidden }
//   new:   { key, image_id: null, url (local preview), caption, room_tag, is_hidden }
// New files are compressed as soon as they're added (useFileUpload); the
// parent saves everything with photoManager.sync(propertyId, savedImages).
const photos = defineModel({ type: Array, required: true })
const props = defineProps({
  max: { type: Number, default: MAX_PHOTOS },
  error: { type: String, default: '' },
})

const files = useFileUpload({ maxBytes: MAX_PHOTO_BYTES })
const rejected = ref([]) // files refused before upload: [{ key, name, reason }]
const dropActive = ref(false)
const announcement = ref('') // read out by screen readers after moves
const dragKey = ref(null) // photo being dragged with a pointer (mouse, touch, pen)
const grabbed = ref(null) // photo picked up with the keyboard: { key, from }
const gripRefs = {}
let nextKey = 1

const left = computed(() => props.max - photos.value.length)
const coverKey = computed(() => photos.value.find((p) => !p.is_hidden)?.key ?? null)
const hiddenCount = computed(() => photos.value.filter((p) => p.is_hidden).length)

// "kitchen-2.jpg" -> kitchen: a head start on the room tag
const NAME_HINTS = [
  ['kitchen', 'kitchen'],
  ['bath', 'bathroom'],
  ['toilet', 'bathroom'],
  ['bed', 'bedroom'],
  ['living', 'living'],
  ['lounge', 'living'],
  ['dining', 'dining'],
  ['balcony', 'balcony'],
  ['front', 'exterior'],
  ['outside', 'exterior'],
  ['exterior', 'exterior'],
]
function guessRoom(name) {
  const lower = name.toLowerCase()
  return NAME_HINTS.find(([hint]) => lower.includes(hint))?.[1] ?? ''
}

function say(message) {
  announcement.value = ''
  nextTick(() => (announcement.value = message))
}

// ---------- adding files ----------

function addFiles(fileList) {
  const added = []
  for (const file of fileList) {
    const key = `new-${nextKey++}`
    if (!PHOTO_TYPES.includes(file.type)) {
      rejected.value.push({ key, name: file.name, reason: 'Only JPEG, PNG or WebP' })
    } else if (file.size > MAX_RAW_BYTES) {
      rejected.value.push({
        key,
        name: file.name,
        reason: `Larger than ${fileSize(MAX_RAW_BYTES)}`,
      })
    } else if (photos.value.length + added.length >= props.max) {
      rejected.value.push({ key, name: file.name, reason: `Only ${props.max} photos allowed` })
    } else {
      // Instant preview from the original file; compression runs meanwhile
      added.push({
        key,
        image_id: null,
        url: URL.createObjectURL(file),
        caption: '',
        room_tag: guessRoom(file.name),
        is_hidden: false,
      })
      files.prepare(key, file)
    }
  }
  photos.value = [...photos.value, ...added]
  if (added.length) say(`${added.length} ${added.length === 1 ? 'photo' : 'photos'} added`)
}

function onPick(event) {
  addFiles(event.target.files)
  event.target.value = '' // picking the same file again still fires change
}

function onDropFiles(event) {
  dropActive.value = false
  if (event.dataTransfer?.files?.length) addFiles(event.dataTransfer.files)
}

// ---------- editing ----------
// Every change builds one new list and assigns it once: with defineModel,
// photos.value keeps returning the parent's old array until it re-renders,
// so a second change in the same tick must not read it again.

function update(index, changes) {
  const list = [...photos.value]
  list[index] = { ...list[index], ...changes }
  photos.value = list
}

function remove(index) {
  const list = [...photos.value]
  const [gone] = list.splice(index, 1)
  if (!gone.image_id) {
    URL.revokeObjectURL(gone.url)
    files.forget(gone.key)
  }
  photos.value = list
  say(`Photo removed. ${list.length} left.`)
}

function move(from, to) {
  if (to < 0 || to >= photos.value.length || from === to) return false
  const list = [...photos.value]
  const [item] = list.splice(from, 1)
  list.splice(to, 0, item)
  photos.value = list
  return true
}

// The cover is the first shown photo, so "set as cover" moves it to the
// front (and shows it, if it was hidden)
function makeCover(index) {
  const list = [...photos.value]
  const [item] = list.splice(index, 1)
  photos.value = [{ ...item, is_hidden: false }, ...list]
  say('Photo moved to the front. It is now the cover.')
}

function toggleHidden(index) {
  const hide = !photos.value[index].is_hidden
  update(index, { is_hidden: hide })
  say(hide ? 'Photo hidden from the public' : 'Photo shown to the public')
}

// ---------- reordering: pointer (mouse, touch, pen) ----------

// The rest of the drag is followed on window, not the handle: when Vue
// moves the card in the DOM the handle loses its pointer capture, and its
// own pointermove events would stop (most noticeable with touch).
function onGripPointerDown(index, event) {
  if (event.button !== 0) return
  event.preventDefault() // no text selection or native drag while dragging
  // preventDefault also stops the click from focusing the handle, so focus it
  // here: then "click the handle, press Space, use the arrows" works too
  event.currentTarget.focus({ preventScroll: true })
  dragKey.value = photos.value[index].key
  window.addEventListener('pointermove', onGripPointerMove)
  window.addEventListener('pointerup', onGripPointerUp)
  window.addEventListener('pointercancel', onGripPointerUp)
}

function onGripPointerMove(event) {
  if (!dragKey.value) return
  // The card under the finger or cursor takes the dragged photo's place
  const target = document
    .elementFromPoint(event.clientX, event.clientY)
    ?.closest('[data-photo-key]')
  if (!target) return
  const from = photos.value.findIndex((p) => p.key === dragKey.value)
  const to = photos.value.findIndex((p) => p.key === target.dataset.photoKey)
  if (to !== -1) move(from, to)
}

function onGripPointerUp() {
  window.removeEventListener('pointermove', onGripPointerMove)
  window.removeEventListener('pointerup', onGripPointerUp)
  window.removeEventListener('pointercancel', onGripPointerUp)
  if (!dragKey.value) return
  const at = photos.value.findIndex((p) => p.key === dragKey.value)
  dragKey.value = null
  say(`Photo dropped in place ${at + 1}${at === 0 ? ', the cover' : ''}.`)
}

// ---------- reordering: keyboard ----------
// Space or Enter picks the photo up, arrows move it, Space or Enter drops
// it, Escape puts it back.

async function focusGrip(key) {
  await nextTick()
  gripRefs[key]?.focus()
}

// Moving the focused handle in the DOM blurs it for a moment (focusGrip puts
// focus back), so only drop the photo if focus really went somewhere else
function onGripBlur(key) {
  setTimeout(() => {
    if (grabbed.value?.key === key && document.activeElement !== gripRefs[key]) grabbed.value = null
  })
}

function onGripKeydown(index, event) {
  const key = photos.value[index].key
  if (event.key === ' ' || event.key === 'Enter') {
    event.preventDefault()
    if (grabbed.value) {
      grabbed.value = null
      say(`Photo dropped in place ${index + 1}${index === 0 ? ', the cover' : ''}.`)
    } else {
      grabbed.value = { key, from: index }
      say(
        `Photo ${index + 1} picked up. Use the arrow keys to move it, Space to drop, Escape to cancel.`,
      )
    }
    return
  }
  if (!grabbed.value) return
  const steps = { ArrowLeft: -1, ArrowUp: -1, ArrowRight: 1, ArrowDown: 1 }
  let to = null
  if (event.key in steps) to = index + steps[event.key]
  if (event.key === 'Home') to = 0
  if (event.key === 'End') to = photos.value.length - 1
  if (event.key === 'Escape') {
    to = grabbed.value.from
    grabbed.value = null
  }
  if (to === null) return
  event.preventDefault()
  if (move(index, to)) {
    say(grabbed.value ? `Place ${to + 1} of ${photos.value.length}` : 'Move cancelled.')
    focusGrip(key)
  }
}

// ---------- saving ----------

const DETAIL_FIELDS = ['caption', 'room_tag', 'is_hidden']

// Saves every change for the listing: deletes removed photos, updates
// changed details, uploads new files (2 at a time, each with its own
// progress), then saves the order. Resolves with { failed } = how many
// new photos didn't upload (they stay here, marked, for another try).
async function sync(propertyId, saved = []) {
  const kept = new Set(photos.value.filter((p) => p.image_id).map((p) => p.image_id))
  for (const old of saved) {
    if (!kept.has(old.image_id)) await deletePhoto(old.image_id)
  }

  const savedById = new Map(saved.map((s) => [s.image_id, s]))
  for (const photo of photos.value.filter((p) => p.image_id)) {
    const before = savedById.get(photo.image_id) ?? {}
    const changes = {}
    for (const field of DETAIL_FIELDS) {
      const now = field === 'is_hidden' ? photo[field] : photo[field] || null
      const was = field === 'is_hidden' ? !!before[field] : before[field] || null
      if (now !== was) changes[field] = now
    }
    if (Object.keys(changes).length) await updatePhoto(photo.image_id, changes)
  }

  await Promise.all(photos.value.map((p) => files.stateOf(p.key)?.preparing))
  const jobs = photos.value
    .filter((p) => !p.image_id && ['ready', 'failed'].includes(files.stateOf(p.key)?.status))
    .map((p) => ({
      key: p.key,
      fields: { caption: p.caption.trim(), room_tag: p.room_tag, is_hidden: p.is_hidden },
    }))
  const ids = await files.uploadAll(propertyId, jobs, 2)
  // a local copy: photos.value only shows this after the parent re-renders
  const list = photos.value.map((p) => (ids[p.key] ? { ...p, image_id: ids[p.key] } : p))
  photos.value = list

  const order = list.filter((p) => p.image_id).map((p) => p.image_id)
  if (order.length > 1) await reorderPhotos(propertyId, order)

  return { failed: list.filter((p) => !p.image_id).length }
}

defineExpose({ sync })

onBeforeUnmount(() => {
  onGripPointerUp() // a drag in progress must not leave window listeners behind
  for (const photo of photos.value) if (!photo.image_id) URL.revokeObjectURL(photo.url)
})

function statusOf(photo) {
  return photo.image_id && !files.stateOf(photo.key) ? null : files.stateOf(photo.key)
}
</script>

<template>
  <div class="photo-manager">
    <label
      class="dropzone d-block mb-3"
      :class="{ active: dropActive, disabled: left <= 0 }"
      for="photo-files"
      @dragover.prevent="dropActive = true"
      @dragleave="dropActive = false"
      @drop.prevent="onDropFiles"
    >
      <i class="bi bi-cloud-arrow-up fs-1 text-primary" aria-hidden="true"></i>
      <span class="d-block fw-semibold mt-1">
        Drag photos here or <span class="text-primary text-decoration-underline">browse</span>
      </span>
      <span class="d-block small text-muted">
        JPEG, PNG or WebP · large photos are shrunk before upload · max {{ max }} photos
      </span>
      <input
        id="photo-files"
        type="file"
        class="visually-hidden"
        multiple
        accept="image/jpeg,image/png,image/webp"
        :disabled="left <= 0"
        aria-describedby="photo-help"
        @change="onPick"
      />
    </label>

    <div v-if="error" class="alert alert-danger py-2 small" role="alert">{{ error }}</div>

    <p id="photo-help" class="form-text mt-0 mb-3">
      <i class="bi bi-arrows-move" aria-hidden="true"></i>
      To reorder, drag a photo by its <i class="bi bi-grip-vertical" aria-hidden="true"></i>
      handle. Or click the handle (or Tab to it), press Space to pick the photo up, move it with the
      arrow keys, and press Space again to drop it. The first shown photo is the cover. Hidden
      photos are only visible to you.
      <template v-if="hiddenCount"> {{ hiddenCount }} hidden.</template>
    </p>

    <ul v-if="photos.length || rejected.length" class="photos list-unstyled mb-0">
      <li
        v-for="(photo, i) in photos"
        :key="photo.key"
        class="photo"
        :class="{
          lifted: dragKey === photo.key || grabbed?.key === photo.key,
          hidden: photo.is_hidden,
        }"
        :data-photo-key="photo.key"
      >
        <div class="thumb">
          <img :src="photo.url" :alt="photo.caption || `Photo ${i + 1}`" draggable="false" />
          <span v-if="photo.key === coverKey" class="tag tag-cover">COVER</span>
          <span v-if="photo.is_hidden" class="tag tag-hidden">
            <i class="bi bi-eye-slash" aria-hidden="true"></i> HIDDEN
          </span>

          <!-- Per-file state from useFileUpload -->
          <div v-if="statusOf(photo)" class="state" :class="`is-${statusOf(photo).status}`">
            <template v-if="statusOf(photo).status === 'compressing'">
              <span class="spinner-border spinner-border-sm" aria-hidden="true"></span>
              Compressing…
            </template>
            <template v-else-if="statusOf(photo).status === 'uploading'">
              <div
                class="progress w-100"
                role="progressbar"
                :aria-label="`Uploading photo ${i + 1}`"
                :aria-valuenow="statusOf(photo).progress"
                aria-valuemin="0"
                aria-valuemax="100"
              >
                <div class="progress-bar" :style="{ width: `${statusOf(photo).progress}%` }"></div>
              </div>
              <span class="small">{{ statusOf(photo).progress }}%</span>
            </template>
            <template v-else-if="['failed', 'invalid'].includes(statusOf(photo).status)">
              <i class="bi bi-exclamation-circle" aria-hidden="true"></i>
              {{ statusOf(photo).error }}
            </template>
            <template v-else-if="statusOf(photo).status === 'done'">
              <i class="bi bi-check-circle" aria-hidden="true"></i> Uploaded
            </template>
            <template v-else-if="statusOf(photo).size < statusOf(photo).originalSize">
              {{ fileSize(statusOf(photo).originalSize) }} → {{ fileSize(statusOf(photo).size) }}
            </template>
            <template v-else>{{ fileSize(statusOf(photo).size) }}</template>
          </div>
        </div>

        <div class="details">
          <label class="visually-hidden" :for="`caption-${photo.key}`">
            Caption for photo {{ i + 1 }}
          </label>
          <input
            :id="`caption-${photo.key}`"
            class="form-control form-control-sm"
            :value="photo.caption"
            maxlength="150"
            placeholder="Caption, e.g. Bright corner living room"
            @input="update(i, { caption: $event.target.value })"
          />
          <label class="visually-hidden" :for="`room-${photo.key}`"
            >Room in photo {{ i + 1 }}</label
          >
          <select
            :id="`room-${photo.key}`"
            class="form-select form-select-sm"
            :value="photo.room_tag ?? ''"
            @change="update(i, { room_tag: $event.target.value || null })"
          >
            <option value="">Room…</option>
            <option v-for="(label, value) in ROOM_LABELS" :key="value" :value="value">
              {{ label }}
            </option>
          </select>
        </div>

        <div class="tools">
          <button
            :ref="(el) => (gripRefs[photo.key] = el)"
            class="btn grip"
            type="button"
            :aria-pressed="grabbed?.key === photo.key ? 'true' : 'false'"
            :aria-label="`Reorder photo ${i + 1}`"
            aria-describedby="photo-help"
            @pointerdown="onGripPointerDown(i, $event)"
            @keydown="onGripKeydown(i, $event)"
            @blur="onGripBlur(photo.key)"
          >
            <i class="bi bi-grip-vertical" aria-hidden="true"></i>
          </button>
          <button
            class="btn"
            type="button"
            :disabled="photo.key === coverKey"
            :aria-label="`Set photo ${i + 1} as the cover`"
            title="Set as cover"
            @click="makeCover(i)"
          >
            <i
              class="bi"
              :class="photo.key === coverKey ? 'bi-star-fill' : 'bi-star'"
              aria-hidden="true"
            ></i>
          </button>
          <button
            class="btn"
            type="button"
            :aria-pressed="photo.is_hidden ? 'true' : 'false'"
            :aria-label="`Hide photo ${i + 1} from the public`"
            title="Hide from the public"
            @click="toggleHidden(i)"
          >
            <i
              class="bi"
              :class="photo.is_hidden ? 'bi-eye-slash' : 'bi-eye'"
              aria-hidden="true"
            ></i>
          </button>
          <button
            class="btn text-danger"
            type="button"
            :aria-label="`Remove photo ${i + 1}`"
            title="Remove"
            @click="remove(i)"
          >
            <i class="bi bi-trash3" aria-hidden="true"></i>
          </button>
        </div>
      </li>

      <li v-for="bad in rejected" :key="bad.key" class="photo rejected">
        <span class="small fw-semibold text-truncate">{{ bad.name }}</span>
        <span class="small text-danger mt-1">
          <i class="bi bi-exclamation-circle" aria-hidden="true"></i> {{ bad.reason }}
        </span>
        <button
          class="btn btn-link btn-sm p-0 mt-1 align-self-start"
          type="button"
          @click="rejected = rejected.filter((r) => r.key !== bad.key)"
        >
          Dismiss<span class="visually-hidden"> {{ bad.name }}</span>
        </button>
      </li>
    </ul>
    <p class="visually-hidden" aria-live="polite">{{ announcement }}</p>
  </div>
</template>

<style scoped>
.dropzone {
  border: 2px dashed #94a3b8;
  border-radius: var(--rob-radius-lg);
  padding: 1.5rem 1rem;
  text-align: center;
  background: var(--rob-surface);
  cursor: pointer;
}
.dropzone:hover,
.dropzone.active {
  border-color: var(--rob-primary);
  background: var(--rob-primary-subtle);
}
.dropzone:focus-within {
  outline: 3px solid var(--rob-primary);
  outline-offset: 2px;
}
.dropzone.disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.photos {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 210px), 1fr));
  gap: 0.75rem;
}
.photo {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius);
  background: #fff;
  overflow: hidden;
  transition:
    box-shadow 0.15s,
    transform 0.15s;
}
.photo.lifted {
  box-shadow: var(--rob-shadow-hover);
  transform: scale(1.02);
  border-color: var(--rob-primary);
  position: relative;
  z-index: 2;
}
.photo.hidden .thumb img {
  opacity: 0.45;
}
.thumb {
  position: relative;
  aspect-ratio: 4 / 3;
  overflow: hidden;
  background: var(--rob-surface);
}
/* absolute, so a portrait photo can't stretch the 4:3 frame */
.thumb img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  user-select: none;
}
.tag {
  position: absolute;
  top: 6px;
  font-size: 0.6875rem;
  font-weight: 700;
  border-radius: 4px;
  padding: 0.1rem 0.4rem;
  color: #fff;
}
.tag-cover {
  left: 6px;
  background: var(--rob-ink);
}
.tag-hidden {
  right: 6px;
  background: #92400e;
}
.state {
  position: absolute;
  inset: auto 0 0 0;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.35rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
  color: #fff;
  background: rgb(15 23 42 / 0.7);
}
.state .progress {
  height: 6px;
}
.state.is-failed,
.state.is-invalid {
  background: #991b1b;
}
.state.is-done {
  background: var(--rob-success);
}
.details {
  display: grid;
  gap: 0.375rem;
  padding: 0.5rem;
}
.tools {
  display: flex;
  justify-content: space-between;
  border-top: 1px solid var(--rob-line);
}
.tools .btn {
  flex: 1;
  min-height: 44px;
  border: 0;
  border-radius: 0;
  color: var(--rob-ink);
}
.tools .btn:hover:not(:disabled) {
  background: var(--rob-surface);
}
.tools .btn:disabled {
  color: var(--rob-primary);
  opacity: 1;
}
.tools .btn.text-danger {
  color: #b91c1c;
}
/* The handle takes touch gestures itself, so dragging doesn't scroll */
.grip {
  cursor: grab;
  touch-action: none;
}
.grip[aria-pressed='true'] {
  background: var(--rob-primary-subtle);
  color: var(--rob-primary-hover);
}
.lifted .grip {
  cursor: grabbing;
}
.rejected {
  justify-content: center;
  padding: 0.75rem;
  border-color: var(--rob-danger);
  min-height: 120px;
}
@media (prefers-reduced-motion: reduce) {
  .photo {
    transition: none;
  }
  .photo.lifted {
    transform: none;
  }
}
</style>

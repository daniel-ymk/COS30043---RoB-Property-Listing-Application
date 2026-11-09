<script setup>
import { ref, computed, onBeforeUnmount } from 'vue'
import { imageUrl } from '@/api/client'
import { ROOM_LABELS } from '@/utils/format'

// The listing's photos as the owner arranged them in the photo manager:
// a mosaic (5, 3 or 1 tiles) and a full-screen viewer on the native
// <dialog>, which gives focus trapping and Esc-to-close for free.
// Hidden photos never show here, even to the owner (this is the public view).
// Captions are the alt text; room tags label the tiles and filter the viewer.
const props = defineProps({
  images: { type: Array, required: true }, // Image objects (docs/api.md §2)
  title: { type: String, required: true },
})

const dialog = ref(null)
const current = ref(0)
const room = ref('') // viewer filter, '' = all rooms

const shown = computed(() =>
  props.images
    .filter((img) => !img.is_hidden)
    .map((img, i) => ({
      ...img,
      url: imageUrl(img.file_path),
      // alt text: the owner's caption, else the room, else the position
      alt: img.caption || (img.room_tag ? ROOM_LABELS[img.room_tag] : `Photo ${i + 1}`),
    })),
)
const tiles = computed(() => {
  const n = shown.value.length
  return shown.value.slice(0, n >= 5 ? 5 : n >= 3 ? 3 : 1)
})
const layout = computed(() =>
  tiles.value.length === 5 ? '' : tiles.value.length === 3 ? 'g3' : 'g1',
)

// Rooms with photos, for the viewer's filter chips: [{ value, label, count }]
const rooms = computed(() => {
  const counts = {}
  for (const img of shown.value)
    if (img.room_tag) counts[img.room_tag] = (counts[img.room_tag] ?? 0) + 1
  return Object.keys(ROOM_LABELS)
    .filter((value) => counts[value])
    .map((value) => ({ value, label: ROOM_LABELS[value], count: counts[value] }))
})
const inView = computed(() =>
  room.value ? shown.value.filter((img) => img.room_tag === room.value) : shown.value,
)
const photo = computed(() => inView.value[current.value])

function open(index = 0) {
  room.value = ''
  current.value = index
  dialog.value.showModal()
}

function step(delta) {
  const n = inView.value.length
  current.value = (current.value + delta + n) % n
}

function pickRoom(value) {
  room.value = value
  current.value = 0
}

function onKey(event) {
  if (event.key === 'ArrowRight') step(1)
  if (event.key === 'ArrowLeft') step(-1)
}

// Clicking the dark backdrop (the dialog itself, not its content) closes it
function onDialogClick(event) {
  if (event.target === dialog.value) dialog.value.close()
}

onBeforeUnmount(() => dialog.value?.open && dialog.value.close())
</script>

<template>
  <div class="photo-gallery">
    <div v-if="!shown.length" class="gallery-empty">
      <i class="bi bi-image" aria-hidden="true"></i>
      <span>No photos yet</span>
    </div>
    <div v-else class="gallery" :class="layout">
      <button
        v-for="(img, i) in tiles"
        :key="img.image_id"
        type="button"
        class="tile"
        :aria-label="`Open photo ${i + 1} of ${shown.length}: ${img.alt}`"
        @click="open(i)"
      >
        <img :src="img.url" :alt="img.alt" :loading="i ? 'lazy' : 'eager'" />
        <span v-if="img.room_tag" class="room" aria-hidden="true">{{
          ROOM_LABELS[img.room_tag]
        }}</span>
      </button>
      <button class="btn btn-light btn-sm shadow-sm more" type="button" @click="open(0)">
        <i class="bi bi-grid-3x3-gap" aria-hidden="true"></i>All {{ shown.length }} photos
      </button>
    </div>

    <dialog
      ref="dialog"
      class="viewer"
      aria-labelledby="viewer-title"
      @keydown="onKey"
      @click="onDialogClick"
    >
      <div class="viewer-head">
        <h2 id="viewer-title" class="h6 text-white mb-0 text-truncate">
          {{ title }} · Photo {{ current + 1 }} of {{ inView.length }}
        </h2>
        <button
          type="button"
          class="btn-close btn-close-white"
          aria-label="Close"
          @click="dialog.close()"
        ></button>
      </div>
      <div v-if="rooms.length > 1" class="room-filter" role="group" aria-label="Show photos of">
        <button
          type="button"
          class="room-chip"
          :aria-pressed="room === '' ? 'true' : 'false'"
          @click="pickRoom('')"
        >
          All ({{ shown.length }})
        </button>
        <button
          v-for="r in rooms"
          :key="r.value"
          type="button"
          class="room-chip"
          :aria-pressed="room === r.value ? 'true' : 'false'"
          @click="pickRoom(r.value)"
        >
          {{ r.label }} ({{ r.count }})
        </button>
      </div>
      <div class="viewer-body">
        <img v-if="photo" :src="photo.url" :alt="photo.alt" />
        <template v-if="inView.length > 1">
          <button type="button" class="nav prev" @click="step(-1)">
            <i class="bi bi-chevron-left" aria-hidden="true"></i
            ><span class="visually-hidden">Previous photo</span>
          </button>
          <button type="button" class="nav next" @click="step(1)">
            <i class="bi bi-chevron-right" aria-hidden="true"></i
            ><span class="visually-hidden">Next photo</span>
          </button>
        </template>
      </div>
      <p
        v-if="photo && (photo.caption || photo.room_tag)"
        class="viewer-caption"
        aria-live="polite"
      >
        <span v-if="photo.room_tag" class="badge text-bg-light me-2">{{
          ROOM_LABELS[photo.room_tag]
        }}</span>
        {{ photo.caption }}
      </p>
    </dialog>
  </div>
</template>

<style scoped>
.tile .room {
  position: absolute;
  left: 8px;
  bottom: 8px;
  background: rgb(15 23 42 / 0.72);
  color: #fff;
  font-size: 0.75rem;
  font-weight: 600;
  border-radius: 4px;
  padding: 0.1rem 0.45rem;
}
.room-filter {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
  padding: 0 1rem 0.75rem;
}
.room-chip {
  border: 1px solid rgb(255 255 255 / 0.4);
  background: transparent;
  color: #fff;
  border-radius: 999px;
  padding: 0.25rem 0.75rem;
  min-height: 36px;
  font-size: 0.8125rem;
  font-weight: 600;
}
.room-chip[aria-pressed='true'] {
  background: #fff;
  color: var(--rob-ink);
}
.viewer-caption {
  color: #fff;
  text-align: center;
  margin: 0;
  padding: 0.75rem 1rem 1rem;
}
/* phones: one photo; tablets and up: the mosaic */
.gallery {
  position: relative;
  display: grid;
  grid-template-columns: 1fr;
  grid-template-rows: 260px;
  gap: 8px;
  border-radius: var(--rob-radius-lg);
  overflow: hidden;
}
.tile {
  position: relative;
  display: block;
  overflow: hidden;
  padding: 0;
  border: 0;
  background: var(--rob-surface);
}
.tile:not(:first-child) {
  display: none;
}
.tile img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s var(--rob-ease);
}
.tile:hover img {
  transform: scale(1.02);
}
.tile:focus-visible {
  outline: 3px solid var(--rob-primary);
  outline-offset: -3px;
}
.more {
  position: absolute;
  right: 12px;
  bottom: 12px;
}
@media (min-width: 768px) {
  .gallery {
    grid-template-columns: 2fr 1fr 1fr;
    grid-template-rows: 220px 220px;
  }
  .gallery.g3 {
    grid-template-columns: 2fr 1fr;
  }
  .gallery.g1 {
    grid-template-columns: 1fr;
    grid-template-rows: 448px;
  }
  .tile:not(:first-child) {
    display: block;
  }
  .tile:first-child {
    grid-row: span 2;
  }
  .g1 .tile:first-child {
    grid-row: auto;
  }
}
.gallery-empty {
  height: 220px;
  border-radius: var(--rob-radius-lg);
  background: var(--rob-surface);
  border: 1px dashed #cbd5e1;
  display: grid;
  place-content: center;
  justify-items: center;
  gap: 0.25rem;
  color: var(--rob-muted);
}
.gallery-empty .bi {
  font-size: 2rem;
}

.viewer {
  width: min(1100px, 100vw);
  max-width: 100vw;
  max-height: 100vh;
  padding: 0;
  border: 0;
  border-radius: var(--rob-radius-lg);
  background: #0b1220;
}
.viewer::backdrop {
  background: rgb(15 23 42 / 0.85);
}
.viewer-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1rem;
}
.viewer-head .btn-close {
  width: 44px;
  height: 44px;
  padding: 0;
  flex-shrink: 0;
}
.viewer-body {
  position: relative;
  display: grid;
  place-items: center;
}
.viewer-body img {
  max-width: 100%;
  max-height: 78vh;
  object-fit: contain;
}
.nav {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 44px;
  height: 44px;
  border: 0;
  border-radius: 50%;
  background: rgb(255 255 255 / 0.9);
  color: var(--rob-ink);
  font-size: 1.25rem;
  display: grid;
  place-items: center;
}
.prev {
  left: 0.75rem;
}
.next {
  right: 0.75rem;
}
@media (prefers-reduced-motion: reduce) {
  .tile img {
    transition: none;
  }
  .tile:hover img {
    transform: none;
  }
}
</style>

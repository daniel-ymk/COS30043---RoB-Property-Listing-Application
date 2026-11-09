<script setup>
import { ref, watch, onMounted, onBeforeUnmount } from 'vue'
import L from 'leaflet'
import { moneyShort } from '@/utils/format'

// OpenStreetMap via Leaflet, in three modes:
//   pins:   price tags for a list of properties (map page)
//   circle: a shaded area around one property (detail page, exact
//           address hidden on purpose)
//   pick:   click or drag a pin to choose a location (listing form);
//           v-model:pin is [lat, lng] or null
const props = defineProps({
  center: { type: Array, required: true }, // [lat, lng]
  zoom: { type: Number, default: 13 },
  properties: { type: Array, default: () => [] },
  circle: { type: Boolean, default: false },
  highlightId: { type: Number, default: null },
  label: { type: String, default: 'Map' },
  scrollZoom: { type: Boolean, default: true },
  pick: { type: Boolean, default: false },
  pin: { type: Array, default: null },
})
const emit = defineEmits(['moved', 'ready', 'select', 'hover', 'update:pin'])

const el = ref(null)
// Leaflet objects are not made reactive: Vue proxies would break them
let map = null
let pinLayer = null
let pickMarker = null
const markers = new Map()

const PICK_ICON = L.divIcon({
  className: '',
  html: '<span class="pick-pin"><i class="bi bi-geo-alt-fill"></i></span>',
  iconSize: [36, 36],
  iconAnchor: [18, 34],
})
const round = (n) => Math.round(n * 1e6) / 1e6 // ~10 cm, fits DECIMAL(10,7)

function placePickMarker(latLng) {
  if (!latLng) {
    pickMarker?.remove()
    pickMarker = null
    return
  }
  if (!pickMarker) {
    pickMarker = L.marker(latLng, {
      icon: PICK_ICON,
      draggable: true,
      title: 'Property location (drag to move)',
      keyboard: true,
    })
      .on('dragend', () => {
        const { lat, lng } = pickMarker.getLatLng()
        emit('update:pin', [round(lat), round(lng)])
      })
      .addTo(map)
  } else {
    pickMarker.setLatLng(latLng)
  }
}

const bounds = () => {
  const b = map.getBounds()
  return { north: b.getNorth(), south: b.getSouth(), east: b.getEast(), west: b.getWest() }
}

function pinLabel(p) {
  return p.listing_type === 'rent' ? `${moneyShort(p.price)}/mo` : moneyShort(p.price)
}

function drawPins() {
  pinLayer.clearLayers()
  markers.clear()
  for (const p of props.properties) {
    if (p.latitude === null || p.longitude === null) continue
    const icon = L.divIcon({
      className: '',
      html: `<span class="price-pin ${p.listing_type}">${pinLabel(p)}</span>`,
      iconSize: null,
    })
    const marker = L.marker([p.latitude, p.longitude], { icon, title: p.title, keyboard: true })
      .on('click', () => emit('select', p.property_id))
      .on('mouseover', () => emit('hover', p.property_id))
      .on('mouseout', () => emit('hover', null))
      .addTo(pinLayer)
    markers.set(p.property_id, marker)
  }
  highlight(props.highlightId)
}

function highlight(id, previous) {
  markers.get(previous)?.getElement()?.querySelector('.price-pin')?.classList.remove('active')
  const marker = markers.get(id)
  marker?.getElement()?.querySelector('.price-pin')?.classList.add('active')
  marker?.setZIndexOffset(1000)
  markers.get(previous)?.setZIndexOffset(0)
}

onMounted(() => {
  map = L.map(el.value, { scrollWheelZoom: props.scrollZoom }).setView(props.center, props.zoom)
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  }).addTo(map)
  if (props.circle) {
    L.circle(props.center, { radius: 180, color: '#0f766e', fillOpacity: 0.2 }).addTo(map)
  }
  pinLayer = L.layerGroup().addTo(map)
  drawPins()
  if (props.pick) {
    placePickMarker(props.pin)
    map.on('click', (e) => emit('update:pin', [round(e.latlng.lat), round(e.latlng.lng)]))
  }
  map.on('moveend', () => emit('moved', bounds()))
  emit('ready', bounds())
})

onBeforeUnmount(() => map?.remove())

watch(() => props.properties, drawPins)
watch(() => props.highlightId, highlight)
watch(
  () => props.pin,
  (pin) => props.pick && map && placePickMarker(pin),
)

defineExpose({
  getBounds: bounds,
  panTo: (latLng) => map?.panTo(latLng),
  setView: (latLng, zoom) => map?.setView(latLng, zoom ?? map.getZoom()),
})
</script>

<template>
  <div ref="el" class="leaflet-map" role="region" :aria-label="label"></div>
</template>

<style scoped>
.leaflet-map {
  height: 100%;
  min-height: 240px;
  z-index: 0; /* keep Leaflet's panes under the sticky navbar */
}
.leaflet-map :deep(.pick-pin) {
  display: block;
  font-size: 2.25rem;
  line-height: 1;
  color: var(--rob-primary);
  filter: drop-shadow(0 2px 2px rgb(15 23 42 / 0.4));
  cursor: grab;
}
.leaflet-map :deep(.price-pin) {
  display: inline-block;
  background: #fff;
  border: 2px solid var(--rob-primary);
  color: var(--rob-ink);
  font: 700 0.8125rem/1.4 var(--rob-font-body);
  border-radius: 999px;
  padding: 2px 10px;
  white-space: nowrap;
  box-shadow: var(--rob-shadow);
  transform: translate(-50%, -50%);
  transition: transform 0.15s var(--rob-ease);
}
.leaflet-map :deep(.price-pin.rent) {
  border-color: var(--rob-rent);
}
.leaflet-map :deep(.price-pin.sale) {
  border-color: var(--rob-sale);
}
.leaflet-map :deep(.price-pin.active) {
  background: var(--rob-ink);
  color: #fff;
  transform: translate(-50%, -50%) scale(1.1);
}
</style>

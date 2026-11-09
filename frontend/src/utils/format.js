// Display helpers shared by every page (ported from design/js/rob.js).

export const TYPE_LABELS = {
  condo: 'Condo',
  apartment: 'Apartment',
  house: 'House',
  townhouse: 'Townhouse',
  studio: 'Studio',
  room: 'Room',
}

export const STATUS_LABELS = {
  pending: 'Pending',
  confirmed: 'Confirmed',
  declined: 'Declined',
  cancelled: 'Cancelled',
  available: 'Available',
  rented: 'Rented',
  sold: 'Sold',
}

export function money(amount) {
  return 'RM ' + Number(amount).toLocaleString('en-MY', { maximumFractionDigits: 0 })
}

// Short form for map pins: RM 750, RM 2.6k, RM 1.2M
export function moneyShort(amount) {
  const n = Number(amount)
  if (n >= 1_000_000) return `RM ${+(n / 1_000_000).toFixed(2)}M`
  if (n >= 1_000) return `RM ${+(n / 1_000).toFixed(1)}k`
  return `RM ${n}`
}

export function typeLabel(type) {
  return TYPE_LABELS[type] ?? type
}

export function bedsLabel(bedrooms) {
  return bedrooms === 0 ? 'Studio' : `${bedrooms} bed`
}

// "2026-11-05" -> "Thu, 5 Nov 2026"
export function fmtDate(
  date,
  options = { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' },
) {
  return new Date(`${date.slice(0, 10)}T00:00:00`).toLocaleDateString('en-GB', options)
}

// "14:30:00" -> "2:30 PM"
export function fmtTime(time) {
  const [h, m] = time.split(':').map(Number)
  return `${((h + 11) % 12) + 1}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`
}

export function initials(name) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word[0].toUpperCase())
    .slice(0, 2)
    .join('')
}

// "2026-11-03 10:00:00" -> "today", "yesterday", "3 days ago"
export function daysAgo(timestamp, now = new Date()) {
  const then = new Date(timestamp.replace(' ', 'T'))
  const days = Math.floor((now - then) / 86_400_000)
  if (days <= 0) return 'today'
  if (days === 1) return 'yesterday'
  return `${days} days ago`
}

// "60123456789" -> "+60 12-345 6789" (display only; links use the digits)
export function formatPhone(digits) {
  const match = /^(\d{2})(\d{2})(\d{3})(\d+)$/.exec(digits ?? '')
  return match ? `+${match[1]} ${match[2]}-${match[3]} ${match[4]}` : `+${digits}`
}

export function whatsappLink(digits, message) {
  return `https://wa.me/${digits}?text=${encodeURIComponent(message)}`
}

// Listing form "State" choices (13 states and 3 federal territories)
export const MALAYSIAN_STATES = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Penang',
  'Perak',
  'Perlis',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
  'Wilayah Persekutuan',
  'Labuan',
  'Putrajaya',
]

// Local calendar date as "YYYY-MM-DD" (not toISOString, which is UTC and
// gives yesterday's date before 8 AM in Malaysia)
export function isoDate(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

// Photo room tags (property_images.room_tag)
export const ROOM_LABELS = {
  exterior: 'Exterior',
  living: 'Living room',
  bedroom: 'Bedroom',
  kitchen: 'Kitchen',
  bathroom: 'Bathroom',
  dining: 'Dining',
  balcony: 'Balcony',
  other: 'Other',
}

// 1536 -> "1.5 KB", 2400000 -> "2.3 MB"
export function fileSize(bytes) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}

// Form rules from docs/api.md section 4, with the same messages PHP returns.
// Each rule takes the value (and all form values) and returns an error
// message, or '' when the value is fine.

export const MESSAGES = {
  fullName: 'Enter your full name (2–100 characters)',
  email: 'Enter a valid email address',
  emailMissing: 'Enter your email address',
  password: 'Use at least 8 characters with a letter and a number',
  passwordMissing: 'Enter your password',
  phone: 'Use digits only, starting with the country code (8–15 digits)',
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function fullName(value) {
  const length = value.trim().length
  return length >= 2 && length <= 100 ? '' : MESSAGES.fullName
}

export function email(value) {
  const text = value.trim()
  if (!text) return MESSAGES.emailMissing
  return EMAIL_PATTERN.test(text) && text.length <= 150 ? '' : MESSAGES.email
}

export function newPassword(value) {
  return value.length >= 8 && /[A-Za-z]/.test(value) && /\d/.test(value) ? '' : MESSAGES.password
}

export function passwordEntered(value) {
  return value ? '' : MESSAGES.passwordMissing
}

// Phone is required for owners and optional for viewers.
export function phone(value, required) {
  const text = value.trim()
  if (!text) return required ? MESSAGES.phone : ''
  return /^\d{8,15}$/.test(text) ? '' : MESSAGES.phone
}

// Listing form (same messages as LISTING_MESSAGES in properties.php)
export const LISTING_MESSAGES = {
  title: 'Title must be 5–150 characters',
  description: 'Description must be 20–5000 characters',
  price: 'Enter a price above 0',
  rooms: 'Enter a whole number from 0 to 20',
  floor_area_sqm: 'Floor area must be 5–100,000 m²',
  address: 'Enter the street address',
  city: 'Enter the city',
  postcode: 'Postcode must be 4–10 digits',
}

const between = (value, min, max) => value.trim().length >= min && value.trim().length <= max

export const listingRules = {
  title: (v) => (between(v, 5, 150) ? '' : LISTING_MESSAGES.title),
  description: (v) => (between(v, 20, 5000) ? '' : LISTING_MESSAGES.description),
  price: (v) => {
    const n = Number(v)
    return String(v).trim() !== '' && n > 0 && n <= 9_999_999_999 ? '' : LISTING_MESSAGES.price
  },
  bedrooms: (v) => rooms(v),
  bathrooms: (v) => rooms(v),
  parking_spaces: (v) => rooms(v),
  floor_area_sqm: (v) => {
    if (String(v).trim() === '') return ''
    const n = Number(v)
    return n >= 5 && n <= 100_000 ? '' : LISTING_MESSAGES.floor_area_sqm
  },
  address: (v) => (between(v, 1, 255) ? '' : LISTING_MESSAGES.address),
  city: (v) => (between(v, 1, 100) ? '' : LISTING_MESSAGES.city),
  postcode: (v) => (!v.trim() || /^\d{4,10}$/.test(v.trim()) ? '' : LISTING_MESSAGES.postcode),
}

function rooms(value) {
  return /^\d{1,2}$/.test(String(value)) && Number(value) <= 20 ? '' : LISTING_MESSAGES.rooms
}

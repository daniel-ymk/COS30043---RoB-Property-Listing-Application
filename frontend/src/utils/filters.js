import { money, TYPE_LABELS } from './format'

// Listing filters live in the URL (/properties?city=Kuching&page=2), so a
// search can be shared, bookmarked and restored with the back button.

export const SORT_OPTIONS = [
  { value: 'newest', label: 'Newest' },
  { value: 'price_asc', label: 'Price: low to high' },
  { value: 'price_desc', label: 'Price: high to low' },
  { value: 'most_liked', label: 'Most liked' },
]

export const PROPERTY_TYPES = Object.keys(TYPE_LABELS)

export function emptyFilters() {
  return {
    q: '',
    listing_type: '',
    city: '',
    property_type: [],
    min_price: '',
    max_price: '',
    min_bedrooms: '',
    furnished: false,
  }
}

const one = (value) => (Array.isArray(value) ? value[0] : value) ?? ''

// route.query -> filter object (ignores values the API would reject)
export function filtersFromQuery(query) {
  const listingType = one(query.listing_type)
  return {
    q: String(one(query.q)),
    listing_type: ['rent', 'sale'].includes(listingType) ? listingType : '',
    city: String(one(query.city)),
    property_type: String(one(query.property_type))
      .split(',')
      .filter((type) => PROPERTY_TYPES.includes(type)),
    min_price: /^\d+$/.test(one(query.min_price)) ? one(query.min_price) : '',
    max_price: /^\d+$/.test(one(query.max_price)) ? one(query.max_price) : '',
    min_bedrooms: /^\d$/.test(one(query.min_bedrooms)) ? one(query.min_bedrooms) : '',
    furnished: one(query.furnished) === '1',
  }
}

// filter object -> route.query / API query, without empty values
export function filtersToQuery(filters) {
  const query = {}
  const text = filters.q.trim()
  if (text) query.q = text
  if (filters.listing_type) query.listing_type = filters.listing_type
  if (filters.city) query.city = filters.city
  if (filters.property_type.length) query.property_type = filters.property_type.join(',')
  if (filters.min_price !== '') query.min_price = String(filters.min_price)
  if (filters.max_price !== '') query.max_price = String(filters.max_price)
  if (filters.min_bedrooms !== '') query.min_bedrooms = String(filters.min_bedrooms)
  if (filters.furnished) query.furnished = '1'
  return query
}

// One removable chip per active filter: { key, label, without } where
// without is the filter object with that one filter taken off
export function filterChips(filters) {
  const chips = []
  const drop = (key, value) => ({ ...filters, [key]: value })
  if (filters.q.trim())
    chips.push({ key: 'q', label: `"${filters.q.trim()}"`, without: drop('q', '') })
  if (filters.listing_type) {
    chips.push({
      key: 'listing_type',
      label: filters.listing_type === 'rent' ? 'For rent' : 'For sale',
      without: drop('listing_type', ''),
    })
  }
  if (filters.city) chips.push({ key: 'city', label: filters.city, without: drop('city', '') })
  for (const type of filters.property_type) {
    chips.push({
      key: `type-${type}`,
      label: TYPE_LABELS[type],
      without: drop(
        'property_type',
        filters.property_type.filter((t) => t !== type),
      ),
    })
  }
  if (filters.min_price !== '' && filters.max_price !== '') {
    chips.push({
      key: 'price',
      label: `${money(filters.min_price)} – ${money(filters.max_price)}`,
      without: { ...filters, min_price: '', max_price: '' },
    })
  } else if (filters.min_price !== '') {
    chips.push({
      key: 'price',
      label: `From ${money(filters.min_price)}`,
      without: drop('min_price', ''),
    })
  } else if (filters.max_price !== '') {
    chips.push({
      key: 'price',
      label: `Up to ${money(filters.max_price)}`,
      without: drop('max_price', ''),
    })
  }
  if (filters.min_bedrooms !== '') {
    chips.push({
      key: 'beds',
      label: `${filters.min_bedrooms}+ bedrooms`,
      without: drop('min_bedrooms', ''),
    })
  }
  if (filters.furnished)
    chips.push({ key: 'furnished', label: 'Furnished', without: drop('furnished', false) })
  return chips
}

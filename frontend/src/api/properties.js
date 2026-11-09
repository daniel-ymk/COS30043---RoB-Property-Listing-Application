import { request } from './client'

// docs/api.md sections 3.2 and 3.3

// Returns { data: [cards], meta }
export function listProperties(query = {}) {
  return request('properties', { query })
}

export function getProperty(id) {
  return request(`properties/${id}`)
}

// Compare page: details for up to 4 ids, in the same order
export function compareProperties(ids) {
  return request('properties', { query: { ids: ids.join(',') } })
}

// bounds: { north, south, east, west }
export function searchMap(bounds) {
  return request('map', { query: bounds })
}

export function listCities() {
  return request('cities')
}

// Owner: my listings (all statuses) - { data: [cards], meta }
export function listMine(query = {}) {
  return request('me/properties', { query })
}

export async function createProperty(listing) {
  const { data } = await request('properties', { method: 'POST', body: listing })
  return data // Property detail
}

// Full replace: every field plus status
export async function replaceProperty(id, listing) {
  const { data } = await request(`properties/${id}`, { method: 'PUT', body: listing })
  return data
}

// Status only: available / rented / sold
export async function setPropertyStatus(id, status) {
  const { data } = await request(`properties/${id}`, { method: 'PATCH', body: { status } })
  return data
}

export function deleteProperty(id) {
  return request(`properties/${id}`, { method: 'DELETE' })
}

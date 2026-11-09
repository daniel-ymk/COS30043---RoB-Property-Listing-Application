import { request } from './client'

// docs/api.md section 3.5

// Returns { data: [cards], meta }
export function listLikes(query = {}) {
  return request('me/likes', { query })
}

// Both return { property_id, liked, like_count }
export async function like(propertyId) {
  const { data } = await request(`me/likes/${propertyId}`, { method: 'PUT' })
  return data
}

export async function unlike(propertyId) {
  const { data } = await request(`me/likes/${propertyId}`, { method: 'DELETE' })
  return data
}

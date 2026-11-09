import { request } from './client'

// docs/api.md section 3.8

export async function updateProfile(changes) {
  const { data } = await request('me', { method: 'PATCH', body: changes })
  return data // User
}

import { request } from './client'

// docs/api.md section 3.1

export async function fetchCurrentUser() {
  const { data } = await request('session')
  return data // User or null
}

export async function login(email, password, remember = false) {
  const { data } = await request('session', {
    method: 'POST',
    body: { email, password, remember },
  })
  return data
}

export async function register(form) {
  const { data } = await request('users', { method: 'POST', body: form })
  return data
}

export async function logout() {
  await request('session', { method: 'DELETE' })
}

// Shared fetch wrapper for the PHP REST API (response format: docs/api.md section 1).
// Every resource file in src/api/ calls request() instead of fetch() directly.

const API_BASE = import.meta.env.VITE_API_BASE ?? '/api'
const BACKEND_URL = import.meta.env.VITE_BACKEND_URL ?? '/backend'

// main.js registers what happens when the session has ended (401).
let unauthorizedHandler = () => {}
export function onUnauthorized(handler) {
  unauthorizedHandler = handler
}

// For requests that can't use fetch (upload progress needs XMLHttpRequest)
export function apiUrl(path) {
  return `${API_BASE}/${path}`
}

// Turns a failed response body into an ApiError, same as request() does
export function toApiError(status, json) {
  if (status === 401) unauthorizedHandler()
  return new ApiError(status, json?.error ?? 'Something went wrong', json?.fields)
}

export class ApiError extends Error {
  constructor(status, message, fields = {}) {
    super(message)
    this.status = status
    this.fields = fields // per-input messages on 422
  }
}

// request('properties', { query: { page: 2 } })
// request('me/likes/5', { method: 'PUT' })
export async function request(path, { method = 'GET', query, body } = {}) {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value !== undefined && value !== null && value !== '') params.append(key, value)
  }
  const url = `${API_BASE}/${path}${params.size ? `?${params}` : ''}`

  const options = { method, credentials: 'same-origin', headers: {} }
  if (body instanceof FormData) {
    options.body = body // browser sets the multipart boundary itself
  } else if (body !== undefined) {
    options.headers['Content-Type'] = 'application/json'
    options.body = JSON.stringify(body)
  }

  let response
  try {
    response = await fetch(url, options)
  } catch {
    throw new ApiError(0, 'Cannot reach the server. Check your connection.')
  }

  if (response.status === 204) return null

  const json = await response.json().catch(() => null)
  if (!response.ok) {
    // A 401 from POST /session is just a wrong password, not an expired session
    if (response.status === 401 && path !== 'session') unauthorizedHandler()
    throw new ApiError(response.status, json?.error ?? 'Something went wrong', json?.fields)
  }
  return json // { data } or { data, meta }
}

// Turns a stored file_path (e.g. "uploads/seed/condo.jpg") into an <img> src.
export function imageUrl(filePath) {
  return filePath ? `${BACKEND_URL}/${filePath}` : null
}

import { request, apiUrl, toApiError, ApiError } from './client'

// docs/api.md section 3.4

export const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp']
export const MAX_PHOTO_BYTES = 2 * 1024 * 1024
export const MAX_PHOTOS = 10

export const MAX_RAW_BYTES = 25 * 1024 * 1024 // before compressing in the browser

// Uploads one file as photos[] with its details (caption, room_tag,
// is_hidden); onProgress(0..100) follows the upload. Resolves with
// { images: every image of the listing, created: [new image id] }.
export function uploadPhoto(propertyId, file, fields = {}, onProgress = () => {}) {
  const form = new FormData()
  form.append('photos[]', file)
  for (const [name, value] of Object.entries(fields)) {
    if (value !== null && value !== undefined)
      form.append(name, typeof value === 'boolean' ? (value ? '1' : '0') : value)
  }

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('POST', apiUrl(`properties/${propertyId}/images`))
    xhr.withCredentials = true
    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable) onProgress(Math.round((event.loaded / event.total) * 100))
    }
    xhr.onload = () => {
      let json = null
      try {
        json = JSON.parse(xhr.responseText)
      } catch {
        // not JSON (e.g. PHP's upload size limit page)
      }
      if (xhr.status >= 200 && xhr.status < 300)
        resolve({ images: json.data, created: json.meta.created })
      else reject(toApiError(xhr.status, json))
    }
    xhr.onerror = () => reject(new ApiError(0, 'Cannot reach the server. Check your connection.'))
    xhr.send(form)
  })
}

// order: image_ids, cover first
export async function reorderPhotos(propertyId, order) {
  const { data } = await request(`properties/${propertyId}/images`, {
    method: 'PUT',
    body: { order },
  })
  return data
}

// details: any of { caption, room_tag, is_hidden }
export async function updatePhoto(imageId, details) {
  const { data } = await request(`images/${imageId}`, { method: 'PATCH', body: details })
  return data
}

export function deletePhoto(imageId) {
  return request(`images/${imageId}`, { method: 'DELETE' })
}

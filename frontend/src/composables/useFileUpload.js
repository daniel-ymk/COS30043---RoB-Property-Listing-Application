import { reactive } from 'vue'
import { compressImage } from '@/utils/compressImage'
import { uploadPhoto } from '@/api/images'

// Per-file preparation and upload, for the photo manager. Each file is
// tracked under its own key, so every thumbnail can show its own state:
//   status: 'compressing' | 'ready' | 'invalid' | 'uploading' | 'done' | 'failed'
//   progress (0-100), error, originalSize, size
//
//   const files = useFileUpload({ maxBytes: 2 MB })
//   await files.prepare(key, file)              // compress, then 'ready'
//   await files.uploadAll(propertyId, jobs, 2)  // jobs: [{ key, fields }]
export function useFileUpload({ maxBytes, maxSide = 1920, quality = 0.82 } = {}) {
  const state = reactive({}) // key -> { status, progress, error, file, originalSize, size }

  function stateOf(key) {
    return state[key] ?? null
  }

  // Compresses the file; the result is kept for uploading later. A file
  // that can't be used ends as 'invalid' (not retried), unlike an upload
  // that failed ('failed', retried on the next upload). state[key].preparing
  // is the promise, so a save can wait for compressions still running.
  function prepare(key, file) {
    const entry = {
      status: 'compressing',
      progress: 0,
      error: '',
      file,
      originalSize: file.size,
      size: file.size,
    }
    state[key] = entry
    entry.preparing = (async () => {
      try {
        const result = await compressImage(file, { maxSide, quality, maxBytes })
        Object.assign(state[key], { file: result.file, size: result.size })
        if (maxBytes && result.size > maxBytes) {
          Object.assign(state[key], {
            status: 'invalid',
            error: 'Still larger than 2 MB after shrinking',
          })
          return false
        }
        state[key].status = 'ready'
        return true
      } catch (err) {
        Object.assign(state[key], { status: 'invalid', error: err.message })
        return false
      }
    })()
    return entry.preparing
  }

  // Sends one prepared file; resolves with the new image id
  async function upload(propertyId, key, fields) {
    const entry = state[key]
    Object.assign(entry, { status: 'uploading', progress: 0, error: '' })
    try {
      const { created } = await uploadPhoto(
        propertyId,
        entry.file,
        fields,
        (pct) => (entry.progress = pct),
      )
      Object.assign(entry, { status: 'done', progress: 100 })
      return created[0]
    } catch (err) {
      Object.assign(entry, {
        status: 'failed',
        error: Object.values(err.fields ?? {})[0] ?? err.message,
      })
      throw err
    }
  }

  // Uploads several files, `concurrency` at a time. Never rejects: resolves
  // with { [key]: imageId } for the ones that worked; failures stay in state.
  async function uploadAll(propertyId, jobs, concurrency = 2) {
    const ids = {}
    const queue = [...jobs]
    async function worker() {
      while (queue.length) {
        const job = queue.shift()
        try {
          ids[job.key] = await upload(propertyId, job.key, job.fields)
        } catch {
          // recorded in state[job.key]
        }
      }
    }
    await Promise.all(Array.from({ length: Math.min(concurrency, jobs.length) }, worker))
    return ids
  }

  function forget(key) {
    delete state[key]
  }

  return { state, stateOf, prepare, upload, uploadAll, forget }
}

import { ref, shallowRef } from 'vue'

// Wraps an API call so a page can show loading / error / empty states.
//   const { data, meta, loading, error, run } = useAsync(() => request('properties'))
//   onMounted(run)
// fn returns the API's { data, meta } body. If run() is called again before
// the last call finishes, only the newest result is kept.
export function useAsync(fn) {
  const data = shallowRef(null)
  const meta = shallowRef(null)
  const loading = ref(false)
  const error = shallowRef(null)
  let latest = 0

  async function run(...args) {
    const call = ++latest
    loading.value = true
    error.value = null
    try {
      const body = await fn(...args)
      if (call !== latest) return
      data.value = body?.data ?? null
      meta.value = body?.meta ?? null
    } catch (err) {
      if (call !== latest) return
      error.value = err
    } finally {
      if (call === latest) loading.value = false
    }
  }

  return { data, meta, loading, error, run }
}

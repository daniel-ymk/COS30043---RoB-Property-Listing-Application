import { ref, watch } from 'vue'
import { defineStore } from 'pinia'
import { listAppointments } from '@/api/viewings'
import { useAuthStore } from './auth'

const REFRESH_MS = 30_000

// Number of pending viewing requests on the owner's listings, for the
// navbar badge (docs/api.md 3.7: per_page=1 and read meta.total).
export const usePendingRequestsStore = defineStore('pendingRequests', () => {
  const auth = useAuthStore()
  const count = ref(0)
  let lastLoaded = 0

  async function refresh({ force = false } = {}) {
    if (!auth.isOwner) {
      count.value = 0
      return
    }
    if (!force && Date.now() - lastLoaded < REFRESH_MS) return
    lastLoaded = Date.now()
    try {
      const { meta } = await listAppointments({ as: 'owner', status: 'pending', per_page: 1 })
      count.value = meta.total
    } catch {
      // the badge just keeps its last value
    }
  }

  // New user: start again
  watch(
    () => auth.user?.user_id,
    () => {
      count.value = 0
      lastLoaded = 0
      refresh()
    },
  )

  return { count, refresh }
})

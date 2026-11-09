import { ref, computed, watch } from 'vue'
import { defineStore } from 'pinia'

export const COMPARE_MAX = 4
const STORAGE_KEY = 'rob-compare'

// localStorage can throw (private mode, blocked storage); compare then lasts
// until the page is reloaded.
function load() {
  try {
    const ids = JSON.parse(localStorage.getItem(STORAGE_KEY))
    return Array.isArray(ids) ? ids.filter(Number.isInteger).slice(0, COMPARE_MAX) : []
  } catch {
    return []
  }
}

// Properties picked for /compare, kept across visits on this browser.
export const useCompareStore = defineStore('compare', () => {
  const ids = ref(load())

  const count = computed(() => ids.value.length)
  const isFull = computed(() => ids.value.length >= COMPARE_MAX)

  watch(
    ids,
    (value) => {
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(value))
      } catch {
        // storage unavailable
      }
    },
    { deep: true },
  )

  function has(id) {
    return ids.value.includes(id)
  }

  // Returns false when the list is already full.
  function add(id) {
    if (has(id)) return true
    if (isFull.value) return false
    ids.value.push(id)
    return true
  }

  function remove(id) {
    ids.value = ids.value.filter((x) => x !== id)
  }

  function clear() {
    ids.value = []
  }

  return { ids, count, isFull, has, add, remove, clear }
})

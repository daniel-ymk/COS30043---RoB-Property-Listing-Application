import { ref } from 'vue'
import { defineStore } from 'pinia'

const MAX_SHOWN = 3

// Short status messages shown by <ToastHost> ("Saved to Liked", errors).
// action: { label, run } adds a button such as "Undo".
export const useToastStore = defineStore('toast', () => {
  const toasts = ref([])
  let nextId = 1

  function show(
    message,
    { icon = 'check-circle', variant = 'dark', delay = 3000, action = null } = {},
  ) {
    const id = nextId++
    toasts.value.push({ id, message, icon, variant, action })
    // Quick repeated actions (liking several homes) keep only the latest few
    if (toasts.value.length > MAX_SHOWN) toasts.value.shift()
    setTimeout(() => dismiss(id), delay)
    return id
  }

  function runAction(item) {
    dismiss(item.id)
    item.action?.run()
  }

  function error(message) {
    return show(message, { icon: 'exclamation-octagon', variant: 'danger', delay: 5000 })
  }

  function dismiss(id) {
    toasts.value = toasts.value.filter((toast) => toast.id !== id)
  }

  return { toasts, show, error, dismiss, runAction }
})

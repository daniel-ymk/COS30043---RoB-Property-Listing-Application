import { ref } from 'vue'
import { defineStore } from 'pinia'

// One confirmation dialog for the whole app (<ConfirmHost> in App.vue).
//   if (await confirm.ask({ title: 'Delete this listing?', danger: true })) ...
export const useConfirmStore = defineStore('confirm', () => {
  const current = ref(null) // { title, text, confirmLabel, cancelLabel, danger }
  let resolver = null

  function ask({
    title,
    text = '',
    confirmLabel = 'Confirm',
    cancelLabel = 'Cancel',
    danger = false,
  }) {
    resolver?.(false) // a new question replaces an unanswered one
    current.value = { title, text, confirmLabel, cancelLabel, danger }
    return new Promise((resolve) => (resolver = resolve))
  }

  function answer(yes) {
    resolver?.(yes)
    resolver = null
    current.value = null
  }

  return { current, ask, answer }
})

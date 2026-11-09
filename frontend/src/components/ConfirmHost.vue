<script setup>
import { ref, watch, nextTick } from 'vue'
import { useConfirmStore } from '@/stores/confirm'

// Native <dialog>: traps focus, closes on Esc, and returns focus to the
// button that opened it.
const confirm = useConfirmStore()
const dialog = ref(null)
const cancelButton = ref(null)

watch(
  () => confirm.current,
  async (question) => {
    await nextTick()
    if (question && !dialog.value.open) {
      dialog.value.showModal()
      // The safe choice gets focus, so Enter never deletes by accident
      cancelButton.value?.focus()
    } else if (!question && dialog.value.open) {
      dialog.value.close()
    }
  },
)

// Esc or a backdrop click count as "no"
function onClose() {
  if (confirm.current) confirm.answer(false)
}
function onClick(event) {
  if (event.target === dialog.value) confirm.answer(false)
}
</script>

<template>
  <dialog
    ref="dialog"
    class="confirm"
    aria-labelledby="confirm-title"
    aria-describedby="confirm-text"
    @close="onClose"
    @click="onClick"
  >
    <div v-if="confirm.current" class="p-4">
      <div v-if="confirm.current.danger" class="icon" aria-hidden="true">
        <i class="bi bi-exclamation-triangle"></i>
      </div>
      <h2 id="confirm-title" class="h5">{{ confirm.current.title }}</h2>
      <p id="confirm-text" class="text-muted">{{ confirm.current.text }}</p>
      <div class="d-flex flex-wrap gap-2 justify-content-end">
        <button
          ref="cancelButton"
          class="btn btn-outline-secondary"
          type="button"
          @click="confirm.answer(false)"
        >
          {{ confirm.current.cancelLabel }}
        </button>
        <button
          class="btn"
          :class="confirm.current.danger ? 'btn-danger' : 'btn-primary'"
          type="button"
          @click="confirm.answer(true)"
        >
          {{ confirm.current.confirmLabel }}
        </button>
      </div>
    </div>
  </dialog>
</template>

<style scoped>
.confirm {
  width: min(460px, calc(100vw - 2rem));
  border: 0;
  border-radius: var(--rob-radius-lg);
  padding: 0;
  box-shadow: 0 24px 48px rgb(15 23 42 / 0.25);
}
.confirm::backdrop {
  background: rgb(15 23 42 / 0.5);
}
.icon {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #fee2e2;
  color: #b91c1c;
  display: grid;
  place-items: center;
  font-size: 1.5rem;
  margin-bottom: 1rem;
}
.btn-danger {
  --bs-btn-bg: #b91c1c;
  --bs-btn-border-color: #b91c1c;
  --bs-btn-hover-bg: #991b1b;
  --bs-btn-hover-border-color: #991b1b;
}
</style>

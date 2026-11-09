<script setup>
import { useToastStore } from '@/stores/toast'

const toast = useToastStore()
</script>

<template>
  <!-- One live region for every toast so screen readers announce them -->
  <div class="toast-host" role="status" aria-live="polite">
    <div
      v-for="item in toast.toasts"
      :key="item.id"
      class="toast show align-items-center border-0"
      :class="`text-bg-${item.variant}`"
    >
      <div class="d-flex">
        <div class="toast-body">
          <i class="bi me-2" :class="`bi-${item.icon}`" aria-hidden="true"></i>{{ item.message }}
        </div>
        <button
          v-if="item.action"
          type="button"
          class="btn btn-sm toast-action"
          @click="toast.runAction(item)"
        >
          {{ item.action.label }}
        </button>
        <button
          type="button"
          class="btn-close btn-close-white me-2 m-auto"
          aria-label="Close"
          @click="toast.dismiss(item.id)"
        ></button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.toast-host {
  position: fixed;
  z-index: 2100;
  inset: auto 1rem 1rem 1rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  pointer-events: none;
}
.toast {
  pointer-events: auto;
  max-width: 100%;
}
.toast-action {
  align-self: center;
  color: #5eead4; /* teal-300: 9:1 on the dark toast */
  font-weight: 700;
  min-height: 36px;
  margin-left: auto;
}
.toast-action:hover {
  color: #fff;
}
@media (min-width: 768px) {
  .toast-host {
    inset: calc(var(--rob-nav-height) + 1rem) 1rem auto auto;
    align-items: flex-end;
  }
}
</style>

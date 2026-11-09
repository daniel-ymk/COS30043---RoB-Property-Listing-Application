<script setup>
defineProps({
  icon: { type: String, default: 'house' },
  title: { type: String, required: true },
  text: { type: String, default: '' },
})
</script>

<template>
  <div class="empty-state">
    <div class="icon"><i class="bi" :class="`bi-${icon}`" aria-hidden="true"></i></div>
    <h2 class="h5">{{ title }}</h2>
    <p v-if="text" class="text-muted mx-auto">{{ text }}</p>
    <!-- action buttons, e.g. "Clear filters" -->
    <slot></slot>
  </div>
</template>

<style scoped>
.empty-state {
  text-align: center;
  padding: 2.5rem 1rem;
  border: 1px dashed #cbd5e1;
  border-radius: var(--rob-radius-lg);
  background: var(--rob-surface);
}
.icon {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: #fff;
  border: 1px solid var(--rob-line);
  display: grid;
  place-items: center;
  margin: 0 auto 1rem;
  font-size: 1.75rem;
  color: var(--rob-primary);
}
p {
  max-width: 44ch;
}
@media (min-width: 768px) {
  .empty-state {
    padding: 3.5rem 1.5rem;
  }
}
</style>

<template>
  <div class="skeleton-card" aria-hidden="true">
    <div class="skeleton media"></div>
    <div class="body">
      <div class="skeleton" style="height: 24px; width: 45%"></div>
      <div class="skeleton" style="height: 18px; width: 90%"></div>
      <div class="skeleton" style="height: 18px; width: 60%"></div>
      <div class="skeleton mt-2" style="height: 16px; width: 80%"></div>
    </div>
  </div>
</template>

<style scoped>
.skeleton-card {
  border: 1px solid var(--rob-line);
  border-radius: var(--rob-radius-lg);
  overflow: hidden;
  height: 100%;
  background: #fff;
}
.media {
  aspect-ratio: 4 / 3;
  border-radius: 0;
}
.body {
  padding: 1rem 1.125rem 1.125rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
</style>

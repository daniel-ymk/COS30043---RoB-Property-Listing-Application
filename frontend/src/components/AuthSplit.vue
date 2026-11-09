<script setup>
// Log in / Register layout: form on the left, photo on the right.
// Phones and tablets show the form only.
defineProps({
  image: { type: String, required: true },
  width: { type: String, default: '420px' },
})
</script>

<template>
  <div class="auth-wrap">
    <div class="form-side">
      <div class="w-100" :style="{ maxWidth: width }">
        <slot></slot>
      </div>
    </div>
    <div class="photo-side" aria-hidden="true">
      <img :src="image" alt="" />
    </div>
  </div>
</template>

<style scoped>
.auth-wrap {
  display: grid;
  grid-template-columns: 1fr;
  min-height: calc(100vh - var(--rob-nav-height));
}
.form-side {
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 2rem 1rem;
}
.photo-side {
  display: none;
  position: relative;
  overflow: hidden;
}
.photo-side img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
@media (min-width: 768px) {
  .form-side {
    padding: 3rem;
  }
}
@media (min-width: 992px) {
  .auth-wrap {
    grid-template-columns: 1fr 1fr;
  }
  .form-side {
    align-items: center;
  }
  .photo-side {
    display: block;
  }
}
</style>

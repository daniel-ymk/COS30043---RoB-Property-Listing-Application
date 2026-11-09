<script setup>
import { RouterView, useRoute } from 'vue-router'
import AppNavbar from '@/components/AppNavbar.vue'
import AppFooter from '@/components/AppFooter.vue'
import ToastHost from '@/components/ToastHost.vue'
import ConfirmHost from '@/components/ConfirmHost.vue'

const route = useRoute()
</script>

<template>
  <a class="skip-link" href="#main">Skip to content</a>
  <AppNavbar />
  <!-- No container here: full-width pages (hero, map, log in) add their own -->
  <main id="main" tabindex="-1">
    <RouterView />
  </main>
  <AppFooter v-if="!route.meta.hideFooter" />
  <ToastHost />
  <ConfirmHost />
</template>

<style scoped>
.skip-link {
  position: absolute;
  left: 1rem;
  top: -100px;
  z-index: 2000;
  background: var(--rob-ink);
  color: #fff;
  padding: 0.75rem 1rem;
  border-radius: var(--rob-radius);
}
.skip-link:focus {
  top: 0.5rem;
}
main:focus {
  outline: none;
}
</style>

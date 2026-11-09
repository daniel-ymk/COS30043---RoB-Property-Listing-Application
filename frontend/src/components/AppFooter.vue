<script setup>
import { RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const year = new Date().getFullYear()
const cities = ['Kuala Lumpur', 'Kuching', 'George Town']
</script>

<template>
  <footer class="rob-footer">
    <div class="container py-5">
      <div class="row g-4">
        <div class="col-12 col-lg-5">
          <RouterLink class="brand d-inline-flex align-items-center gap-2" :to="{ name: 'home' }">
            <span class="brand-mark"><i class="bi bi-house-door-fill" aria-hidden="true"></i></span>
            RoB Property
          </RouterLink>
          <p class="text-muted mt-3 mb-0">
            Rent or buy homes across Malaysia, straight from the owner. Book a viewing in two
            clicks.
          </p>
        </div>
        <div class="col-6 col-lg-2">
          <h2 class="h6">Find a home</h2>
          <ul class="list-unstyled d-grid gap-2 mb-0">
            <li>
              <RouterLink :to="{ name: 'properties', query: { listing_type: 'rent' } }"
                >For rent</RouterLink
              >
            </li>
            <li>
              <RouterLink :to="{ name: 'properties', query: { listing_type: 'sale' } }"
                >For sale</RouterLink
              >
            </li>
            <li><RouterLink :to="{ name: 'map' }">Map search</RouterLink></li>
          </ul>
        </div>
        <div class="col-6 col-lg-2">
          <h2 class="h6">Owners</h2>
          <ul class="list-unstyled d-grid gap-2 mb-0">
            <li v-if="auth.isOwner">
              <RouterLink :to="{ name: 'listing-create' }">List a property</RouterLink>
            </li>
            <li v-else-if="!auth.isLoggedIn">
              <RouterLink :to="{ name: 'register' }">List a property</RouterLink>
            </li>
            <li v-if="auth.isOwner">
              <RouterLink :to="{ name: 'owner-listings' }">My listings</RouterLink>
            </li>
            <li><RouterLink :to="{ name: 'compare' }">Compare homes</RouterLink></li>
          </ul>
        </div>
        <div class="col-12 col-lg-3">
          <h2 class="h6">Cities</h2>
          <ul class="list-unstyled d-grid gap-2 mb-0">
            <li v-for="city in cities" :key="city">
              <RouterLink :to="{ name: 'properties', query: { city } }">{{ city }}</RouterLink>
            </li>
          </ul>
        </div>
      </div>
      <div
        class="border-top mt-4 pt-4 small text-muted d-flex flex-wrap justify-content-between gap-2"
      >
        <span>© {{ year }} RoB Property · COS30043 student project</span>
        <span>Photos: Unsplash</span>
      </div>
    </div>
  </footer>
</template>

<style scoped>
.rob-footer {
  border-top: 1px solid var(--rob-line);
  background: var(--rob-surface);
  margin-top: 3rem;
}
.rob-footer a {
  color: var(--rob-muted);
  text-decoration: none;
}
.rob-footer a:hover {
  color: var(--rob-ink);
  text-decoration: underline;
}
.rob-footer .brand {
  font-family: var(--rob-font-heading);
  font-weight: 700;
  font-size: 1.25rem;
  color: var(--rob-ink);
}
.brand-mark {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--rob-primary);
  color: #fff;
  display: grid;
  place-items: center;
  font-size: 1rem;
}
p {
  max-width: 38ch;
}
</style>

<script setup>
import { ref, computed, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useCompareStore } from '@/stores/compare'
import { useToastStore } from '@/stores/toast'
import { usePendingRequestsStore } from '@/stores/requests'
import { initials } from '@/utils/format'

const auth = useAuthStore()
const compare = useCompareStore()
const toast = useToastStore()
const route = useRoute()
const router = useRouter()

// The phone menu is opened by Vue rather than Bootstrap's collapse plugin,
// so it can close itself after every navigation.
const menuOpen = ref(false)
const pending = usePendingRequestsStore()
watch(
  () => route.fullPath,
  () => {
    menuOpen.value = false
    pending.refresh() // at most every 30 s, owners only
  },
)

const firstName = computed(() => auth.user?.full_name.split(' ')[0] ?? '')
const ownerSection = computed(() => route.path.startsWith('/owner'))

async function handleLogout() {
  await auth.logout()
  toast.show('You have logged out', { icon: 'box-arrow-right' })
  router.push({ name: 'home' })
}
</script>

<template>
  <nav class="navbar navbar-expand-lg rob-nav sticky-top" aria-label="Main">
    <div class="container">
      <RouterLink class="navbar-brand" :to="{ name: 'home' }">
        <span class="brand-mark"><i class="bi bi-house-door-fill" aria-hidden="true"></i></span>
        RoB Property
      </RouterLink>
      <button
        class="navbar-toggler border-0"
        type="button"
        aria-controls="mainNav"
        :aria-expanded="menuOpen"
        aria-label="Toggle navigation"
        @click="menuOpen = !menuOpen"
      >
        <i class="bi fs-2" :class="menuOpen ? 'bi-x-lg' : 'bi-list'" aria-hidden="true"></i>
      </button>

      <div id="mainNav" class="collapse navbar-collapse" :class="{ show: menuOpen }">
        <ul class="navbar-nav me-auto ms-lg-4 gap-lg-1">
          <li class="nav-item">
            <RouterLink class="nav-link" :to="{ name: 'properties' }">Properties</RouterLink>
          </li>
          <li class="nav-item">
            <RouterLink class="nav-link" :to="{ name: 'map' }">Map</RouterLink>
          </li>
          <li class="nav-item">
            <RouterLink class="nav-link" :to="{ name: 'compare' }">
              Compare
              <span v-if="compare.count" class="count-pill">
                {{ compare.count }}<span class="visually-hidden"> selected</span>
              </span>
            </RouterLink>
          </li>
          <template v-if="auth.isLoggedIn">
            <li class="nav-item">
              <RouterLink class="nav-link" :to="{ name: 'liked' }">Liked</RouterLink>
            </li>
            <li class="nav-item">
              <RouterLink class="nav-link" :to="{ name: 'appointments' }">My viewings</RouterLink>
            </li>
          </template>
          <li v-if="auth.isOwner" class="nav-item dropdown">
            <a
              class="nav-link dropdown-toggle"
              :class="{ active: ownerSection }"
              href="#"
              role="button"
              data-bs-toggle="dropdown"
              aria-expanded="false"
            >
              Owner
              <span v-if="pending.count" class="count-pill">
                {{ pending.count }}<span class="visually-hidden"> pending requests</span>
              </span>
            </a>
            <ul class="dropdown-menu shadow-sm">
              <li>
                <RouterLink class="dropdown-item" :to="{ name: 'owner-listings' }">
                  <i class="bi bi-buildings me-2" aria-hidden="true"></i>My listings
                </RouterLink>
              </li>
              <li>
                <RouterLink class="dropdown-item" :to="{ name: 'listing-create' }">
                  <i class="bi bi-plus-square me-2" aria-hidden="true"></i>New listing
                </RouterLink>
              </li>
              <li>
                <RouterLink class="dropdown-item" :to="{ name: 'owner-availability' }">
                  <i class="bi bi-calendar3 me-2" aria-hidden="true"></i>Availability
                </RouterLink>
              </li>
              <li>
                <RouterLink class="dropdown-item" :to="{ name: 'owner-requests' }">
                  <i class="bi bi-inbox me-2" aria-hidden="true"></i>Viewing requests
                  <span v-if="pending.count" class="badge rounded-pill text-bg-primary ms-auto">
                    {{ pending.count }}<span class="visually-hidden"> pending</span>
                  </span>
                </RouterLink>
              </li>
            </ul>
          </li>
        </ul>

        <div class="d-flex flex-wrap align-items-center gap-2 py-3 py-lg-0">
          <template v-if="!auth.isLoggedIn">
            <RouterLink class="btn btn-outline-secondary" :to="{ name: 'login' }"
              >Log in</RouterLink
            >
            <RouterLink class="btn btn-primary" :to="{ name: 'register' }">Register</RouterLink>
          </template>
          <template v-else>
            <RouterLink
              v-if="auth.isOwner"
              class="btn btn-primary d-none d-xl-inline-flex"
              :to="{ name: 'listing-create' }"
            >
              <i class="bi bi-plus-lg" aria-hidden="true"></i>List a property
            </RouterLink>
            <div class="dropdown">
              <button
                class="btn btn-link text-decoration-none px-0 d-flex align-items-center gap-2"
                type="button"
                data-bs-toggle="dropdown"
                aria-expanded="false"
              >
                <span class="avatar" aria-hidden="true">{{ initials(auth.user.full_name) }}</span>
                <span class="fw-semibold text-body d-lg-none d-xl-inline">{{ firstName }}</span>
                <span class="visually-hidden">Account menu</span>
                <i class="bi bi-chevron-down small text-muted" aria-hidden="true"></i>
              </button>
              <ul class="dropdown-menu dropdown-menu-lg-end shadow-sm">
                <li>
                  <h6 class="dropdown-header">
                    {{ auth.user.email }}<br /><span class="text-capitalize">{{
                      auth.user.role
                    }}</span>
                    account
                  </h6>
                </li>
                <li>
                  <RouterLink class="dropdown-item" :to="{ name: 'profile' }">
                    <i class="bi bi-person me-2" aria-hidden="true"></i>Profile
                  </RouterLink>
                </li>
                <li><hr class="dropdown-divider" /></li>
                <li>
                  <button class="dropdown-item" type="button" @click="handleLogout">
                    <i class="bi bi-box-arrow-right me-2" aria-hidden="true"></i>Log out
                  </button>
                </li>
              </ul>
            </div>
          </template>
        </div>
      </div>
    </div>
  </nav>
</template>

<style scoped>
.rob-nav {
  background: #fff;
  border-bottom: 1px solid var(--rob-line);
  min-height: var(--rob-nav-height);
}
.navbar-brand {
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.25rem;
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
.navbar-toggler {
  width: 44px;
  height: 44px;
  padding: 0;
}
.navbar-toggler:focus {
  box-shadow: none;
}
.navbar-toggler:focus-visible {
  box-shadow: 0 0 0 0.25rem var(--bs-focus-ring-color);
}
.nav-link {
  font-weight: 600;
  color: var(--rob-muted);
  padding: 0.625rem 0.875rem !important;
  border-radius: var(--rob-radius);
}
.nav-link:hover {
  color: var(--rob-ink);
  background: var(--rob-surface);
}
.nav-link.router-link-active,
.nav-link.active {
  color: var(--rob-primary);
}
.dropdown-item {
  min-height: 44px;
  display: flex;
  align-items: center;
}
.dropdown-item.router-link-active {
  color: var(--rob-primary);
  background: var(--rob-primary-subtle);
}
/* phone menu: separate it from the page underneath (desktop has no menu panel) */
.navbar-collapse.show {
  border-top: 1px solid var(--rob-line);
  margin-top: 0.5rem;
  padding-top: 0.5rem;
}
@media (min-width: 992px) {
  .navbar-collapse.show {
    border-top: 0;
    margin-top: 0;
    padding-top: 0;
  }
}
</style>

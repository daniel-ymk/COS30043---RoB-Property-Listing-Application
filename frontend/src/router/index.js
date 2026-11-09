import { createRouter, createWebHistory, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

// Route map from docs/api.md section 5.
// meta.requiresAuth  - any logged-in user
// meta.requiresOwner - logged in with role 'owner'
// meta.guestOnly     - login/register, hidden once logged in
// meta.hideFooter    - full-height pages without the footer
// Guards only hide pages; the API still enforces every rule.
const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('@/views/HomeView.vue'),
    meta: { title: 'Home' },
  },
  {
    path: '/properties',
    name: 'properties',
    component: () => import('@/views/PropertyListView.vue'),
    meta: { title: 'Properties' },
  },
  {
    path: '/properties/:id(\\d+)',
    name: 'property-detail',
    component: () => import('@/views/PropertyDetailView.vue'),
    props: (route) => ({ id: Number(route.params.id) }),
    meta: { title: 'Property' },
  },
  {
    path: '/map',
    name: 'map',
    component: () => import('@/views/MapView.vue'),
    meta: { title: 'Map search', hideFooter: true },
  },
  {
    path: '/compare',
    name: 'compare',
    component: () => import('@/views/CompareView.vue'),
    meta: { title: 'Compare' },
  },
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/LoginView.vue'),
    meta: { title: 'Log in', guestOnly: true, hideFooter: true },
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('@/views/RegisterView.vue'),
    meta: { title: 'Register', guestOnly: true, hideFooter: true },
  },
  {
    path: '/liked',
    name: 'liked',
    component: () => import('@/views/LikedView.vue'),
    meta: { title: 'Liked properties', requiresAuth: true },
  },
  {
    path: '/appointments',
    name: 'appointments',
    component: () => import('@/views/AppointmentsView.vue'),
    meta: { title: 'My viewings', requiresAuth: true },
  },
  {
    path: '/profile',
    name: 'profile',
    component: () => import('@/views/ProfileView.vue'),
    meta: { title: 'Profile', requiresAuth: true },
  },
  {
    path: '/owner/listings',
    name: 'owner-listings',
    component: () => import('@/views/owner/MyListingsView.vue'),
    meta: { title: 'My listings', requiresAuth: true, requiresOwner: true },
  },
  {
    path: '/owner/listings/new',
    name: 'listing-create',
    component: () => import('@/views/owner/ListingFormView.vue'),
    meta: { title: 'New listing', requiresAuth: true, requiresOwner: true },
  },
  {
    // Same form as create; the API returns 403 if the listing is not yours.
    path: '/owner/listings/:id(\\d+)/edit',
    name: 'listing-edit',
    component: () => import('@/views/owner/ListingFormView.vue'),
    props: (route) => ({ id: Number(route.params.id) }),
    meta: { title: 'Edit listing', requiresAuth: true, requiresOwner: true },
  },
  {
    path: '/owner/availability',
    name: 'owner-availability',
    component: () => import('@/views/owner/AvailabilityView.vue'),
    meta: { title: 'Availability', requiresAuth: true, requiresOwner: true },
  },
  {
    path: '/owner/requests',
    name: 'owner-requests',
    component: () => import('@/views/owner/RequestsView.vue'),
    meta: { title: 'Viewing requests', requiresAuth: true, requiresOwner: true },
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'not-found',
    component: () => import('@/views/NotFoundView.vue'),
    meta: { title: 'Page not found' },
  },
]

const router = createRouter({
  // Hash URLs (/#/properties/5) need no server rewrite; use them only if
  // the host can't send every path to index.html (see .env.mercury)
  history:
    import.meta.env.VITE_ROUTER_MODE === 'hash'
      ? createWebHashHistory(import.meta.env.BASE_URL)
      : createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior(to, from, savedPosition) {
    return savedPosition ?? { top: 0 }
  },
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.init()

  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (to.meta.requiresOwner && !auth.isOwner) {
    return { name: 'home' }
  }
  if (to.meta.guestOnly && auth.isLoggedIn) {
    return { name: 'home' }
  }
})

router.afterEach((to) => {
  document.title = to.meta.title ? `${to.meta.title} | RoB Property` : 'RoB Property'
})

export default router

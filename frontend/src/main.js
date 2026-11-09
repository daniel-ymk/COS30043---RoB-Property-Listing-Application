import 'bootstrap/dist/css/bootstrap.min.css'
// ESM build: registers data-bs-* behaviour and lets views import plugins
import 'bootstrap'
import 'bootstrap-icons/font/bootstrap-icons.min.css'
import 'leaflet/dist/leaflet.css'
// Fonts are bundled so the site makes no Google Fonts request
import '@fontsource/lexend/latin-500.css'
import '@fontsource/lexend/latin-600.css'
import '@fontsource/lexend/latin-700.css'
import '@fontsource/source-sans-3/latin-400.css'
import '@fontsource/source-sans-3/latin-600.css'
import '@fontsource/source-sans-3/latin-700.css'
import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import router from './router'
import { onUnauthorized } from './api/client'
import { useAuthStore } from './stores/auth'

const app = createApp(App)

app.use(createPinia())
app.use(router)

// docs/api.md: on any 401 the session has ended, so clear it and send the
// user to log in, then back to where they were.
onUnauthorized(() => {
  const auth = useAuthStore()
  const wasLoggedIn = auth.isLoggedIn
  auth.clear()
  const route = router.currentRoute.value
  if (wasLoggedIn || route.meta.requiresAuth) {
    router.push({ name: 'login', query: { redirect: route.fullPath } })
  }
})

app.mount('#app')

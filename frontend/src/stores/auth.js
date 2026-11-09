import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import * as authApi from '@/api/auth'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const ready = ref(false)
  let initPromise = null

  const isLoggedIn = computed(() => user.value !== null)
  const isOwner = computed(() => user.value?.role === 'owner')

  // Restores the session once per page load; the router awaits this.
  function init() {
    initPromise ??= (async () => {
      try {
        user.value = await authApi.fetchCurrentUser()
      } catch {
        user.value = null
      } finally {
        ready.value = true
      }
    })()
    return initPromise
  }

  async function login(email, password, remember = false) {
    user.value = await authApi.login(email, password, remember)
  }

  async function register(form) {
    user.value = await authApi.register(form)
  }

  async function logout() {
    try {
      await authApi.logout()
    } finally {
      user.value = null
    }
  }

  // After PATCH /me, so the navbar shows the new name at once
  function setUser(updated) {
    user.value = updated
  }

  // Call when any API request returns 401 (session expired).
  function clear() {
    user.value = null
  }

  return { user, ready, isLoggedIn, isOwner, init, login, register, logout, setUser, clear }
})

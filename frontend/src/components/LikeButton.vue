<script setup>
import { computed } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useLikesStore } from '@/stores/likes'

// Heart toggle for one listing. Guests get a link to log in instead, and an
// owner's own listings get no heart (the API refuses those likes).
const props = defineProps({
  property: { type: Object, required: true },
})

const auth = useAuthStore()
const likes = useLikesStore()
const route = useRoute()
const loginLink = computed(() => ({ name: 'login', query: { redirect: route.fullPath } }))
const liked = computed(() => likes.isLiked(props.property))
</script>

<template>
  <RouterLink
    v-if="!auth.isLoggedIn"
    class="like-btn"
    :to="loginLink"
    :aria-label="`Log in to save ${property.title}`"
  >
    <i class="bi bi-heart" aria-hidden="true"></i>
  </RouterLink>
  <button
    v-else-if="!property.is_mine"
    class="like-btn"
    type="button"
    :aria-pressed="liked ? 'true' : 'false'"
    :aria-label="`Save ${property.title}`"
    @click="likes.toggle(property)"
  >
    <i class="bi" :class="liked ? 'bi-heart-fill' : 'bi-heart'" aria-hidden="true"></i>
  </button>
</template>

<style scoped>
.like-btn {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: 0;
  background: rgb(255 255 255 / 0.95);
  color: var(--rob-ink);
  display: grid;
  place-items: center;
  box-shadow: var(--rob-shadow);
  transition:
    transform 0.15s var(--rob-ease),
    color 0.15s;
}
.like-btn:hover {
  transform: scale(1.08);
}
.like-btn[aria-pressed='true'] {
  color: var(--rob-danger);
}
@media (prefers-reduced-motion: reduce) {
  .like-btn {
    transition: none;
  }
}
</style>

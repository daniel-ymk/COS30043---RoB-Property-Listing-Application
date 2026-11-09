<script setup>
import { ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import notFoundImage from '@/assets/img/not-found.jpg'

const router = useRouter()
const q = ref('')

function search() {
  const text = q.value.trim()
  router.push({ name: 'properties', query: text ? { q: text } : {} })
}
</script>

<template>
  <div class="container py-5">
    <div class="row align-items-center g-4 g-lg-5 py-lg-5">
      <div class="col-lg-6">
        <p class="text-primary fw-bold mb-2">Error 404</p>
        <h1 class="display-5 mb-3">This page has moved out</h1>
        <p class="lead text-muted mb-4">
          The link may be old, or the listing was removed by its owner.
        </p>
        <form class="mb-4 search" role="search" @submit.prevent="search">
          <label class="form-label" for="nf-q">Search for a home instead</label>
          <div class="input-group">
            <input
              id="nf-q"
              v-model="q"
              class="form-control"
              type="search"
              placeholder="Area, city or property name"
            />
            <button class="btn btn-primary" type="submit">
              <i class="bi bi-search" aria-hidden="true"></i>Search
            </button>
          </div>
        </form>
        <div class="d-flex flex-wrap gap-2">
          <RouterLink class="btn btn-outline-secondary" :to="{ name: 'home' }">
            <i class="bi bi-house" aria-hidden="true"></i>Go to home
          </RouterLink>
          <RouterLink class="btn btn-outline-secondary" :to="{ name: 'map' }">
            <i class="bi bi-map" aria-hidden="true"></i>Search on the map
          </RouterLink>
        </div>
      </div>
      <div class="col-lg-6">
        <img :src="notFoundImage" alt="" class="photo" />
      </div>
    </div>
  </div>
</template>

<style scoped>
.search {
  max-width: 460px;
}
.photo {
  width: 100%;
  aspect-ratio: 4 / 3;
  object-fit: cover;
  border-radius: 1rem;
}
</style>

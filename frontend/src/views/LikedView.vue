<script setup>
import { computed, watch, onMounted } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { listLikes } from '@/api/likes'
import { useAsync } from '@/composables/useAsync'
import { useLikesStore } from '@/stores/likes'
import { useCompareStore, COMPARE_MAX } from '@/stores/compare'
import { useToastStore } from '@/stores/toast'
import PropertyGrid from '@/components/PropertyGrid.vue'
import EmptyState from '@/components/EmptyState.vue'
import AppPagination from '@/components/AppPagination.vue'

const PER_PAGE = 12

const route = useRoute()
const router = useRouter()
const likes = useLikesStore()
const compare = useCompareStore()
const toast = useToastStore()

const page = computed(() => Math.max(1, Number.parseInt(route.query.page, 10) || 1))
const result = useAsync(() => listLikes({ page: page.value, per_page: PER_PAGE }))

// Un-liking here removes the card at once; "Undo" in the toast brings it back
const shown = computed(() => (result.data.value ?? []).filter((p) => likes.isLiked(p)))
const removedHere = computed(() => (result.data.value?.length ?? 0) - shown.value.length)
const total = computed(() => (result.meta.value?.total ?? 0) - removedHere.value)
const countText = computed(() => {
  if (!result.meta.value) return ''
  if (!total.value) return 'Nothing saved yet'
  return total.value === 1 ? '1 home saved' : `${total.value} homes saved`
})

function compareLiked() {
  const ids = shown.value.map((p) => p.property_id).slice(0, COMPARE_MAX)
  compare.clear()
  ids.forEach(compare.add)
  if (shown.value.length > COMPARE_MAX) {
    toast.show(`Comparing your first ${COMPARE_MAX} liked homes`, { icon: 'info-circle' })
  }
  router.push({ name: 'compare' })
}

watch(
  () => route.query.page,
  () => route.name === 'liked' && result.run(),
)
onMounted(result.run)
</script>

<template>
  <div class="container">
    <div class="page-head d-flex flex-wrap justify-content-between align-items-end gap-3">
      <div>
        <h1 class="h2 mb-1">Liked properties</h1>
        <p class="text-muted mb-0" aria-live="polite">{{ countText }}</p>
      </div>
      <button
        v-if="shown.length > 1"
        class="btn btn-outline-secondary"
        type="button"
        @click="compareLiked"
      >
        <i class="bi bi-layout-three-columns" aria-hidden="true"></i>Compare liked homes
      </button>
    </div>

    <PropertyGrid
      :properties="shown"
      :loading="result.loading.value"
      :error="result.error.value"
      what="your liked homes"
      cols="row-cols-1 row-cols-sm-2 row-cols-lg-3 row-cols-xl-4"
      :skeletons="8"
      @retry="result.run"
    >
      <EmptyState
        icon="heart"
        title="No liked homes yet"
        text="Tap the heart on any listing to keep it here for later."
      >
        <RouterLink class="btn btn-primary" :to="{ name: 'properties' }"
          >Browse properties</RouterLink
        >
      </EmptyState>
    </PropertyGrid>

    <AppPagination
      v-if="result.meta.value && shown.length && !result.loading.value"
      class="mt-5"
      :meta="result.meta.value"
      label="liked home"
    />
  </div>
</template>

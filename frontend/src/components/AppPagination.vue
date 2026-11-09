<script setup>
import { computed } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

// Page links that keep the current filters: ?page=N is merged into the URL.
// meta is the API's { page, per_page, total, total_pages }.
const props = defineProps({
  meta: { type: Object, required: true },
  // singular noun; an s is added when there is more than one
  label: { type: String, default: 'result' },
})

const route = useRoute()

const first = computed(() => (props.meta.page - 1) * props.meta.per_page + 1)
const last = computed(() => Math.min(props.meta.page * props.meta.per_page, props.meta.total))

// 1 … 4 5 6 … 12  (null = gap)
const pages = computed(() => {
  const { page, total_pages: total } = props.meta
  const wanted = new Set([1, total, page - 1, page, page + 1])
  const list = []
  for (let n = 1; n <= total; n++) {
    if (wanted.has(n)) list.push(n)
    else if (list.at(-1) !== null) list.push(null)
  }
  return list
})

function linkTo(page) {
  const query = { ...route.query, page: String(page) }
  if (page === 1) delete query.page
  return { query }
}
</script>

<template>
  <nav
    v-if="meta.total"
    class="pager d-flex justify-content-between align-items-center flex-wrap gap-3"
    aria-label="Pages"
  >
    <span class="text-muted small"
      >Showing {{ first }}–{{ last }} of {{ meta.total }}
      {{ meta.total === 1 ? label : `${label}s` }}</span
    >
    <ul v-if="meta.total_pages > 1" class="pagination mb-0">
      <li class="page-item" :class="{ disabled: meta.page === 1 }">
        <span v-if="meta.page === 1" class="page-link">
          <i class="bi bi-chevron-left" aria-hidden="true"></i
          ><span class="visually-hidden">Previous page</span>
        </span>
        <RouterLink v-else class="page-link" :to="linkTo(meta.page - 1)">
          <i class="bi bi-chevron-left" aria-hidden="true"></i
          ><span class="visually-hidden">Previous page</span>
        </RouterLink>
      </li>
      <template v-for="(n, i) in pages" :key="n ?? `gap-${i}`">
        <li v-if="n === null" class="page-item disabled d-none d-sm-block">
          <span class="page-link">…</span>
        </li>
        <li
          v-else
          class="page-item"
          :class="{ active: n === meta.page, 'd-none d-sm-block': Math.abs(n - meta.page) > 1 }"
        >
          <span v-if="n === meta.page" class="page-link" aria-current="page">{{ n }}</span>
          <RouterLink v-else class="page-link" :to="linkTo(n)">
            <span class="visually-hidden">Page </span>{{ n }}
          </RouterLink>
        </li>
      </template>
      <li class="page-item" :class="{ disabled: meta.page === meta.total_pages }">
        <span v-if="meta.page === meta.total_pages" class="page-link">
          <i class="bi bi-chevron-right" aria-hidden="true"></i
          ><span class="visually-hidden">Next page</span>
        </span>
        <RouterLink v-else class="page-link" :to="linkTo(meta.page + 1)">
          <i class="bi bi-chevron-right" aria-hidden="true"></i
          ><span class="visually-hidden">Next page</span>
        </RouterLink>
      </li>
    </ul>
  </nav>
</template>

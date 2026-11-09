<script setup>
import { ref, computed } from 'vue'

// Box at the top of a form listing every error, each linking to its field.
// Call focus() after a failed submit so screen readers read it first.
const props = defineProps({
  // [{ field, message }] from useForm().errorList
  errors: { type: Array, required: true },
  idPrefix: { type: String, default: '' },
})

const box = ref(null)
const title = computed(() =>
  props.errors.length === 1 ? 'Please fix 1 thing' : `Please fix ${props.errors.length} things`,
)

function goTo(field) {
  document.getElementById(props.idPrefix + field)?.focus()
}

defineExpose({ focus: () => box.value?.focus() })
</script>

<template>
  <div
    v-if="errors.length"
    ref="box"
    class="error-summary mb-4"
    role="alert"
    tabindex="-1"
    aria-labelledby="error-summary-title"
  >
    <h2 id="error-summary-title">{{ title }}</h2>
    <ul class="mb-0 ps-3">
      <li v-for="item in errors" :key="item.field">
        <a :href="`#${idPrefix}${item.field}`" @click.prevent="goTo(item.field)">
          {{ item.message }}
        </a>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.error-summary {
  border: 2px solid var(--rob-danger);
  border-radius: var(--rob-radius);
  padding: 1rem 1.25rem;
  background: #fef2f2;
}
.error-summary:focus {
  outline: 3px solid #991b1b;
  outline-offset: 2px;
}
h2 {
  font-size: 1.0625rem;
  color: #991b1b;
  margin-bottom: 0.25rem;
}
a {
  color: #991b1b;
  font-weight: 600;
}
</style>

<script setup>
import { computed } from 'vue'
import { useCompareStore, COMPARE_MAX } from '@/stores/compare'
import { useToastStore } from '@/stores/toast'

const props = defineProps({
  propertyId: { type: Number, required: true },
})

const compare = useCompareStore()
const toast = useToastStore()
const inputId = computed(() => `compare-${props.propertyId}`)

function onChange(event) {
  if (!event.target.checked) {
    compare.remove(props.propertyId)
  } else if (!compare.add(props.propertyId)) {
    event.target.checked = false
    toast.show(`You can compare up to ${COMPARE_MAX} properties`, { icon: 'info-circle' })
  }
}
</script>

<template>
  <div class="compare-check form-check mb-0">
    <input
      :id="inputId"
      class="form-check-input"
      type="checkbox"
      :checked="compare.has(propertyId)"
      @change="onChange"
    />
    <label class="form-check-label" :for="inputId">Compare</label>
  </div>
</template>

<style scoped>
.compare-check {
  position: relative;
  z-index: 2; /* above the card's full-size link */
  font-size: 0.875rem;
  color: var(--rob-muted);
  min-height: 44px;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding-left: 0;
}
.compare-check .form-check-input {
  margin: 0;
  width: 1.25rem;
  height: 1.25rem;
}
</style>

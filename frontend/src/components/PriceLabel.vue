<script setup>
import { money } from '@/utils/format'

defineProps({
  price: { type: Number, required: true },
  listingType: { type: String, required: true },
})
</script>

<template>
  <span class="price">{{ money(price) }}<small v-if="listingType === 'rent'"> /month</small></span>
</template>

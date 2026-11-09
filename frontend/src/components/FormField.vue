<script setup>
import { computed } from 'vue'

// Label + input + help text + error message, wired together for screen
// readers. The input goes in the default slot and receives the ids:
//   <FormField id="email" label="Email" :error="form.errors.email" v-slot="field">
//     <input v-bind="field.attrs" v-model="form.values.email" class="form-control">
//   </FormField>
const props = defineProps({
  id: { type: String, required: true },
  label: { type: String, required: true },
  help: { type: String, default: '' },
  error: { type: String, default: '' },
  optional: { type: Boolean, default: false },
  // "+" prefix box for phone numbers
  prefix: { type: String, default: '' },
})

const helpId = computed(() => `${props.id}-help`)
const errorId = computed(() => `${props.id}-error`)
const attrs = computed(() => ({
  id: props.id,
  'aria-invalid': props.error ? 'true' : 'false',
  'aria-describedby':
    [props.help && helpId.value, props.error && errorId.value].filter(Boolean).join(' ') ||
    undefined,
  class: { 'is-invalid': !!props.error },
}))
</script>

<template>
  <div class="form-field">
    <label class="form-label" :for="id">
      {{ label }}<span v-if="optional" class="text-muted fw-normal"> (optional)</span>
    </label>
    <div v-if="prefix" class="input-group has-validation">
      <span class="input-group-text">{{ prefix }}</span>
      <slot :attrs="attrs"></slot>
      <div v-if="error" :id="errorId" class="invalid-feedback">{{ error }}</div>
    </div>
    <template v-else>
      <slot :attrs="attrs"></slot>
      <div v-if="error" :id="errorId" class="invalid-feedback">{{ error }}</div>
    </template>
    <div v-if="help" :id="helpId" class="form-text">{{ help }}</div>
  </div>
</template>

<style scoped>
/* Bootstrap only shows .invalid-feedback after an .is-invalid sibling; the
   message is already conditional, so always show it */
.invalid-feedback {
  display: block;
}
</style>

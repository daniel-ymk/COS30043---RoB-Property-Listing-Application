import { reactive, ref, computed, watch, nextTick } from 'vue'

// Form state shared by every form page.
//   const form = useForm({ email: '' }, { email: (v) => rules.email(v) })
//   <input v-model="form.values.email" @blur="form.touch('email', $event)">
// A field shows its error after it is left (blur) or after a submit, and is
// re-checked while typing from then on, so the message clears as soon as
// the value is fixed.
export function useForm(initial, rules) {
  const values = reactive({ ...initial })
  const errors = reactive({})
  const touched = reactive({})
  const submitted = ref(false)

  const errorList = computed(() =>
    Object.entries(errors)
      .filter(([, message]) => message)
      .map(([field, message]) => ({ field, message })),
  )
  const hasErrors = computed(() => errorList.value.length > 0)

  function validate(field) {
    errors[field] = rules[field]?.(values[field], values) ?? ''
    return !errors[field]
  }

  // Call from @blur with $event. When focus is moving to the submit or reset
  // button, wait: showing the message now would push the button down under
  // the pointer and swallow the click. Submit checks every field anyway.
  function touch(field, event) {
    if (['submit', 'reset'].includes(event?.relatedTarget?.type)) return
    touched[field] = true
    validate(field)
  }

  // Re-check fields the user has already left (also clears server errors)
  for (const field of Object.keys(rules)) {
    watch(
      () => values[field],
      () => {
        if (touched[field] || submitted.value) validate(field)
      },
    )
  }

  // Checks every field; returns true when the form can be sent.
  function validateAll() {
    submitted.value = true
    Object.keys(rules).forEach(validate)
    return !hasErrors.value
  }

  // Puts a 422 response's fields under their inputs.
  function setServerErrors(fields = {}) {
    submitted.value = true
    Object.assign(errors, fields)
  }

  function reset(newValues = initial) {
    Object.assign(values, newValues)
    submitted.value = false
    for (const key of Object.keys(errors)) delete errors[key]
    for (const key of Object.keys(touched)) delete touched[key]
  }

  // Moves focus to the first field with an error (inputs use the field name as id)
  async function focusFirstError(idPrefix = '') {
    await nextTick()
    const first = errorList.value[0]
    if (first) document.getElementById(idPrefix + first.field)?.focus()
  }

  return {
    values,
    errors,
    errorList,
    hasErrors,
    submitted,
    touch,
    validate,
    validateAll,
    setServerErrors,
    reset,
    focusFirstError,
  }
}

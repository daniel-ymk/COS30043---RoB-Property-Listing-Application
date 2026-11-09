<script setup>
import { ref, computed, nextTick, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useForm } from '@/composables/useForm'
import { updateProfile } from '@/api/profile'
import { fullName, phone } from '@/utils/validation'
import { initials } from '@/utils/format'
import FormField from '@/components/FormField.vue'
import ErrorSummary from '@/components/ErrorSummary.vue'

const auth = useAuthStore()
const toast = useToastStore()

const isOwner = computed(() => auth.isOwner)
const saved = () => ({ full_name: auth.user.full_name, phone: auth.user.phone ?? '' })

const form = useForm(saved(), {
  full_name: (v) => fullName(v),
  phone: (v) => phone(v, isOwner.value),
})
const summary = ref(null)
const sending = ref(false)
const savedNotice = ref(false)
const failure = ref('')

// Only send what changed, so an untouched form makes no request
const changes = computed(() => {
  const result = {}
  if (form.values.full_name.trim() !== auth.user.full_name) {
    result.full_name = form.values.full_name.trim()
  }
  if (form.values.phone.trim() !== (auth.user.phone ?? '')) {
    result.phone = form.values.phone.trim()
  }
  return result
})
const dirty = computed(() => Object.keys(changes.value).length > 0)

// Editing again hides the "saved" message
watch(
  () => ({ ...form.values }),
  () => {
    if (dirty.value) savedNotice.value = false
  },
)

async function submit() {
  failure.value = ''
  savedNotice.value = false
  if (!form.validateAll()) {
    await nextTick()
    return summary.value?.focus()
  }
  if (!dirty.value) return

  sending.value = true
  try {
    auth.setUser(await updateProfile(changes.value))
    form.reset(saved())
    savedNotice.value = true
    toast.show('Profile saved')
  } catch (err) {
    if (err.status === 422) {
      form.setServerErrors(err.fields)
      await nextTick()
      summary.value?.focus()
    } else {
      failure.value = err.message
    }
  } finally {
    sending.value = false
  }
}

function discard() {
  form.reset(saved())
  failure.value = ''
}
</script>

<template>
  <div class="container profile">
    <div class="page-head">
      <h1 class="h2 mb-1">Profile</h1>
      <p class="text-muted mb-0">
        Your name and WhatsApp number are shown to the people you contact.
      </p>
    </div>

    <div v-if="savedNotice" class="alert alert-success d-flex gap-2" role="status">
      <i class="bi bi-check-circle" aria-hidden="true"></i>Profile saved.
    </div>
    <div v-if="failure" class="alert alert-danger d-flex gap-2" role="alert">
      <i class="bi bi-exclamation-octagon" aria-hidden="true"></i>
      <div>{{ failure }}</div>
    </div>
    <ErrorSummary ref="summary" :errors="form.submitted.value ? form.errorList.value : []" />

    <div class="panel mb-4">
      <div class="d-flex align-items-center gap-3 mb-4">
        <span class="avatar avatar-lg" aria-hidden="true">{{ initials(auth.user.full_name) }}</span>
        <div class="min-w-0">
          <div class="h5 mb-0 text-break">{{ auth.user.full_name }}</div>
          <div class="text-muted">{{ isOwner ? 'Owner account' : 'Viewer account' }}</div>
        </div>
      </div>

      <form novalidate @submit.prevent="submit" @reset.prevent="discard">
        <FormField
          v-slot="{ attrs }"
          id="full_name"
          class="mb-3"
          label="Full name"
          :error="form.errors.full_name"
        >
          <input
            v-bind="attrs"
            v-model="form.values.full_name"
            class="form-control"
            autocomplete="name"
            @blur="form.touch('full_name', $event)"
          />
        </FormField>

        <FormField
          v-slot="{ attrs }"
          id="email"
          class="mb-3"
          label="Email"
          help="Email can't be changed."
        >
          <input v-bind="attrs" class="form-control" :value="auth.user.email" disabled />
        </FormField>

        <FormField
          v-slot="{ attrs }"
          id="phone"
          class="mb-4"
          label="WhatsApp number"
          prefix="+"
          :optional="!isOwner"
          :help="
            isOwner
              ? 'Renters contact you on this number. Include the country code, e.g. 60 for Malaysia.'
              : 'Include the country code, e.g. 60 for Malaysia.'
          "
          :error="form.errors.phone"
        >
          <input
            v-bind="attrs"
            v-model="form.values.phone"
            class="form-control"
            inputmode="numeric"
            autocomplete="tel"
            placeholder="60123456789"
            @blur="form.touch('phone', $event)"
          />
        </FormField>

        <div class="d-flex flex-wrap gap-2 justify-content-end">
          <button class="btn btn-outline-secondary" type="reset" :disabled="!dirty || sending">
            Discard changes
          </button>
          <button class="btn btn-primary" type="submit" :disabled="!dirty || sending">
            <span v-if="sending" class="spinner-border spinner-border-sm" aria-hidden="true"></span>
            {{ sending ? 'Saving…' : 'Save changes' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
.profile {
  max-width: 760px;
}
.min-w-0 {
  min-width: 0;
}
</style>

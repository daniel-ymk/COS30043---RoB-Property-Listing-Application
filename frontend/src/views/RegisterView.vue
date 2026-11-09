<script setup>
import { ref, computed, nextTick } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useForm } from '@/composables/useForm'
import { fullName, email, newPassword, phone } from '@/utils/validation'
import { safeRedirect } from '@/utils/redirect'
import AuthSplit from '@/components/AuthSplit.vue'
import FormField from '@/components/FormField.vue'
import ErrorSummary from '@/components/ErrorSummary.vue'
import registerImage from '@/assets/img/auth-register.jpg'

const auth = useAuthStore()
const toast = useToastStore()
const route = useRoute()
const router = useRouter()

const ROLES = [
  { value: 'viewer', icon: 'search', title: 'Find a home', text: 'Rent or buy' },
  { value: 'owner', icon: 'key', title: 'List my property', text: "I'm an owner" },
]

const form = useForm(
  { role: 'viewer', full_name: '', email: '', phone: '', password: '' },
  {
    full_name: (v) => fullName(v),
    email: (v) => email(v),
    phone: (v, all) => phone(v, all.role === 'owner'),
    password: (v) => newPassword(v),
  },
)
const isOwner = computed(() => form.values.role === 'owner')
const summary = ref(null)
const sending = ref(false)
const failure = ref('')

async function showErrors() {
  await nextTick()
  summary.value?.focus()
}

async function submit() {
  failure.value = ''
  // A viewer never sends a phone number, so it can't block the form
  if (!isOwner.value) form.values.phone = ''
  if (!form.validateAll()) return showErrors()

  sending.value = true
  try {
    await auth.register({
      role: form.values.role,
      full_name: form.values.full_name.trim(),
      email: form.values.email.trim(),
      phone: isOwner.value ? form.values.phone.trim() : null,
      password: form.values.password,
    })
    toast.show(`Welcome to RoB Property, ${auth.user.full_name.split(' ')[0]}`)
    const home = isOwner.value ? '/owner/listings' : '/'
    router.replace(safeRedirect(route.query.redirect, home))
  } catch (err) {
    if (err.status === 422) {
      form.setServerErrors(err.fields)
      showErrors()
    } else {
      failure.value = err.message
    }
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <AuthSplit :image="registerImage" width="460px">
    <h1 class="h2 mb-1">Create your account</h1>
    <p class="text-muted mb-4">Free for renters, buyers and owners.</p>

    <div v-if="failure" class="alert alert-danger d-flex gap-2" role="alert">
      <i class="bi bi-exclamation-octagon" aria-hidden="true"></i>
      <div>{{ failure }}</div>
    </div>
    <ErrorSummary ref="summary" :errors="form.submitted.value ? form.errorList.value : []" />

    <form novalidate @submit.prevent="submit">
      <fieldset class="mb-4">
        <legend class="form-label fs-6">I want to</legend>
        <div class="row g-2">
          <div v-for="option in ROLES" :key="option.value" class="col-6">
            <input
              :id="`role-${option.value}`"
              v-model="form.values.role"
              type="radio"
              class="btn-check"
              name="role"
              :value="option.value"
            />
            <label
              class="btn btn-outline-secondary w-100 h-100 flex-column align-items-start text-start p-3"
              :for="`role-${option.value}`"
            >
              <i class="bi fs-4 text-primary" :class="`bi-${option.icon}`" aria-hidden="true"></i>
              <span>{{ option.title }}</span>
              <small class="fw-normal text-muted">{{ option.text }}</small>
            </label>
          </div>
        </div>
      </fieldset>

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
        :error="form.errors.email"
      >
        <input
          v-bind="attrs"
          v-model="form.values.email"
          class="form-control"
          type="email"
          autocomplete="email"
          @blur="form.touch('email', $event)"
        />
      </FormField>

      <FormField
        v-if="isOwner"
        v-slot="{ attrs }"
        id="phone"
        class="mb-3"
        label="WhatsApp number"
        prefix="+"
        help="Renters contact you on this number. Include the country code, e.g. 60 for Malaysia."
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

      <FormField
        v-slot="{ attrs }"
        id="password"
        class="mb-4"
        label="Password"
        help="At least 8 characters, with a letter and a number."
        :error="form.errors.password"
      >
        <input
          v-bind="attrs"
          v-model="form.values.password"
          class="form-control"
          type="password"
          autocomplete="new-password"
          @blur="form.touch('password', $event)"
        />
      </FormField>

      <button class="btn btn-primary btn-lg w-100" type="submit" :disabled="sending">
        <span v-if="sending" class="spinner-border spinner-border-sm" aria-hidden="true"></span>
        {{ sending ? 'Creating account…' : 'Create account' }}
      </button>
    </form>

    <p class="text-center mt-4 mb-0">
      Already have an account?
      <RouterLink class="fw-semibold" :to="{ name: 'login', query: route.query }"
        >Log in</RouterLink
      >
    </p>
  </AuthSplit>
</template>

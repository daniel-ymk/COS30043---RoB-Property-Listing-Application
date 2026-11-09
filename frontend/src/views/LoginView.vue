<script setup>
import { ref, computed } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useForm } from '@/composables/useForm'
import { email, passwordEntered } from '@/utils/validation'
import { safeRedirect } from '@/utils/redirect'
import AuthSplit from '@/components/AuthSplit.vue'
import FormField from '@/components/FormField.vue'
import loginImage from '@/assets/img/auth-login.jpg'

const auth = useAuthStore()
const toast = useToastStore()
const route = useRoute()
const router = useRouter()

const form = useForm(
  { email: '', password: '', remember: false },
  { email: (v) => email(v), password: (v) => passwordEntered(v) },
)
const showPassword = ref(false)
const sending = ref(false)
const failure = ref('') // wrong email/password or server down

const redirectTo = computed(() => safeRedirect(route.query.redirect))
// "Log in to continue to Liked properties" when a guard sent the user here
const redirectTitle = computed(() =>
  route.query.redirect ? router.resolve(redirectTo.value).meta.title : '',
)

async function submit() {
  failure.value = ''
  if (!form.validateAll()) return form.focusFirstError()

  sending.value = true
  try {
    await auth.login(form.values.email.trim(), form.values.password, form.values.remember)
    toast.show(`Welcome back, ${auth.user.full_name.split(' ')[0]}`)
    router.replace(redirectTo.value)
  } catch (err) {
    failure.value =
      err.status === 401
        ? "That email and password don't match an account. Check them and try again."
        : err.message
    form.values.password = ''
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <AuthSplit :image="loginImage">
    <h1 class="h2 mb-1">Welcome back</h1>
    <p class="text-muted mb-4">Log in to save homes, contact owners and book viewings.</p>

    <div v-if="failure" class="alert alert-danger d-flex gap-2" role="alert">
      <i class="bi bi-exclamation-octagon" aria-hidden="true"></i>
      <div>{{ failure }}</div>
    </div>
    <div v-else-if="redirectTitle" class="alert alert-info d-flex gap-2">
      <i class="bi bi-info-circle" aria-hidden="true"></i>
      <div>
        Log in to continue to <strong>{{ redirectTitle }}</strong
        >.
      </div>
    </div>

    <form novalidate @submit.prevent="submit">
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

      <div class="mb-2">
        <label class="form-label" for="password">Password</label>
        <div class="input-group has-validation">
          <input
            id="password"
            v-model="form.values.password"
            class="form-control"
            :class="{ 'is-invalid': form.errors.password }"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="current-password"
            :aria-invalid="form.errors.password ? 'true' : 'false'"
            :aria-describedby="form.errors.password ? 'password-error' : undefined"
            @blur="form.touch('password', $event)"
          />
          <button
            class="btn btn-outline-secondary"
            type="button"
            :aria-pressed="showPassword"
            aria-label="Show password"
            @click="showPassword = !showPassword"
          >
            <i class="bi" :class="showPassword ? 'bi-eye-slash' : 'bi-eye'" aria-hidden="true"></i>
          </button>
          <div v-if="form.errors.password" id="password-error" class="invalid-feedback d-block">
            {{ form.errors.password }}
          </div>
        </div>
      </div>

      <div class="form-check mb-4">
        <input
          id="remember"
          v-model="form.values.remember"
          class="form-check-input"
          type="checkbox"
        />
        <label class="form-check-label" for="remember">Keep me logged in</label>
      </div>

      <button class="btn btn-primary btn-lg w-100" type="submit" :disabled="sending">
        <span v-if="sending" class="spinner-border spinner-border-sm" aria-hidden="true"></span>
        {{ sending ? 'Logging in…' : 'Log in' }}
      </button>
    </form>

    <p class="text-center mt-4 mb-0">
      New to RoB Property?
      <RouterLink class="fw-semibold" :to="{ name: 'register', query: route.query }">
        Create an account
      </RouterLink>
    </p>
  </AuthSplit>
</template>

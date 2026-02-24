<template>
  <q-page class="flex flex-center no-scroll">
    <!-- Main Card -->
    <div class="login-card-container shadow-24">
      <!-- Left Panel: Illustration -->
      <div class="panel-left flex flex-center gt-xs">
        <div class="illustration-orb"></div>
        <div class="glass-overlay"></div>
        <q-img src="/login-illustration.png" class="illustration-img" fit="contain" />
      </div>

      <!-- Right Panel: Form -->
      <div class="panel-right q-pa-xl column items-center justify-center">
        <div class="form-wrapper full-width">
          <!-- Logo & Welcome -->
          <div class="text-center q-mb-xl">
            <div class="logo-img q-mb-sm" role="img" aria-label="VisionCore Logo"></div>
            <div class="text-h6 text-weight-bolder text-primary welcome-text">VISION CORE ERP</div>
          </div>

          <!-- Form Fields -->
          <q-form @submit="handleLogin" class="q-gutter-y-lg">
            <q-input
              v-model="email"
              placeholder="User Name"
              outlined
              dense
              bg-color="white"
              class="premium-input"
              :rules="[(val) => !!val || 'User name is required']"
              hide-bottom-space
            >
              <template v-slot:prepend>
                <q-icon name="person" color="primary" />
              </template>
            </q-input>

            <q-input
              v-model="password"
              placeholder="Password"
              outlined
              dense
              :type="isPwd ? 'password' : 'text'"
              bg-color="white"
              class="premium-input"
              :rules="[(val) => !!val || 'Password is required']"
              hide-bottom-space
            >
              <template v-slot:prepend>
                <q-icon name="lock" color="primary" />
              </template>
              <template v-slot:append>
                <q-icon
                  :name="isPwd ? 'visibility_off' : 'visibility'"
                  class="cursor-pointer"
                  @click="isPwd = !isPwd"
                  color="grey-7"
                />
              </template>
            </q-input>

            <q-btn
              type="submit"
              color="primary"
              label="Sign In"
              unelevated
              class="full-width login-btn q-mt-md"
              :loading="authStore.loading"
            />
          </q-form>

          <!-- Footer -->
          <div class="copyright-text text-center q-mt-xl opacity-50 text-caption">
            © VisionCore ERP 2026 All Rights Reserved.
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/stores/auth'
import { useQuasar } from 'quasar'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const isPwd = ref(true)

async function handleLogin() {
  const { error } = await authStore.signIn(email.value, password.value)
  if (!error) {
    const landing = authStore.defaultLandingPage
    router.push(landing)

    $q.notify({
      type: 'positive',
      message: `Welcome back, ${authStore.userDisplayName}!`,
      position: 'top',
      timeout: 2000,
    })
  } else {
    $q.notify({
      type: 'negative',
      message: error.message || 'Login failed',
      position: 'top',
    })
  }
}
</script>

<style scoped lang="scss">
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap');

.no-scroll {
  height: 100vh;
  width: 100vw;
  overflow: hidden !important;
  position: fixed;
  font-family:
    'Inter',
    -apple-system,
    BlinkMacSystemFont,
    'Segoe UI',
    Roboto,
    Helvetica,
    Arial,
    sans-serif !important;
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
}

.login-card-container {
  width: 960px;
  max-width: 95vw;
  height: min(650px, 90vh);
  display: flex;
  border-radius: 20px;
  overflow: hidden;
  background: white;
  z-index: 10;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.08);
}

.panel-left {
  flex: 1.25;
  background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
  position: relative;
  overflow: hidden;

  .illustration-orb {
    position: absolute;
    width: 600px;
    height: 600px;
    background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
    border-radius: 50%;
    top: -100px;
    left: -100px;
    z-index: 1;
  }

  .glass-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(135deg, rgba(30, 60, 114, 0.2) 0%, rgba(0, 0, 0, 0.3) 100%);
    z-index: 2;
  }
}

.illustration-img {
  width: 80%;
  max-width: 440px;
  z-index: 5;
  filter: drop-shadow(0 20px 40px rgba(0, 0, 0, 0.2));
}

.panel-right {
  flex: 0.9;
  background: white;
  position: relative;
}

.form-wrapper {
  max-width: 340px;
}

.logo-img {
  width: 155px;
  height: 155px;
  background-image: url('/logo.png');
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
  background-color: white;
  margin: 0 auto;
}

.welcome-text {
  font-family: 'Inter', sans-serif;
  letter-spacing: 1px;
  font-size: 1.25rem;
  color: #1e3c72;
  margin-top: 10px;
}

.premium-input {
  font-size: 14px;

  :deep(.q-field__control) {
    border-radius: 8px !important;
    background: #fdfdfd !important;
    height: 52px;
    border: 1.5px solid #eceef1 !important;
    transition: all 0.3s ease;

    &:before {
      display: none;
    }

    &:after {
      display: none;
    }

    &.q-field__control--focused {
      border-color: #1e3c72 !important;
      background: white !important;
      box-shadow: 0 0 0 4px rgba(30, 60, 114, 0.05);
    }
  }

  :deep(.q-field__native) {
    font-weight: 500;
  }

  :deep(.q-field__prepend) {
    padding-right: 12px;
    .q-icon {
      font-size: 20px;
    }
  }

  :deep(.q-field__append) {
    .q-icon {
      font-size: 20px;
    }
  }
}

.login-btn {
  height: 50px;
  border-radius: 8px;
  font-weight: 600;
  text-transform: none;
  font-size: 15px;
  background: #1e3c72 !important;
  transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 20px rgba(30, 60, 114, 0.2);
  }

  &:active {
    transform: translateY(0);
  }
}

.copyright-text {
  color: #6c757d;
  font-weight: 400;
  font-size: 12px;
}

/* Response handling */
@media (max-width: 600px) {
  .login-card-container {
    width: 90vw;
    height: auto;
    max-height: 90vh;
  }
  .panel-right {
    padding: 32px 24px !important;
  }
}
</style>

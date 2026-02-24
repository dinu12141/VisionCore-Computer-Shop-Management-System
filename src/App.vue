<template>
  <LoadingScreen :show="!authStore.initialized" />
  <router-view v-if="authStore.initialized" />
  <ToastContainer />
</template>

<script setup>
import { onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'stores/auth'
import LoadingScreen from 'components/LoadingScreen.vue'
import ToastContainer from 'components/common/ToastContainer.vue'

const $q = useQuasar()
const authStore = useAuthStore()

// Set dark mode preference
onMounted(() => {
  const isDark = localStorage.getItem('theme-dark') !== 'false'
  $q.dark.set(isDark)
})
</script>

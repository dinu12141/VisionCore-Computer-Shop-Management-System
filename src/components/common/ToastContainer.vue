<template>
  <div
    class="toast-container fixed-top-right q-pt-lg q-pr-md"
    style="z-index: 9999; pointer-events: none"
  >
    <ToastAlert
      v-for="toast in store.toasts"
      :key="toast.id"
      :message="toast.message"
      :type="toast.type"
      :duration="toast.duration"
      @close="store.removeToast(toast.id)"
    />
  </div>
</template>

<script setup>
import { useNotificationStore } from 'src/stores/notifications'
import ToastAlert from './ToastAlert.vue'

const store = useNotificationStore()
</script>

<style scoped>
.toast-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
</style>

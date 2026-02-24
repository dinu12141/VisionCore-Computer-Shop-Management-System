<template>
  <transition name="toast">
    <div
      v-if="visible"
      class="toast-alert flex items-center q-pa-sm q-mb-sm rounded-borders shadow-2"
      :class="typeClass"
    >
      <q-icon :name="icon" size="sm" class="q-mr-sm" />
      <div class="text-body2 text-weight-medium">{{ message }}</div>
      <q-space />
      <q-btn flat round dense icon="close" size="sm" @click="$emit('close')" />
    </div>
  </transition>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'

const props = defineProps({
  message: {
    type: String,
    required: true,
  },
  type: {
    type: String,
    default: 'info',
    validator: (value) => ['info', 'success', 'warning', 'error'].includes(value),
  },
  duration: {
    type: Number,
    default: 3000,
  },
})

const emit = defineEmits(['close'])
const visible = ref(false)

onMounted(() => {
  visible.value = true
  if (props.duration > 0) {
    setTimeout(() => {
      visible.value = false
      setTimeout(() => emit('close'), 300) // Wait for transition
    }, props.duration)
  }
})

const typeClass = computed(() => {
  switch (props.type) {
    case 'success':
      return 'bg-positive text-white'
    case 'warning':
      return 'bg-warning text-dark'
    case 'error':
      return 'bg-negative text-white'
    default:
      return 'bg-info text-white'
  }
})

const icon = computed(() => {
  switch (props.type) {
    case 'success':
      return 'check_circle'
    case 'warning':
      return 'warning'
    case 'error':
      return 'error'
    default:
      return 'info'
  }
})
</script>

<style scoped>
.toast-alert {
  min-width: 300px;
  max-width: 400px;
  pointer-events: auto;
}

.toast-enter-active,
.toast-leave-active {
  transition: all 0.3s ease;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
</style>

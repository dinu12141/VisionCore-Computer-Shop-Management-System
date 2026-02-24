<template>
  <q-dialog :model-value="show" persistent seamless>
    <div class="loading-screen">
      <div class="loading-content">
        <q-icon name="vignette" size="80px" color="primary" class="loading-icon" />
        <div class="loading-title">VisionCore ERP</div>
        <q-spinner-dots size="60px" color="primary" class="q-mt-lg" />
        <div class="loading-text">Initializing...</div>
      </div>
    </div>
  </q-dialog>
</template>

<script setup>
defineProps({
  show: {
    type: Boolean,
    default: true,
  },
})
</script>

<style scoped lang="scss">
.loading-screen {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: v-bind(
    "$q.dark.isActive ? 'linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)' : 'linear-gradient(135deg, #ffffff 0%, #f0f4f8 100%)'"
  );
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}

.loading-content {
  text-align: center;
  animation: fadeIn 0.5s ease-in;
}

.loading-icon {
  animation: pulse 2s ease-in-out infinite;
}

.loading-title {
  font-size: 2rem;
  font-weight: 600;
  color: v-bind("$q.dark.isActive ? '#ffffff' : '#2c3e50'");
  margin-top: 1rem;
  letter-spacing: 1px;
}

.loading-text {
  font-size: 1rem;
  color: #94a3b8;
  margin-top: 1rem;
  animation: blink 1.5s ease-in-out infinite;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes pulse {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.1);
  }
}

@keyframes blink {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}
</style>

<template>
  <div class="page-header q-mb-lg">
    <div class="page-header-inner row items-center justify-between no-wrap">
      <div class="row items-center no-wrap">
        <q-btn
          v-if="showBack"
          flat
          round
          dense
          icon="arrow_back"
          class="q-mr-md"
          color="primary"
          @click="$router.back()"
        />
        <div class="page-header-text">
          <div class="page-header-eyebrow" v-if="subtitle">{{ subtitle }}</div>
          <h1 class="page-header-title">{{ title }}</h1>
        </div>
      </div>
      <div class="row q-gutter-sm items-center page-header-actions" v-if="$slots.actions">
        <slot name="actions"></slot>
      </div>
    </div>
    <div class="page-header-divider"></div>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  showBack: { type: Boolean, default: false },
})
</script>

<style scoped lang="scss">
.page-header {
  position: relative;
}

.page-header-inner {
  gap: 16px;
  flex-wrap: wrap;
}

.page-header-eyebrow {
  font-size: 11.5px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--v-primary);
  margin-bottom: 4px;
  opacity: 0.85;
}

.page-header-title {
  font-size: 1.5rem;
  font-weight: 800;
  line-height: 1.25;
  margin: 0;
  letter-spacing: -0.02em;
  color: v-bind("$q.dark.isActive ? '#F1F5F9' : '#0F172A'");
}

.page-header-actions {
  flex-shrink: 0;
}

.page-header-divider {
  height: 1px;
  background: linear-gradient(
    90deg,
    var(--v-primary) 0%,
    rgba(139, 92, 246, 0.4) 40%,
    transparent 100%
  );
  margin-top: 14px;
  border-radius: 2px;
  opacity: 0.5;
}
</style>

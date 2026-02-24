<template>
  <div class="stock-level-bar">
    <div class="row justify-between text-caption q-mb-xs">
      <span>{{ label }}</span>
      <span :class="textColor">{{ current }} / {{ max || '∞' }} {{ unit }}</span>
    </div>

    <q-linear-progress rounded size="15px" :value="progress" :color="color" track-color="grey-8">
      <div class="absolute-full flex flex-center">
        <q-badge color="transparent" text-color="white" :label="progressLabel" />
      </div>
    </q-linear-progress>

    <div v-if="min" class="row justify-between text-caption text-grey-5 q-mt-xs">
      <span>Min: {{ min }}</span>
      <span v-if="max">Max: {{ max }}</span>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  current: {
    type: Number,
    required: true,
  },
  min: {
    type: Number,
    default: 0,
  },
  max: {
    type: Number,
    default: 100, // Default max for visualization if not provided
  },
  unit: {
    type: String,
    default: 'units',
  },
  label: {
    type: String,
    default: 'Stock Level',
  },
})

// Calculate progress percentage (clamped 0-1)
const progress = computed(() => {
  const effectiveMax = props.max || props.min * 2 || 100
  return Math.min(Math.max(props.current / effectiveMax, 0), 1)
})

const progressLabel = computed(() => {
  return `${Math.round(progress.value * 100)}%`
})

// Determine color based on stock level relative to min
const color = computed(() => {
  if (props.current <= props.min) return 'negative'
  if (props.current <= props.min * 1.2) return 'warning'
  return 'positive'
})

const textColor = computed(() => {
  if (props.current <= props.min) return 'text-negative text-weight-bold'
  if (props.current <= props.min * 1.2) return 'text-warning'
  return 'text-grey-4'
})
</script>

<style scoped>
.stock-level-bar {
  min-width: 150px;
}
</style>

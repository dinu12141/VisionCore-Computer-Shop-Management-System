<template>
  <q-card
    :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
    class="q-pa-md"
    flat
    bordered
  >
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h6">Revenue vs Profit Trend</div>
      <div class="text-caption text-grey">Period overview</div>
    </div>

    <div v-if="loading" class="flex flex-center" style="height: 300px">
      <q-spinner color="primary" size="3em" />
    </div>

    <div
      v-else-if="!data || data.length === 0"
      class="flex flex-center text-grey"
      style="height: 300px"
    >
      No data available for this range
    </div>

    <div v-else class="chart-container relative-position" style="height: 300px">
      <svg viewBox="0 0 100 50" class="full-width full-height" preserveAspectRatio="none">
        <!-- Grid Lines -->
        <line
          v-for="y in [10, 20, 30, 40]"
          :key="y"
          x1="0"
          :y1="y"
          x2="100"
          :y2="y"
          :stroke="$q.dark.isActive ? '#333' : '#eee'"
          stroke-width="0.1"
        />

        <!-- Area Gradient -->
        <defs>
          <linearGradient id="grad-rev" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color: var(--q-primary); stop-opacity: 0.3" />
            <stop offset="100%" style="stop-color: var(--q-primary); stop-opacity: 0" />
          </linearGradient>
        </defs>

        <!-- Revenue Path -->
        <path :d="revenueAreaPath" fill="url(#grad-rev)" />
        <polyline
          :points="revenuePoints"
          fill="none"
          stroke="var(--q-primary)"
          stroke-width="0.8"
          stroke-linecap="round"
          stroke-linejoin="round"
        />

        <!-- Profit Path -->
        <polyline
          :points="profitPoints"
          fill="none"
          stroke="#2e7d32"
          stroke-width="0.8"
          stroke-dasharray="1,1"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>

      <!-- Labels -->
      <div class="row justify-between text-grey-6 text-caption q-mt-sm" style="padding: 0 5px">
        <span v-for="(label, idx) in xLabels" :key="idx">{{ label }}</span>
      </div>

      <div class="row q-gutter-md q-mt-sm justify-center">
        <div class="row items-center q-gutter-xs">
          <div style="width: 12px; height: 12px; background: var(--q-primary)"></div>
          <span class="text-caption">Revenue</span>
        </div>
        <div class="row items-center q-gutter-xs">
          <div
            style="width: 12px; height: 12px; background: #2e7d32; border: 1px dashed #fff"
          ></div>
          <span class="text-caption">Profit</span>
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup>
import { computed } from 'vue'
import { useQuasar, date } from 'quasar'

const props = defineProps({
  data: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
})

const $q = useQuasar()

const maxVal = computed(() => {
  if (!props.data.length) return 100
  return Math.max(...props.data.map((d) => Number(d.revenue)), 100) * 1.1
})

const points = computed(() => {
  if (!props.data.length) return []
  const step = 100 / (props.data.length - 1 || 1)
  return props.data.map((d, i) => ({
    x: i * step,
    ry: 50 - (Number(d.revenue) / maxVal.value) * 50,
    py: 50 - (Number(d.profit) / maxVal.value) * 50,
  }))
})

const revenuePoints = computed(() => points.value.map((p) => `${p.x},${p.ry}`).join(' '))
const profitPoints = computed(() => points.value.map((p) => `${p.x},${p.py}`).join(' '))

const revenueAreaPath = computed(() => {
  if (!points.value.length) return ''
  const p = points.value
  return (
    `M${p[0].x},50 ` + p.map((pt) => `L${pt.x},${pt.ry}`).join(' ') + ` L${p[p.length - 1].x},50 Z`
  )
})

const xLabels = computed(() => {
  if (!props.data.length) return []
  if (props.data.length <= 7) {
    return props.data.map((d) => date.formatDate(d.period_start, 'ddd'))
  }
  // If many points, just show first, middle, last
  const labels = [
    date.formatDate(props.data[0].period_start, 'MMM DD'),
    date.formatDate(props.data[Math.floor(props.data.length / 2)].period_start, 'MMM DD'),
    date.formatDate(props.data[props.data.length - 1].period_start, 'MMM DD'),
  ]
  return labels
})
</script>

<style scoped></style>

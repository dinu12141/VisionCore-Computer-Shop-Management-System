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

    <div v-if="loading" class="flex flex-center" style="height: 450px">
      <q-spinner color="primary" size="3em" />
    </div>

    <div
      v-else-if="!data || data.length === 0"
      class="flex flex-center text-grey"
      style="height: 450px"
    >
      No data available for this range
    </div>

    <div v-else class="chart-container relative-position" style="height: 450px">
      <v-chart :option="chartOption" class="full-width full-height" autoresize />
    </div>
  </q-card>
</template>

<script setup>
import { computed } from 'vue'
import { useQuasar } from 'quasar'

const props = defineProps({
  data: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
})

const $q = useQuasar()

const chartOption = computed(() => {
  if (!props.data || props.data.length === 0) return {}

  const dates = props.data.map((d) => {
    // Format date nicely (e.g. Mar 04)
    if (!d.period_start) return ''
    const dateObj = new Date(d.period_start)
    return dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  })

  // Parse values to actual numbers to render properly
  const revenues = props.data.map((d) => Number(d.revenue || 0).toFixed(2))
  const profits = props.data.map((d) => Number(d.profit || 0).toFixed(2))

  const textColor = $q.dark.isActive ? '#ccc' : '#666'
  const splitLineColor = $q.dark.isActive ? '#444' : '#eee'

  return {
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      valueFormatter: (value) => `LKR ${Number(value).toLocaleString()}`,
    },
    legend: {
      data: ['Revenue', 'Profit'],
      bottom: 0,
      textStyle: { color: textColor },
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '15%',
      top: '5%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      data: dates,
      axisLine: { lineStyle: { color: splitLineColor } },
      axisLabel: { color: textColor },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      splitLine: {
        lineStyle: {
          color: splitLineColor,
          type: 'dashed',
        },
      },
      axisLabel: { color: textColor },
    },
    series: [
      {
        name: 'Revenue',
        type: 'bar',
        barGap: '15%',
        barWidth: '35%',
        itemStyle: {
          color: '#6c63ff', // Primary app color
          borderRadius: [4, 4, 0, 0],
        },
        data: revenues,
      },
      {
        name: 'Profit',
        type: 'bar',
        barWidth: '35%',
        itemStyle: {
          color: '#2e7d32', // Positive green
          borderRadius: [4, 4, 0, 0],
        },
        data: profits,
      },
    ],
  }
})
</script>

<style scoped>
.chart-container {
  width: 100%;
}
</style>

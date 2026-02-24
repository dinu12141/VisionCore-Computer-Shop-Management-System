<template>
  <q-card flat bordered class="glass-container fit overflow-hidden">
    <q-card-section class="row items-center q-pb-none">
      <div class="text-h6 text-weight-bold">Revenue & Profit Trends</div>
      <q-space />
      <q-btn-toggle
        v-model="internalGroupBy"
        flat
        dense
        rounded
        toggle-color="primary"
        :options="[
          { label: 'Day', value: 'day' },
          { label: 'Week', value: 'week' },
          { label: 'Month', value: 'month' },
        ]"
        @update:model-value="$emit('group-change', $event)"
      />
    </q-card-section>

    <q-card-section class="q-pa-md" style="height: 350px">
      <q-skeleton v-if="loading" class="fit" />
      <VChart
        v-else-if="data && data.length > 0"
        class="fit"
        :option="chartOption"
        :init-options="{ renderer: 'canvas' }"
        autoresize
      />
      <div v-else class="fit flex flex-center text-grey-6 italic">
        No trend data available for the selected period
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { useQuasar, date } from 'quasar'

const props = defineProps({
  data: { type: Array, default: () => [] },
  loading: Boolean,
  groupBy: { type: String, default: 'day' },
})

defineEmits(['group-change'])

const $q = useQuasar()
const internalGroupBy = ref(props.groupBy)

watch(
  () => props.groupBy,
  (val) => {
    internalGroupBy.value = val
  },
)

const chartOption = computed(() => {
  const isDark = $q.dark.isActive

  return {
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      backgroundColor: isDark ? '#1e1e28' : '#fff',
      borderColor: isDark ? '#333' : '#eee',
      textStyle: { color: isDark ? '#fff' : '#333' },
    },
    legend: {
      data: ['Revenue', 'Profit'],
      bottom: 0,
      textStyle: { color: isDark ? '#bbb' : '#666' },
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
      data: props.data.map((d) => formatDate(d.period_start)),
      axisLine: { lineStyle: { color: isDark ? '#444' : '#ddd' } },
      axisLabel: {
        color: isDark ? '#888' : '#777',
        fontSize: 10,
      },
    },
    yAxis: {
      type: 'value',
      splitLine: { lineStyle: { color: isDark ? '#222' : '#f0f0f0' } },
      axisLabel: {
        color: isDark ? '#888' : '#777',
        formatter: (val) => (val >= 1000 ? val / 1000 + 'k' : val),
      },
    },
    series: [
      {
        name: 'Revenue',
        type: 'line',
        smooth: true,
        showSymbol: true,
        symbolSize: 6,
        data: props.data.map((d) => d.revenue),
        itemStyle: { color: '#1976D2' },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(25, 118, 210, 0.2)' },
              { offset: 1, color: 'rgba(25, 118, 210, 0)' },
            ],
          },
        },
      },
      {
        name: 'Profit',
        type: 'line',
        smooth: true,
        showSymbol: true,
        symbolSize: 6,
        data: props.data.map((d) => d.profit),
        itemStyle: { color: '#4CAF50' },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(76, 175, 80, 0.2)' },
              { offset: 1, color: 'rgba(76, 175, 80, 0)' },
            ],
          },
        },
      },
    ],
  }
})

function formatDate(d) {
  if (!d) return ''
  const dateObj = new Date(d)
  if (props.groupBy === 'day') return date.formatDate(dateObj, 'DD')
  if (props.groupBy === 'week') return 'W' + date.formatDate(dateObj, 'w')
  return date.formatDate(dateObj, 'MMM')
}
</script>

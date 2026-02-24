<template>
  <q-card flat bordered class="glass-container fit overflow-hidden">
    <q-card-section>
      <div class="text-h6 text-weight-bold">Payment Methods</div>
    </q-card-section>

    <q-card-section class="q-pa-md" style="height: 300px">
      <q-skeleton v-if="loading" class="fit" type="circle" />
      <VChart
        v-else
        class="fit"
        :option="chartOption"
        :init-options="{ renderer: 'canvas' }"
        autoresize
      />
    </q-card-section>
  </q-card>
</template>

<script setup>
import { computed } from 'vue'
import { useQuasar } from 'quasar'

const props = defineProps({
  data: { type: Array, default: () => [] },
  loading: Boolean,
})

const $q = useQuasar()

const chartOption = computed(() => {
  const isDark = $q.dark.isActive

  return {
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'item',
      backgroundColor: isDark ? '#1e1e28' : '#fff',
      textStyle: { color: isDark ? '#fff' : '#333' },
    },
    legend: {
      orient: 'vertical',
      left: 'left',
      textStyle: { color: isDark ? '#bbb' : '#666' },
    },
    series: [
      {
        name: 'Payment Method',
        type: 'pie',
        radius: ['40%', '70%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 10,
          borderColor: isDark ? '#121212' : '#fff',
          borderWidth: 2,
        },
        label: {
          show: false,
          position: 'center',
        },
        emphasis: {
          label: {
            show: true,
            fontSize: '18',
            fontWeight: 'bold',
          },
        },
        labelLine: {
          show: false,
        },
        data: props.data.map((d) => ({
          name: d.method,
          value: d.value,
        })),
      },
    ],
  }
})
</script>

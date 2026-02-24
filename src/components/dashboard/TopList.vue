<template>
  <q-card flat bordered class="glass-container fit overflow-hidden">
    <q-card-section class="row items-center q-pb-sm">
      <div class="text-h6 text-weight-bold">{{ title }}</div>
      <q-space />
      <q-btn-dropdown flat dense rounded :label="currentMetricLabel" color="grey-7" size="sm">
        <q-list dense>
          <q-item
            v-for="m in metrics"
            :key="m.value"
            clickable
            v-close-popup
            @click="$emit('metric-change', m.value)"
          >
            <q-item-section>{{ m.label }}</q-item-section>
          </q-item>
        </q-list>
      </q-btn-dropdown>
    </q-card-section>

    <q-list padding class="q-pt-none">
      <q-item v-for="(item, index) in data" :key="index" class="q-py-md">
        <q-item-section avatar>
          <div
            class="rank-circle flex flex-center text-weight-bold"
            :class="index < 3 ? 'rank-' + (index + 1) : 'rank-other'"
          >
            {{ index + 1 }}
          </div>
        </q-item-section>

        <q-item-section>
          <q-item-label class="text-weight-bold ellipsis">{{ item.name }}</q-item-label>
          <q-item-label caption v-if="item.qty">{{ item.qty }} units sold</q-item-label>
        </q-item-section>

        <q-item-section side>
          <div class="text-weight-bolder text-primary">
            {{ formatValue(item.value) }}
          </div>
        </q-item-section>
      </q-item>

      <div v-if="loading" class="q-pa-md">
        <q-skeleton type="text" class="q-mb-sm" v-for="i in 5" :key="i" />
      </div>

      <div v-if="!loading && data.length === 0" class="q-pa-xl text-center text-grey-5">
        No data available
      </div>
    </q-list>
  </q-card>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  title: String,
  data: { type: Array, default: () => [] },
  metrics: { type: Array, default: () => [] },
  currentMetric: String,
  loading: Boolean,
  isCurrency: { type: Boolean, default: true },
})

defineEmits(['metric-change'])

const currentMetricLabel = computed(() => {
  const m = props.metrics.find((x) => x.value === props.currentMetric)
  return m ? m.label : 'Select Metric'
})

function formatValue(val) {
  if (typeof val !== 'number') return val
  if (props.isCurrency) {
    return 'LKR ' + val.toLocaleString(undefined, { maximumFractionDigits: 0 })
  }
  return val.toLocaleString()
}
</script>

<style scoped lang="scss">
.rank-circle {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  font-size: 14px;
}

.rank-1 {
  background: #ffd700;
  color: #000;
  box-shadow: 0 0 10px rgba(255, 215, 0, 0.4);
}
.rank-2 {
  background: #c0c0c0;
  color: #000;
}
.rank-3 {
  background: #cd7f32;
  color: #fff;
}
.rank-other {
  background: v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)'");
  color: #888;
}
</style>

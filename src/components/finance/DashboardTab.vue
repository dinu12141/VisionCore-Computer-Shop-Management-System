<template>
  <div class="row q-col-gutter-md">
    <div class="col-12">
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-btn-toggle
          v-model="rangeType"
          toggle-color="primary"
          flat
          dense
          unelevated
          :options="[
            { label: 'Today', value: 'today' },
            { label: 'Week', value: 'week' },
            { label: 'Month', value: 'month' },
            { label: 'Year', value: 'year' },
            { label: 'Custom', value: 'custom' },
          ]"
          @update:model-value="onRangeChange"
        />
        <q-input
          v-if="rangeType === 'custom'"
          v-model="customRange.from"
          dense
          outlined
          type="date"
          label="From"
          class="q-ml-sm"
        />
        <q-input
          v-if="rangeType === 'custom'"
          v-model="customRange.to"
          dense
          outlined
          type="date"
          label="To"
          class="q-ml-sm"
        />
        <q-btn
          v-if="rangeType === 'custom'"
          color="primary"
          icon="refresh"
          @click="refreshData"
          flat
          round
        />
      </div>
    </div>

    <!-- Revenue -->
    <div class="col-12 col-md-4">
      <StatCard
        title="Revenue"
        :value="financeStore.overview.totalRevenue"
        prefix="LKR"
        icon="attach_money"
        gradient="primary"
        :loading="financeStore.loading"
      />
    </div>

    <!-- COGS -->
    <div class="col-12 col-md-4">
      <StatCard
        title="COGS"
        :value="financeStore.overview.totalCogs"
        prefix="LKR"
        icon="inventory"
        gradient="warning"
        :loading="financeStore.loading"
      />
    </div>

    <!-- Profit -->
    <div class="col-12 col-md-4">
      <StatCard
        title="Gross Profit"
        :value="financeStore.overview.totalProfit"
        prefix="LKR"
        icon="trending_up"
        gradient="success"
        :trend="`Margin: ${financeStore.overview.marginPct}%`"
        trendColor="green"
        :loading="financeStore.loading"
      />
    </div>

    <!-- Payments Received -->
    <div class="col-12 col-md-6">
      <StatCard
        title="Payments Received"
        :value="financeStore.overview.totalReceived"
        prefix="LKR"
        icon="account_balance_wallet"
        gradient="info"
        :loading="financeStore.loading"
      />
    </div>

    <!-- Outstanding Balance -->
    <div class="col-12 col-md-6">
      <StatCard
        title="Outstanding Receivables (AR)"
        :value="financeStore.overview.outstandingBalance"
        prefix="LKR"
        icon="pending_actions"
        gradient="danger"
        :loading="financeStore.loading"
      />
    </div>

    <!-- Sales Chart -->
    <div class="col-12">
      <SalesChart :data="financeStore.periodSummary" :loading="financeStore.loading" />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import StatCard from 'components/common/StatCard.vue'
import SalesChart from 'components/finance/SalesChart.vue'
import { useFinanceStore } from 'src/stores/financeStore'
import { date } from 'quasar'

const financeStore = useFinanceStore()
const rangeType = ref('month')
const customRange = reactive({
  from: date.formatDate(date.subtractFromDate(new Date(), { days: 30 }), 'YYYY-MM-DD'),
  to: date.formatDate(new Date(), 'YYYY-MM-DD'),
})

// formatCurrency removed since LKR prefix is handled by StatCard

let cleanup = null

async function refreshData() {
  let from, to
  const now = new Date()

  if (rangeType.value === 'today') {
    from = to = date.formatDate(now, 'YYYY-MM-DD')
  } else if (rangeType.value === 'week') {
    from = date.formatDate(date.subtractFromDate(now, { days: 7 }), 'YYYY-MM-DD')
    to = date.formatDate(now, 'YYYY-MM-DD')
  } else if (rangeType.value === 'month') {
    from = date.formatDate(date.startOfDate(now, 'month'), 'YYYY-MM-DD')
    to = date.formatDate(now, 'YYYY-MM-DD')
  } else if (rangeType.value === 'year') {
    from = date.formatDate(date.startOfDate(now, 'year'), 'YYYY-MM-DD')
    to = date.formatDate(now, 'YYYY-MM-DD')
  } else {
    from = customRange.from
    to = customRange.to
  }

  const groupBy = rangeType.value === 'year' ? 'month' : 'day'
  await financeStore.fetchOverview(from, to)
  await financeStore.fetchPeriodSummary(from, to, groupBy)

  // Set up real-time subscription
  if (cleanup) cleanup()
  cleanup = financeStore.setupRealtime(from, to, groupBy)
}

function onRangeChange() {
  if (rangeType.value !== 'custom') {
    refreshData()
  }
}

onMounted(refreshData)

import { onUnmounted } from 'vue'
onUnmounted(() => {
  if (cleanup) cleanup()
})
</script>

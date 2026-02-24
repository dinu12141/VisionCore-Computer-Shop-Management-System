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
          ]"
          @update:model-value="refreshData"
        />
        <q-space />
        <ExportButton
          :data="reportStore.itemSales"
          :date-from="exportDateFrom"
          :date-to="exportDateTo"
          :filters="{ range: rangeType }"
          :excel-options="[{ key: 'profit_analysis', label: 'Profit &amp; Loss Report' }]"
          :pdf-options="[{ key: 'profit_analysis', label: 'Profit &amp; Loss Report' }]"
        />
      </div>
    </div>

    <!-- Summary Stats for the selected range -->
    <div class="col-12 col-md-4">
      <StatCard
        title="Total Profit"
        :value="formatCurrency(financeStore.overview.totalProfit)"
        icon="trending_up"
        color="green"
        :loading="financeStore.loading"
      />
    </div>
    <div class="col-12 col-md-4">
      <StatCard
        title="Avg. Margin"
        :value="financeStore.overview.marginPct + '%'"
        icon="percent"
        color="blue"
        :loading="financeStore.loading"
      />
    </div>
    <div class="col-12 col-md-4">
      <StatCard
        title="Items Analyzed"
        :value="reportStore.itemSales.length.toString()"
        icon="list"
        color="purple"
        :loading="reportStore.loading"
      />
    </div>

    <!-- Detailed Profit Table -->
    <div class="col-12">
      <q-card flat bordered class="border-radius-12 mt-md">
        <q-card-section class="row items-center justify-between">
          <div>
            <div class="text-h6 text-weight-bold">Item-wise Profit Analysis</div>
            <div class="text-caption text-grey-7">Profit breakdown by individual product items</div>
          </div>
          <q-input
            v-model="filter"
            placeholder="Search items..."
            outlined
            dense
            style="width: 250px"
          >
            <template v-slot:append>
              <q-icon name="search" />
            </template>
          </q-input>
        </q-card-section>

        <q-separator />

        <q-table
          :rows="reportStore.itemSales"
          :columns="columns"
          :filter="filter"
          :loading="reportStore.loading"
          flat
          row-key="item_name"
          :pagination="{ rowsPerPage: 15 }"
        >
          <template v-slot:body-cell-item_name="props">
            <q-td :props="props">
              <div class="text-weight-bold">{{ props.value }}</div>
              <div class="text-caption text-grey-6" v-if="props.row.item_code">
                Code: {{ props.row.item_code }}
              </div>
            </q-td>
          </template>

          <template v-slot:body-cell-profit="props">
            <q-td
              :props="props"
              class="text-weight-bold"
              :class="props.value >= 0 ? 'text-green' : 'text-red'"
            >
              LKR {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
            </q-td>
          </template>

          <template v-slot:body-cell-revenue="props">
            <q-td :props="props" align="right" class="text-weight-bold">
              LKR {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
            </q-td>
          </template>

          <template v-slot:body-cell-avg_cost="props">
            <q-td :props="props" align="right" class="text-weight-bold text-blue-7">
              LKR {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
            </q-td>
          </template>

          <template v-slot:body-cell-avg_price="props">
            <q-td :props="props" align="right" class="text-weight-bold text-teal-7">
              LKR {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
            </q-td>
          </template>

          <template v-slot:body-cell-margin="props">
            <q-td :props="props">
              <q-linear-progress
                :value="props.row.profit_pct / 100"
                :color="getMarginColor(props.row.profit_pct)"
                class="q-mb-xs"
                style="height: 6px; border-radius: 3px"
              />
              <div class="text-caption text-weight-bold">{{ props.row.profit_pct }}%</div>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import StatCard from 'components/common/StatCard.vue'
import ExportButton from 'components/common/ExportButton.vue'
import { useFinanceStore } from 'src/stores/financeStore'
import { useReportStore } from 'src/stores/reportStore'
import { date } from 'quasar'

const financeStore = useFinanceStore()
const reportStore = useReportStore()

const rangeType = ref('month')
const filter = ref('')
const exportDateFrom = ref('')
const exportDateTo = ref('')

const columns = [
  {
    name: 'item_name',
    label: 'ITEM DESCRIPTION',
    align: 'left',
    field: 'item_name',
    sortable: true,
  },
  { name: 'qty_sold', label: 'QTY SOLD', align: 'center', field: 'qty_sold', sortable: true },
  { name: 'avg_cost', label: 'COST PRICE', align: 'right', field: 'avg_unit_cost', sortable: true },
  {
    name: 'avg_price',
    label: 'SALE PRICE',
    align: 'right',
    field: 'avg_unit_price',
    sortable: true,
  },
  { name: 'revenue', label: 'TOTAL SALES', align: 'right', field: 'revenue', sortable: true },
  { name: 'profit', label: 'NET PROFIT', align: 'right', field: 'profit', sortable: true },
  { name: 'margin', label: 'PROFIT %', align: 'center', field: 'profit_pct', sortable: true },
]

function formatCurrency(val) {
  return (
    'LKR ' +
    (Number(val) || 0).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  )
}

function getMarginColor(margin) {
  if (margin >= 30) return 'green'
  if (margin >= 15) return 'blue'
  if (margin >= 5) return 'orange'
  return 'red'
}

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
  } else {
    from = date.formatDate(date.startOfDate(now, 'year'), 'YYYY-MM-DD')
    to = date.formatDate(now, 'YYYY-MM-DD')
  }

  // Track for export metadata
  exportDateFrom.value = from
  exportDateTo.value = to

  // Fetch data
  await Promise.all([
    financeStore.fetchOverview(from, to),
    reportStore.fetchItemSales(from, to, 100),
  ])

  // Setup Realtime
  if (cleanup) cleanup()
  cleanup = reportStore.setupRealtime('item', from, to)
}

onMounted(refreshData)
onUnmounted(() => {
  if (cleanup) cleanup()
})
</script>

<style scoped>
.border-radius-12 {
  border-radius: 12px;
}
</style>

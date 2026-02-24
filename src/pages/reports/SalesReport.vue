<template>
  <q-page class="q-pa-md">
    <PageHeader
      title="Sales Summary Report"
      subtitle="Analytical view of revenue and profitability"
    >
      <template #actions>
        <div class="row q-gutter-sm items-center">
          <q-select
            v-model="rangeLabel"
            :options="rangeOptions"
            label="Date Range"
            dense
            outlined
            style="width: 200px"
            @update:model-value="onRangeChange"
          />
          <q-btn
            flat
            dense
            color="primary"
            icon="list_alt"
            label="Detailed Report"
            to="/reports/invoices"
            class="q-px-sm"
          />
          <ExportButton
            :data="reportStore.itemSales"
            :date-from="currentFrom"
            :date-to="currentTo"
            :filters="{ range: rangeLabel }"
            :excel-options="[{ key: 'item_sales', label: 'Sales by Product' }]"
            :pdf-options="[{ key: 'item_sales', label: 'Sales by Product' }]"
          />
          <ExportButton
            :data="reportStore.customerSales"
            :date-from="currentFrom"
            :date-to="currentTo"
            :filters="{ range: rangeLabel }"
            :excel-options="[{ key: 'customer_sales', label: 'Sales by Customer' }]"
            :pdf-options="[{ key: 'customer_sales', label: 'Sales by Customer' }]"
          />
        </div>
      </template>
    </PageHeader>

    <div class="row q-col-gutter-md q-mt-md">
      <!-- Trend Chart -->
      <div class="col-12">
        <SalesChart :data="financeStore.periodSummary" :loading="financeStore.loading" />
      </div>

      <!-- Top Items -->
      <div class="col-12 col-md-6">
        <q-card flat bordered>
          <q-card-section class="row items-center justify-between">
            <div class="text-h6">Top Items by Profit</div>
            <q-btn flat round icon="more_horiz" />
          </q-card-section>
          <q-separator />
          <q-table
            flat
            :rows="reportStore.itemSales"
            :columns="itemColumns"
            :loading="reportStore.loading"
            hide-pagination
            :pagination="{ rowsPerPage: 10 }"
          >
            <template v-slot:body-cell-avg_cost="props">
              <q-td :props="props" class="text-blue-7 text-weight-bold">
                LKR
                {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
              </q-td>
            </template>
            <template v-slot:body-cell-avg_price="props">
              <q-td :props="props" class="text-teal-7 text-weight-bold">
                LKR
                {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
              </q-td>
            </template>
            <template v-slot:body-cell-profit="props">
              <q-td :props="props" class="text-weight-bold text-green">
                LKR
                {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
              </q-td>
            </template>
            <template v-slot:body-cell-margin="props">
              <q-td :props="props" align="right"> {{ props.value }}% </q-td>
            </template>
          </q-table>
        </q-card>
      </div>

      <!-- Top Customers -->
      <div class="col-12 col-md-6">
        <q-card flat bordered>
          <q-card-section class="row items-center justify-between">
            <div class="text-h6">Top Customers by Revenue</div>
            <q-btn flat round icon="more_horiz" />
          </q-card-section>
          <q-separator />
          <q-table
            flat
            :rows="reportStore.customerSales"
            :columns="customerColumns"
            :loading="reportStore.loading"
            hide-pagination
            :pagination="{ rowsPerPage: 10 }"
          />
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import PageHeader from 'components/common/PageHeader.vue'
import SalesChart from 'components/finance/SalesChart.vue'
import ExportButton from 'components/common/ExportButton.vue'
import { useFinanceStore } from 'src/stores/financeStore'
import { useReportStore } from 'src/stores/reportStore'
import { date } from 'quasar'

const financeStore = useFinanceStore()
const reportStore = useReportStore()

const rangeLabel = ref('This Month')
const rangeOptions = ['Today', 'This Week', 'This Month', 'This Year']
const currentFrom = ref('')
const currentTo = ref('')

const itemColumns = [
  { name: 'item_name', label: 'Item Description', field: 'item_name', align: 'left' },
  { name: 'avg_cost', label: 'Cost Price', field: 'avg_unit_cost', align: 'right' },
  { name: 'avg_price', label: 'Sale Price', field: 'avg_unit_price', align: 'right' },
  { name: 'qty_sold', label: 'Qty', field: 'qty_sold', align: 'right' },
  { name: 'profit', label: 'Profit', field: 'profit', align: 'right' },
  { name: 'margin', label: 'Margin %', field: 'profit_pct', align: 'right' },
]

const customerColumns = [
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'inv_count', label: 'Invoices', field: 'invoice_count', align: 'right' },
  {
    name: 'revenue',
    label: 'Total Sales',
    field: (row) => Number(row.revenue).toLocaleString(),
    align: 'right',
  },
  {
    name: 'balance',
    label: 'Balance',
    field: (row) => Number(row.balance_due).toLocaleString(),
    align: 'right',
  },
]

let cleanups = []

async function fetchData() {
  let from, to
  const now = new Date()

  if (rangeLabel.value === 'Today') {
    from = to = date.formatDate(now, 'YYYY-MM-DD')
  } else if (rangeLabel.value === 'This Week') {
    from = date.formatDate(date.subtractFromDate(now, { days: 7 }), 'YYYY-MM-DD')
    to = date.formatDate(now, 'YYYY-MM-DD')
  } else if (rangeLabel.value === 'This Month') {
    from = date.formatDate(date.startOfDate(now, 'month'), 'YYYY-MM-DD')
    to = date.formatDate(now, 'YYYY-MM-DD')
  } else {
    from = date.formatDate(date.startOfDate(now, 'year'), 'YYYY-MM-DD')
    to = date.formatDate(now, 'YYYY-MM-DD')
  }

  // Track current date range for export
  currentFrom.value = from
  currentTo.value = to

  await Promise.all([
    financeStore.fetchPeriodSummary(from, to, rangeLabel.value === 'This Year' ? 'month' : 'day'),
    reportStore.fetchItemSales(from, to),
    reportStore.fetchCustomerSales(from, to),
  ])

  // Realtime setup
  cleanups.forEach((c) => c())
  cleanups = [
    reportStore.setupRealtime('item', from, to),
    reportStore.setupRealtime('customer', from, to),
    financeStore.setupRealtime(from, to, rangeLabel.value === 'This Year' ? 'month' : 'day'),
  ]
}

function onRangeChange() {
  fetchData()
}

onMounted(fetchData)

onUnmounted(() => {
  cleanups.forEach((c) => c())
})
</script>

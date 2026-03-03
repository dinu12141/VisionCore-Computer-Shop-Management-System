<template>
  <q-page class="q-pa-lg">
    <!-- ── Header ─────────────────────────────────────────────────────── -->
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bolder q-ma-none text-gradient">Sales Reports</h1>
        <div class="text-subtitle2 text-grey-6 q-mt-xs">
          Revenue analytics across all sales channels
        </div>
      </div>
      <div class="col-auto row q-gutter-sm items-center">
        <!-- Date Range -->
        <q-btn-group flat>
          <q-btn
            v-for="r in ranges"
            :key="r.value"
            :label="r.label"
            :flat="selectedRange !== r.value"
            :unelevated="selectedRange === r.value"
            :color="selectedRange === r.value ? 'primary' : 'grey-7'"
            size="sm"
            no-caps
            @click="selectRange(r.value)"
          />
        </q-btn-group>

        <!-- Custom date range -->
        <q-btn flat icon="date_range" color="grey-7" dense>
          <q-menu>
            <div class="q-pa-md" style="min-width: 260px">
              <div class="text-subtitle2 q-mb-sm">Custom Range</div>
              <q-input
                v-model="customFrom"
                type="date"
                label="From"
                outlined
                dense
                class="q-mb-sm"
              />
              <q-input v-model="customTo" type="date" label="To" outlined dense class="q-mb-sm" />
              <q-btn
                color="primary"
                label="Apply"
                unelevated
                class="full-width"
                size="sm"
                @click="applyCustomRange"
                v-close-popup
              />
            </div>
          </q-menu>
        </q-btn>

        <!-- Export: Sales Overview -->
        <ExportButton
          :data="invoices"
          :date-from="currentFrom"
          :date-to="currentTo"
          :excel-options="[{ key: 'sales_overview', label: 'Sales Overview' }]"
          :pdf-options="[{ key: 'sales_overview', label: 'Sales Overview' }]"
        />
      </div>
    </div>

    <!-- ── KPI Summary Cards ───────────────────────────────────────────── -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-6 col-md-3" v-for="kpi in kpiCards" :key="kpi.label">
        <q-card flat bordered class="kpi-card q-pa-lg">
          <div class="row items-start no-wrap">
            <q-avatar
              :color="kpi.avatarBg"
              :text-color="kpi.color"
              :icon="kpi.icon"
              size="44px"
              class="q-mr-md"
            />
            <div class="col">
              <div class="kpi-label">{{ kpi.label }}</div>
              <div class="kpi-value" :class="`text-${kpi.color}`">{{ kpi.value }}</div>
              <div v-if="kpi.sub" class="kpi-sub">{{ kpi.sub }}</div>
            </div>
          </div>
        </q-card>
      </div>
    </div>

    <!-- ── Tabs: All Sales | Service Sales ────────────────────────────── -->
    <q-card flat bordered class="glass-card">
      <q-tabs
        v-model="activeTab"
        dense
        align="left"
        narrow-indicator
        :dark="$q.dark.isActive"
        class="q-px-md"
        active-color="primary"
        indicator-color="primary"
      >
        <q-tab name="overview" icon="bar_chart" label="Sales Overview" />
        <q-tab name="items" icon="inventory_2" label="By Product / Item" />
        <q-tab name="customers" icon="people_alt" label="By Customer" />
        <q-tab name="service" icon="build" label="Service Sales" />
      </q-tabs>
      <q-separator />

      <q-tab-panels v-model="activeTab" animated :dark="$q.dark.isActive" class="bg-transparent">
        <!-- ── OVERVIEW ───────────────────────────────────────────────── -->
        <q-tab-panel name="overview" class="q-pa-lg">
          <div class="row q-col-gutter-md">
            <!-- Revenue vs Invoices daily chart -->
            <div class="col-12">
              <div class="text-subtitle1 text-weight-bold q-mb-sm">Revenue Trend</div>
              <div v-if="loading" class="flex flex-center" style="height: 260px">
                <q-spinner-dots color="primary" size="42px" />
              </div>
              <div
                v-else-if="!dailyData.length"
                class="flex flex-center text-grey"
                style="height: 260px"
              >
                No data for this range
              </div>
              <div v-else style="height: 260px">
                <v-chart :option="revenueChartOption" autoresize class="full-width full-height" />
              </div>
            </div>

            <!-- Payment method split -->
            <div class="col-12 col-md-5">
              <div class="text-subtitle1 text-weight-bold q-mb-sm">Payment Methods</div>
              <div v-if="loading" class="flex flex-center" style="height: 220px">
                <q-spinner-dots color="primary" size="36px" />
              </div>
              <div
                v-else-if="!paymentMethods.length"
                class="flex flex-center text-grey"
                style="height: 220px"
              >
                No data
              </div>
              <div v-else style="height: 220px">
                <v-chart :option="paymentPieOption" autoresize class="full-width full-height" />
              </div>
            </div>

            <!-- Invoice status breakdown -->
            <div class="col-12 col-md-7">
              <div class="text-subtitle1 text-weight-bold q-mb-sm">Invoice Status Breakdown</div>
              <q-list dense separator>
                <q-item v-for="s in statusBreakdown" :key="s.label">
                  <q-item-section avatar>
                    <q-icon :name="s.icon" :color="s.color" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label>{{ s.label }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-badge :color="s.color" :label="s.count" />
                  </q-item-section>
                  <q-item-section side style="min-width: 110px">
                    <span class="text-weight-bold">LKR {{ s.total.toLocaleString() }}</span>
                  </q-item-section>
                </q-item>
              </q-list>
            </div>
          </div>
        </q-tab-panel>

        <!-- ── BY ITEM ─────────────────────────────────────────────────── -->
        <q-tab-panel name="items" class="q-pa-lg">
          <div class="row items-center q-mb-md">
            <div class="text-subtitle1 text-weight-bold">Top Products / Services Sold</div>
            <q-space />
            <ExportButton
              :data="filteredItems"
              :date-from="currentFrom"
              :date-to="currentTo"
              :excel-options="[{ key: 'sales_items', label: 'Sales by Product' }]"
              :pdf-options="[{ key: 'sales_items', label: 'Sales by Product' }]"
              class="q-mr-sm"
            />
            <q-input
              v-model="itemSearch"
              placeholder="Search item…"
              dense
              outlined
              clearable
              style="width: 200px"
            >
              <template #prepend><q-icon name="search" /></template>
            </q-input>
          </div>
          <div v-if="loading" class="flex flex-center q-pa-xl">
            <q-spinner-dots color="primary" size="40px" />
          </div>
          <q-table
            v-else
            flat
            :rows="filteredItems"
            :columns="itemColumns"
            row-key="item_name"
            :dark="$q.dark.isActive"
            :pagination="{ rowsPerPage: 15 }"
            class="bg-transparent"
          >
            <template #body-cell-revenue="props">
              <q-td :props="props" class="text-weight-bold text-primary">
                LKR {{ Number(props.value).toLocaleString() }}
              </q-td>
            </template>
            <template #body-cell-qty_sold="props">
              <q-td :props="props">
                <q-badge color="blue-2" text-color="blue-9" :label="props.value" />
              </q-td>
            </template>
            <template #no-data>
              <div class="full-width text-center q-pa-lg text-grey-5">
                <q-icon name="inventory_2" size="40px" /><br />No item sales data
              </div>
            </template>
          </q-table>
        </q-tab-panel>

        <!-- ── BY CUSTOMER ─────────────────────────────────────────────── -->
        <q-tab-panel name="customers" class="q-pa-lg">
          <div class="row items-center q-mb-md">
            <div class="text-subtitle1 text-weight-bold">Sales by Customer</div>
            <q-space />
            <ExportButton
              :data="filteredCustomers"
              :date-from="currentFrom"
              :date-to="currentTo"
              :excel-options="[{ key: 'sales_customers', label: 'Sales by Customer' }]"
              :pdf-options="[{ key: 'sales_customers', label: 'Sales by Customer' }]"
              class="q-mr-sm"
            />
            <q-input
              v-model="customerSearch"
              placeholder="Search customer…"
              dense
              outlined
              clearable
              style="width: 200px"
            >
              <template #prepend><q-icon name="search" /></template>
            </q-input>
          </div>
          <div v-if="loading" class="flex flex-center q-pa-xl">
            <q-spinner-dots color="primary" size="40px" />
          </div>
          <q-table
            v-else
            flat
            :rows="filteredCustomers"
            :columns="customerColumns"
            row-key="customer_name"
            :dark="$q.dark.isActive"
            :pagination="{ rowsPerPage: 15 }"
            class="bg-transparent"
          >
            <template #body-cell-revenue="props">
              <q-td :props="props" class="text-weight-bold text-primary">
                LKR {{ Number(props.value).toLocaleString() }}
              </q-td>
            </template>
            <template #body-cell-balance="props">
              <q-td :props="props">
                <span
                  :class="
                    Number(props.value) > 0 ? 'text-negative text-weight-bold' : 'text-positive'
                  "
                >
                  LKR {{ Number(props.value).toLocaleString() }}
                </span>
              </q-td>
            </template>
            <template #no-data>
              <div class="full-width text-center q-pa-lg text-grey-5">
                <q-icon name="people_alt" size="40px" /><br />No customer data
              </div>
            </template>
          </q-table>
        </q-tab-panel>

        <!-- ── SERVICE SALES ──────────────────────────────────────────── -->
        <q-tab-panel name="service" class="q-pa-lg">
          <div class="row items-center q-mb-md">
            <div>
              <div class="text-subtitle1 text-weight-bold">Service Revenue Report</div>
              <div class="text-caption text-grey-6">
                Revenue generated from device repair & service jobs
              </div>
            </div>
            <q-space />
            <ExportButton
              :data="serviceRows"
              :date-from="currentFrom"
              :date-to="currentTo"
              :excel-options="[{ key: 'service_sales', label: 'Service Revenue' }]"
              :pdf-options="[{ key: 'service_sales', label: 'Service Revenue' }]"
            />
          </div>

          <!-- Service KPIs -->
          <div class="row q-col-gutter-md q-mb-lg">
            <div class="col-6 col-md-3" v-for="kpi in serviceKpis" :key="kpi.label">
              <q-card flat bordered class="q-pa-md text-center">
                <div class="text-caption text-grey-6 q-mb-xs">{{ kpi.label }}</div>
                <div class="text-h6 text-weight-bold" :class="`text-${kpi.color}`">
                  {{ kpi.value }}
                </div>
              </q-card>
            </div>
          </div>

          <!-- Service jobs table -->
          <div v-if="serviceLoading" class="flex flex-center q-pa-xl">
            <q-spinner-dots color="primary" size="40px" />
          </div>
          <q-table
            v-else
            flat
            :rows="serviceRows"
            :columns="serviceColumns"
            row-key="id"
            :dark="$q.dark.isActive"
            :pagination="{ rowsPerPage: 15 }"
            class="bg-transparent"
            @row-click="(_, row) => $router.push(`/services/jobs/${row.id}`)"
            style="cursor: pointer"
          >
            <template #body-cell-payment_status="props">
              <q-td :props="props">
                <q-badge
                  :color="
                    props.value === 'paid'
                      ? 'positive'
                      : props.value === 'partial'
                        ? 'warning'
                        : 'negative'
                  "
                  :label="props.value || 'unpaid'"
                  class="text-capitalize"
                />
              </q-td>
            </template>
            <template #body-cell-total_final_cost="props">
              <q-td :props="props" class="text-weight-bold text-primary">
                LKR {{ Number(props.value || 0).toLocaleString() }}
              </q-td>
            </template>
            <template #body-cell-status="props">
              <q-td :props="props">
                <q-badge
                  color="blue-2"
                  text-color="blue-9"
                  :label="props.value"
                  class="text-capitalize"
                />
              </q-td>
            </template>
            <template #no-data>
              <div class="full-width text-center q-pa-lg text-grey-5">
                <q-icon name="build" size="40px" /><br />No service jobs for this range
              </div>
            </template>
          </q-table>
        </q-tab-panel>
      </q-tab-panels>
    </q-card>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useQuasar, date } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'
import ExportButton from 'src/components/common/ExportButton.vue'

const $q = useQuasar()
const auth = useAuthStore()
const loading = ref(false)
const serviceLoading = ref(false)
const activeTab = ref('overview')

// ── Date range ────────────────────────────────────────────────────────────
const ranges = [
  { label: 'Today', value: 'today' },
  { label: 'This Week', value: 'week' },
  { label: 'Month', value: 'month' },
  { label: 'Year', value: 'year' },
]
const selectedRange = ref('month')
const customFrom = ref('')
const customTo = ref('')
const currentFrom = ref('')
const currentTo = ref('')

function getDateRange() {
  const now = new Date()
  if (selectedRange.value === 'custom' && customFrom.value && customTo.value) {
    return { from: customFrom.value, to: customTo.value }
  }
  const fmt = (d) => date.formatDate(d, 'YYYY-MM-DD')
  if (selectedRange.value === 'today') return { from: fmt(now), to: fmt(now) }
  if (selectedRange.value === 'week')
    return { from: fmt(date.subtractFromDate(now, { days: 7 })), to: fmt(now) }
  if (selectedRange.value === 'year')
    return { from: fmt(date.startOfDate(now, 'year')), to: fmt(now) }
  // default: month
  return { from: fmt(date.startOfDate(now, 'month')), to: fmt(now) }
}

function selectRange(val) {
  selectedRange.value = val
  fetchAll()
}

function applyCustomRange() {
  selectedRange.value = 'custom'
  fetchAll()
}

// ── Raw data refs ─────────────────────────────────────────────────────────
const invoices = ref([])
const dailyData = ref([])
const itemSales = ref([])
const customerData = ref([])
const serviceRows = ref([])
const itemSearch = ref('')
const customerSearch = ref('')

// ── Utility ───────────────────────────────────────────────────────────────
const getCompanyId = () => auth.currentBranch?.company_id

// ── KPI Cards ─────────────────────────────────────────────────────────────
const kpiCards = computed(() => {
  const invs = invoices.value
  const totalRevenue = invs.reduce((s, i) => s + Number(i.total || 0), 0)
  const totalCollected = invs.reduce((s, i) => s + Number(i.paid_amount || 0), 0)
  const totalBalance = invs.reduce((s, i) => s + Number(i.balance || 0), 0)
  return [
    {
      label: 'Total Revenue',
      value: `LKR ${totalRevenue.toLocaleString()}`,
      icon: 'payments',
      avatarBg: 'purple-2',
      color: 'purple-9',
    },
    {
      label: 'Total Invoices',
      value: invs.length,
      icon: 'receipt_long',
      avatarBg: 'blue-2',
      color: 'blue-9',
    },
    {
      label: 'Collected',
      value: `LKR ${totalCollected.toLocaleString()}`,
      icon: 'check_circle',
      avatarBg: 'green-2',
      color: 'green-9',
    },
    {
      label: 'Outstanding',
      value: `LKR ${totalBalance.toLocaleString()}`,
      icon: 'pending_actions',
      avatarBg: 'orange-2',
      color: 'orange-9',
      sub: `${invs.filter((i) => i.balance > 0).length} invoices`,
    },
  ]
})

// ── Status Breakdown ──────────────────────────────────────────────────────
const statusBreakdown = computed(() => {
  const invs = invoices.value
  const group = (status) => invs.filter((i) => i.payment_status === status)
  const sum = (arr) => arr.reduce((s, i) => s + Number(i.total || 0), 0)
  return [
    {
      label: 'Paid',
      color: 'positive',
      icon: 'check_circle',
      count: group('paid').length,
      total: sum(group('paid')),
    },
    {
      label: 'Partial',
      color: 'warning',
      icon: 'schedule',
      count: group('partial').length,
      total: sum(group('partial')),
    },
    {
      label: 'Unpaid',
      color: 'negative',
      icon: 'cancel',
      count: group('unpaid').length,
      total: sum(group('unpaid')),
    },
    {
      label: 'Outstanding',
      color: 'orange',
      icon: 'pending_actions',
      count: group('outstanding').length,
      total: sum(group('outstanding')),
    },
  ].filter((s) => s.count > 0)
})

// ── Revenue Bar Chart ─────────────────────────────────────────────────────
const revenueChartOption = computed(() => {
  const labels = dailyData.value.map((d) => d.day)
  const revs = dailyData.value.map((d) => Number(d.revenue || 0))
  const textColor = $q.dark.isActive ? '#ccc' : '#666'
  const lineColor = $q.dark.isActive ? '#444' : '#eee'
  return {
    tooltip: { trigger: 'axis', valueFormatter: (v) => `LKR ${Number(v).toLocaleString()}` },
    grid: { left: '2%', right: '2%', top: '8%', bottom: '8%', containLabel: true },
    xAxis: {
      type: 'category',
      data: labels,
      axisLabel: { color: textColor, fontSize: 11 },
      axisLine: { lineStyle: { color: lineColor } },
    },
    yAxis: {
      type: 'value',
      axisLabel: { color: textColor, formatter: (v) => `LKR ${(v / 1000).toFixed(0)}k` },
      splitLine: { lineStyle: { color: lineColor, type: 'dashed' } },
    },
    series: [
      {
        name: 'Revenue',
        type: 'bar',
        data: revs,
        barMaxWidth: 40,
        itemStyle: { color: '#6c63ff', borderRadius: [4, 4, 0, 0] },
        emphasis: { itemStyle: { color: '#8b5cf6' } },
      },
    ],
  }
})

// ── Payment Method Pie ────────────────────────────────────────────────────
const paymentMethods = computed(() => {
  const map = {}
  invoices.value.forEach((i) => {
    const m = (i.payment_type || 'other').toUpperCase()
    map[m] = (map[m] || 0) + Number(i.total || 0)
  })
  return Object.entries(map).map(([name, value]) => ({ name, value }))
})

const paymentPieOption = computed(() => ({
  tooltip: { trigger: 'item', valueFormatter: (v) => `LKR ${Number(v).toLocaleString()}` },
  legend: { bottom: 0, textStyle: { color: $q.dark.isActive ? '#ccc' : '#666' } },
  series: [
    {
      name: 'Payment Method',
      type: 'pie',
      radius: ['40%', '68%'],
      center: ['50%', '42%'],
      data: paymentMethods.value,
      label: { formatter: '{b}: {d}%', fontSize: 11 },
      itemStyle: { borderRadius: 6 },
    },
  ],
}))

// ── Item table ────────────────────────────────────────────────────────────
const filteredItems = computed(() =>
  !itemSearch.value
    ? itemSales.value
    : itemSales.value.filter((r) =>
        r.item_name?.toLowerCase().includes(itemSearch.value.toLowerCase()),
      ),
)

const itemColumns = [
  {
    name: 'item_name',
    label: 'Item / Description',
    field: 'item_name',
    align: 'left',
    sortable: true,
  },
  { name: 'qty_sold', label: 'Qty', field: 'qty_sold', align: 'center', sortable: true },
  { name: 'revenue', label: 'Revenue', field: 'revenue', align: 'right', sortable: true },
]

// ── Customer table ────────────────────────────────────────────────────────
const filteredCustomers = computed(() =>
  !customerSearch.value
    ? customerData.value
    : customerData.value.filter((r) =>
        r.customer_name?.toLowerCase().includes(customerSearch.value.toLowerCase()),
      ),
)

const customerColumns = [
  {
    name: 'customer_name',
    label: 'Customer',
    field: 'customer_name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'invoice_count',
    label: 'Invoices',
    field: 'invoice_count',
    align: 'center',
    sortable: true,
  },
  { name: 'revenue', label: 'Total Revenue', field: 'revenue', align: 'right', sortable: true },
  { name: 'balance', label: 'Outstanding', field: 'balance', align: 'right', sortable: true },
]

// ── Service KPIs ─────────────────────────────────────────────────────────
const serviceKpis = computed(() => {
  const rows = serviceRows.value
  const total = rows.reduce((s, j) => s + Number(j.total_final_cost || 0), 0)
  const paid = rows
    .filter((j) => j.payment_status === 'paid')
    .reduce((s, j) => s + Number(j.total_final_cost || 0), 0)
  return [
    { label: 'Service Jobs', value: rows.length, color: 'blue-9' },
    { label: 'Total Revenue', value: `LKR ${total.toLocaleString()}`, color: 'purple-9' },
    { label: 'Paid', value: `LKR ${paid.toLocaleString()}`, color: 'green-9' },
    { label: 'Outstanding', value: `LKR ${(total - paid).toLocaleString()}`, color: 'orange-9' },
  ]
})

const serviceColumns = [
  { name: 'job_no', label: 'Job #', field: 'job_no', align: 'left' },
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'device_type', label: 'Device', field: 'device_type', align: 'left' },
  {
    name: 'brand',
    label: 'Brand/Model',
    field: (r) => `${r.brand || ''} ${r.model || ''}`.trim(),
    align: 'left',
  },
  { name: 'received_date', label: 'Received', field: 'received_date', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'center' },
  { name: 'total_final_cost', label: 'Final Cost', field: 'total_final_cost', align: 'right' },
]

// ── Fetch all data ────────────────────────────────────────────────────────
async function fetchAll() {
  const companyId = getCompanyId()
  if (!companyId) return
  const { from, to } = getDateRange()
  currentFrom.value = from
  currentTo.value = to

  loading.value = true
  serviceLoading.value = true

  try {
    // 1. All invoices in range
    const { data: invData } = await supabase
      .from('invoices')
      .select(
        'id, invoice_no, total, paid_amount, balance, payment_type, payment_status, customer_snapshot, created_at',
      )
      .eq('company_id', companyId)
      .gte('created_at', from + 'T00:00:00')
      .lte('created_at', to + 'T23:59:59')
      .order('created_at', { ascending: true })
    invoices.value = invData || []

    // 2. Daily revenue for chart
    const daily = {}
    ;(invData || []).forEach((inv) => {
      const day = inv.created_at?.slice(0, 10)
      if (!day) return
      daily[day] = (daily[day] || 0) + Number(inv.total || 0)
    })
    dailyData.value = Object.entries(daily)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([day, revenue]) => ({ day, revenue }))

    // 3. Item sales — from invoice_items
    const { data: itemData } = await supabase
      .from('invoice_items')
      .select('description, qty, line_total, invoice:invoices!inner(company_id, created_at)')
      .eq('invoice.company_id', companyId)
      .gte('invoice.created_at', from + 'T00:00:00')
      .lte('invoice.created_at', to + 'T23:59:59')
    const itemMap = {}
    ;(itemData || []).forEach((r) => {
      const key = r.description || 'Unknown'
      if (!itemMap[key]) itemMap[key] = { item_name: key, qty_sold: 0, revenue: 0 }
      itemMap[key].qty_sold += Number(r.qty || 0)
      itemMap[key].revenue += Number(r.line_total || 0)
    })
    itemSales.value = Object.values(itemMap).sort((a, b) => b.revenue - a.revenue)

    // 4. Customer sales — from invoices customer_snapshot
    const custMap = {}
    ;(invData || []).forEach((inv) => {
      const name = inv.customer_snapshot?.name || 'Walk-in'
      if (!custMap[name])
        custMap[name] = { customer_name: name, invoice_count: 0, revenue: 0, balance: 0 }
      custMap[name].invoice_count++
      custMap[name].revenue += Number(inv.total || 0)
      custMap[name].balance += Number(inv.balance || 0)
    })
    customerData.value = Object.values(custMap).sort((a, b) => b.revenue - a.revenue)
  } finally {
    loading.value = false
  }

  // 5. Service jobs in range (separate load)
  try {
    const { data: svcData } = await supabase
      .from('service_jobs')
      .select(
        'id, job_no, device_type, brand, model, status, payment_status, total_final_cost, total_estimated_cost, received_date, customer:customers(name)',
      )
      .eq('company_id', companyId)
      .gte('received_date', from)
      .lte('received_date', to)
      .order('received_date', { ascending: false })

    serviceRows.value = (svcData || []).map((j) => ({
      ...j,
      customer_name: j.customer?.name || 'Walk-in',
    }))
  } finally {
    serviceLoading.value = false
  }
}

onMounted(fetchAll)
watch(
  () => activeTab.value,
  () => {
    if (!serviceRows.value.length && activeTab.value === 'service') fetchAll()
  },
)
</script>

<style scoped lang="scss">
.text-gradient {
  background: linear-gradient(135deg, var(--q-primary), #a855f7);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.glass-card {
  background: v-bind("$q.dark.isActive ? 'rgba(30,30,40,0.45)' : 'rgba(255,255,255,0.7)'");
  backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'");
  border-radius: 20px;
}

.kpi-card {
  border-radius: 16px;
  transition: box-shadow 0.2s;
  &:hover {
    box-shadow: 0 4px 20px rgba(108, 99, 255, 0.12);
  }
}

.kpi-label {
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.8px;
  color: #9ca3af;
  font-weight: 600;
  margin-bottom: 2px;
}

.kpi-value {
  font-size: 1.4rem;
  font-weight: 800;
  line-height: 1.1;
}

.kpi-sub {
  font-size: 11px;
  color: #9ca3af;
  margin-top: 2px;
}
</style>

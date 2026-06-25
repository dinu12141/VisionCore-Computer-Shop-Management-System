<template>
  <q-page class="dashboard-page q-pa-lg">
    <div class="ambient-bg">
      <div class="blob blob-1"></div>
      <div class="blob blob-2"></div>
    </div>

    <!-- Header Section -->
    <div class="row items-center q-mb-xl relative-position">
      <div class="col-12 col-md-6">
        <h1 class="text-h4 text-weight-bolder q-ma-none text-gradient">Dashboard</h1>
        <div class="text-subtitle1 text-grey-6">
          System performance summary for {{ companyName }}
          <q-badge color="grey-8" class="q-ml-sm" outline>{{ lastRefreshTime }}</q-badge>
        </div>
      </div>

      <div
        class="col-12 col-md-6 text-right q-gutter-sm flex justify-end items-center dashboard-controls"
      >
        <q-btn-dropdown outline color="primary" icon="calendar_today" :label="dateRangeLabel">
          <q-list dense>
            <q-item clickable v-close-popup @click="setDateRange('today')">
              <q-item-section>Today</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="setDateRange('week')">
              <q-item-section>This Week</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="setDateRange('month')">
              <q-item-section>This Month</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="setDateRange('year')">
              <q-item-section>This Year</q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>

        <q-btn
          flat
          round
          dense
          icon="refresh"
          color="primary"
          @click="store.refresh()"
          :loading="store.loading"
        >
          <q-tooltip>Refresh Data</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- KPI Row (Row A) -->
    <div class="row q-col-gutter-lg q-mb-xl relative-position">
      <div v-for="stat in visibleKpiCards" :key="stat.title" class="col-12 col-sm-6 col-md-3">
        <KpiCard
          v-bind="stat"
          :loading="store.loading"
          @click="stat.to ? $router.push(stat.to) : null"
        />
      </div>
    </div>

    <!-- Trends Row (Row B) -->
    <div class="row q-col-gutter-lg q-mb-xl relative-position">
      <div class="col-12 col-lg-8">
        <TrendChart
          :data="store.trends"
          :loading="store.loading"
          :groupBy="store.groupBy"
          @group-change="store.setGroupBy"
        />
      </div>
      <div class="col-12 col-lg-4">
        <DonutChart :data="store.paymentMethods" :loading="store.loading" />
      </div>
    </div>

    <!-- Action Row (Row C) -->
    <div class="row q-col-gutter-lg q-mb-xl relative-position">
      <div class="col-12 col-lg-7">
        <CollectionsTable
          :data="store.collections"
          :loading="store.loading"
          @add-payment="openPaymentDialog"
        />
      </div>
      <div class="col-12 col-lg-5">
        <RecentActivity
          :invoices="recentInvoices"
          :payments="recentPayments"
          :customers="recentCustomers"
          :loading="store.loading"
        />
      </div>
    </div>

    <!-- Insights Row (Row D) -->
    <div class="row q-col-gutter-lg relative-position">
      <div class="col-12 col-md-4">
        <TopList
          title="Top Items"
          :data="store.topItems"
          :loading="store.loading"
          :metrics="itemMetrics"
          :currentMetric="itemMetric"
          @metric-change="
            (val) => {
              itemMetric = val
              store.fetchTopItems(val)
            }
          "
        />
      </div>
      <div class="col-12 col-md-4">
        <TopList
          title="Top Customers"
          :data="store.topCustomers"
          :loading="store.loading"
          :metrics="customerMetrics"
          :currentMetric="customerMetric"
          @metric-change="
            (val) => {
              customerMetric = val
              store.fetchTopCustomers(val)
            }
          "
        />
      </div>
      <div class="col-12 col-md-4">
        <div class="row q-col-gutter-md">
          <div class="col-12">
            <q-card flat bordered class="glass-container q-pa-md flex items-center">
              <q-avatar
                color="info-soft"
                text-color="info"
                icon="lightbulb"
                size="40px"
                class="q-mr-md"
              />
              <div>
                <div class="text-caption text-grey-7 font-bold uppercase">Today's Best Seller</div>
                <div class="text-subtitle1 text-weight-bold">{{ bestSellerToday }}</div>
              </div>
            </q-card>
          </div>
          <div class="col-12">
            <q-card flat bordered class="glass-container q-pa-md flex items-center">
              <q-avatar
                color="warning-soft"
                text-color="warning"
                icon="account_balance_wallet"
                size="40px"
                class="q-mr-md"
              />
              <div>
                <div class="text-caption text-grey-7 font-bold uppercase">Highest Owed</div>
                <div class="text-subtitle1 text-weight-bold">{{ highestOwedCustomer }}</div>
              </div>
            </q-card>
          </div>
          <div class="col-12">
            <q-card flat bordered class="glass-container q-pa-md flex items-center">
              <q-avatar
                color="negative-soft"
                text-color="negative"
                icon="priority_high"
                size="40px"
                class="q-mr-md"
              />
              <div>
                <div class="text-caption text-grey-7 font-bold uppercase">Low Stock Alert</div>
                <div class="text-subtitle1 text-weight-bold">
                  {{ store.kpis?.low_stock_count || 0 }} Items
                </div>
              </div>
            </q-card>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useQuasar, date } from 'quasar'
import { useDashboardStore } from 'src/stores/dashboard'
import { useAuthStore } from 'src/stores/auth'

// Components
import KpiCard from 'components/dashboard/KpiCard.vue'
import TrendChart from 'components/dashboard/TrendChart.vue'
import DonutChart from 'components/dashboard/DonutChart.vue'
import CollectionsTable from 'components/dashboard/CollectionsTable.vue'
import RecentActivity from 'components/dashboard/RecentActivity.vue'
import TopList from 'components/dashboard/TopList.vue'

const $q = useQuasar()
const store = useDashboardStore()
const authStore = useAuthStore()

// Local State
const itemMetric = ref('profit')
const customerMetric = ref('revenue')
const rangeType = ref('month')

const recentInvoices = ref([])
const recentPayments = ref([])
const recentCustomers = ref([])

// Computed
const companyName = computed(() => authStore.currentBranch?.companies?.name || 'Company')
const lastRefreshTime = computed(() =>
  store.lastUpdated ? date.formatDate(store.lastUpdated, 'HH:mm:ss') : '-',
)

const dateRangeLabel = computed(() => {
  if (rangeType.value === 'today') return 'Today'
  if (rangeType.value === 'week') return 'This Week'
  if (rangeType.value === 'month') return 'This Month'
  if (rangeType.value === 'year') return 'This Year'
  return 'Select Date'
})

// Metrics configuration
const itemMetrics = [
  { label: 'Profit', value: 'profit' },
  { label: 'Revenue', value: 'revenue' },
  { label: 'Qty Sold', value: 'qty' },
]

const customerMetrics = [
  { label: 'Revenue', value: 'revenue' },
  { label: 'Outstanding', value: 'outstanding' },
]

// KPI Logic with RBAC
const userRole = computed(() => {
  // Assuming authStore has a role field. If multiple roles, pick primary.
  const roles = authStore.roles || []
  if (roles.includes('admin') || roles.includes('finance')) return 'admin'
  if (roles.includes('inventory')) return 'inventory'
  return 'cashier'
})

const kpiCards = computed(() => {
  const k = store.kpis || {}
  const role = userRole.value

  return [
    {
      title: 'Total Sales',
      value: k.revenue || 0,
      delta: k.deltas?.revenue,
      icon: 'payments',
      color: 'primary',
      prefix: 'LKR',
      visible: true,
      to: '/billing/history',
    },
    {
      title: 'Gross Profit',
      value: k.profit || 0,
      delta: k.deltas?.profit,
      icon: 'trending_up',
      color: 'positive',
      prefix: 'LKR',
      visible: role === 'admin',
    },
    {
      title: 'Profit Margin',
      value: k.margin_pct || 0,
      suffix: '%',
      icon: 'pie_chart',
      color: 'secondary',
      visible: role === 'admin',
    },
    {
      title: 'Cashflow (Paid)',
      value: k.payments_received || 0,
      icon: 'account_balance_wallet',
      color: 'info',
      prefix: 'LKR',
      visible: true,
    },
    {
      title: 'Outstanding',
      value: k.outstanding_balance || 0,
      icon: 'money_off',
      color: 'warning',
      prefix: 'LKR',
      visible: role === 'admin',
      to: '/collections/outstanding',
    },
    {
      title: 'Invoices Count',
      value: k.invoices_count || 0,
      icon: 'description',
      color: 'grey-7',
      visible: true,
    },
    {
      title: 'Low Stock',
      value: k.low_stock_count || 0,
      icon: 'warning',
      color: 'negative',
      visible: role === 'admin' || role === 'inventory',
      to: '/inventory',
    },
    {
      title: 'Overdue Collections',
      value: k.overdue_collections_count || 0,
      icon: 'alarm',
      color: 'negative',
      visible: true,
      to: '/collections/outstanding',
    },
  ]
})

const bestSellerToday = computed(() => store.topItems?.[0]?.name || '-')
const highestOwedCustomer = computed(() => store.topCustomers?.[0]?.name || '-')

// Only show cards that are visible to the current role
const visibleKpiCards = computed(() => kpiCards.value.filter((c) => c.visible))

// Actions
function setDateRange(type) {
  rangeType.value = type
  let from,
    to = date.formatDate(new Date(), 'YYYY-MM-DD')

  const today = new Date()
  if (type === 'today') {
    from = date.formatDate(today, 'YYYY-MM-DD')
  } else if (type === 'week') {
    from = date.formatDate(date.startOfDate(today, 'week'), 'YYYY-MM-DD')
  } else if (type === 'month') {
    from = date.formatDate(date.startOfDate(today, 'month'), 'YYYY-MM-DD')
  } else if (type === 'year') {
    from = date.formatDate(date.startOfDate(today, 'year'), 'YYYY-MM-DD')
  }

  store.setDateRange({ from, to })
}

async function fetchRecentActivity() {
  const result = await store.fetchRecentActivity()
  recentInvoices.value = result.invoices
  recentPayments.value = result.payments
  recentCustomers.value = result.customers
}

function openPaymentDialog(invoice) {
  // Logic to open payment dialog that should exist in the app
  console.log('Open payment for', invoice)
  $q.notify({ message: 'Navigation to payment screen for ' + invoice.invoice_no, color: 'info' })
}

onMounted(async () => {
  try {
    await store.refresh()
    await store.fetchPaymentMethods()
    await fetchRecentActivity()
  } catch (err) {
    console.error('Initial dashboard load failed:', err)
    $q.notify({
      type: 'negative',
      message: 'Failed to load some dashboard data. Please try refreshing.',
      caption: err.message || String(err),
    })
  }
})
</script>

<style scoped lang="scss">
.dashboard-page {
  min-height: 100vh;
  position: relative;
  overflow-x: hidden;
}

.ambient-bg {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 0;
  overflow: hidden;
  pointer-events: none;

  .blob {
    position: absolute;
    width: 600px;
    height: 600px;
    border-radius: 50%;
    filter: blur(100px);
    opacity: v-bind('$q.dark.isActive ? 0.08 : 0.04');

    &.blob-1 {
      top: -100px;
      right: -100px;
      background: var(--q-primary);
      animation: float 20s infinite alternate;
    }

    &.blob-2 {
      bottom: -100px;
      left: -100px;
      background: var(--q-secondary);
      animation: float 25s infinite alternate-reverse;
    }
  }
}

@keyframes float {
  from {
    transform: translate(0, 0) scale(1);
  }
  to {
    transform: translate(60px, 80px) scale(1.1);
  }
}

.text-gradient {
  background: linear-gradient(135deg, var(--q-primary), #64b5f6);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.glass-container {
  background: v-bind("$q.dark.isActive ? 'rgba(30, 30, 40, 0.45)' : 'rgba(255, 255, 255, 0.6)'");
  backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid v-bind("$q.dark.isActive ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.06)'");
  border-radius: 20px;
  box-shadow: 0 4px 20px 0 rgba(0, 0, 0, 0.02);
}

.dashboard-controls {
  @media (max-width: 600px) {
    justify-content: flex-start !important;
    margin-top: 16px;
  }
}

.info-soft {
  background: rgba(0, 188, 212, 0.1);
}
.warning-soft {
  background: rgba(255, 152, 0, 0.1);
}
.negative-soft {
  background: rgba(244, 67, 54, 0.1);
}

.uppercase {
  text-transform: uppercase;
  letter-spacing: 1px;
  font-size: 10px;
}
</style>

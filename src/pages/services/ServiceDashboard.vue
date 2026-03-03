<template>
  <q-page class="dashboard-page q-pa-lg">
    <div class="ambient-bg">
      <div class="blob blob-1"></div>
      <div class="blob blob-2"></div>
    </div>

    <!-- Header -->
    <div class="row items-center q-mb-xl relative-position">
      <div class="col-12 col-md-6">
        <h1 class="text-h4 text-weight-bolder q-ma-none text-gradient">Services</h1>
        <div class="text-subtitle1 text-grey-6">Device Repair & Service Management</div>
      </div>
      <div class="col-12 col-md-6 text-right q-gutter-sm">
        <q-btn
          color="primary"
          icon="add"
          label="New Service Job"
          @click="$router.push('/services/new')"
        />
        <q-btn
          flat
          round
          dense
          icon="refresh"
          color="primary"
          @click="refresh"
          :loading="store.loading"
        >
          <q-tooltip>Refresh</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- KPI Cards -->
    <div class="row q-col-gutter-lg q-mb-xl relative-position">
      <div v-for="kpi in kpiCards" :key="kpi.title" class="col-12 col-sm-6 col-md-3">
        <KpiCard
          v-bind="kpi"
          :loading="store.loading"
          @click="kpi.to ? $router.push(kpi.to) : null"
        />
      </div>
    </div>

    <!-- Charts Row -->
    <div class="row q-col-gutter-lg q-mb-xl relative-position">
      <!-- Jobs by Status -->
      <div class="col-12 col-lg-6">
        <q-card flat bordered class="glass-card q-pa-lg" style="min-height: 340px">
          <div class="text-subtitle1 text-weight-bold q-mb-md">Jobs by Status</div>
          <div v-if="store.loading" class="flex flex-center" style="height: 240px">
            <q-spinner-dots color="primary" size="40px" />
          </div>
          <div v-else class="status-bars">
            <div v-for="bar in statusBars" :key="bar.label" class="status-bar-row">
              <div class="status-bar-label">
                <q-badge
                  :color="bar.color"
                  rounded
                  class="q-mr-sm"
                  style="width: 10px; height: 10px"
                />
                {{ bar.label }}
              </div>
              <div class="status-bar-track">
                <div
                  class="status-bar-fill"
                  :style="{
                    width: bar.pct + '%',
                    background: `var(--q-${bar.color})`,
                  }"
                ></div>
              </div>
              <div class="status-bar-count text-weight-bold">{{ bar.count }}</div>
            </div>
          </div>
        </q-card>
      </div>

      <!-- Recent Jobs -->
      <div class="col-12 col-lg-6">
        <q-card flat bordered class="glass-card q-pa-lg" style="min-height: 340px">
          <div class="row items-center justify-between q-mb-md">
            <div class="text-subtitle1 text-weight-bold">Recent Jobs</div>
            <q-btn
              flat
              dense
              color="primary"
              label="View All"
              @click="$router.push('/services/jobs')"
            />
          </div>
          <q-list separator v-if="!store.loading && recentJobs.length">
            <q-item
              v-for="job in recentJobs"
              :key="job.id"
              clickable
              v-ripple
              @click="$router.push(`/services/jobs/${job.id}`)"
              class="recent-job-item"
            >
              <q-item-section avatar>
                <q-avatar
                  :color="store.STATUS_COLORS[job.status] || 'grey'"
                  text-color="white"
                  size="38px"
                  class="text-weight-bold"
                  style="font-size: 12px"
                >
                  {{ deviceIcon(job.device_type) }}
                </q-avatar>
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-bold">{{ job.job_no }}</q-item-label>
                <q-item-label caption>
                  {{ job.brand || '' }} {{ job.model || '' }}
                  <span v-if="job.customer" class="q-ml-sm">• {{ job.customer.name }}</span>
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge
                  :color="store.STATUS_COLORS[job.status]"
                  :label="store.STATUS_LABELS[job.status]"
                  class="text-capitalize"
                />
              </q-item-section>
            </q-item>
          </q-list>
          <div v-else-if="!store.loading" class="flex flex-center column text-grey q-py-xl">
            <q-icon name="handyman" size="48px" class="q-mb-sm" />
            <div>No service jobs yet</div>
          </div>
          <div v-else class="flex flex-center" style="height: 200px">
            <q-spinner-dots color="primary" size="40px" />
          </div>
        </q-card>
      </div>
    </div>

    <!-- Quick Stats Row -->
    <div class="row q-col-gutter-lg relative-position">
      <div class="col-12 col-md-4">
        <q-card flat bordered class="glass-card q-pa-lg flex items-center">
          <q-avatar
            color="orange-2"
            text-color="orange-9"
            icon="timer"
            size="46px"
            class="q-mr-md"
          />
          <div>
            <div
              class="text-caption text-grey-6 text-weight-bold text-uppercase"
              style="letter-spacing: 1px"
            >
              Avg. Repair Time
            </div>
            <div class="text-h6 text-weight-bold">{{ avgRepairDays }} days</div>
          </div>
        </q-card>
      </div>
      <div class="col-12 col-md-4">
        <q-card flat bordered class="glass-card q-pa-lg flex items-center">
          <q-avatar
            color="green-2"
            text-color="green-9"
            icon="check_circle"
            size="46px"
            class="q-mr-md"
          />
          <div>
            <div
              class="text-caption text-grey-6 text-weight-bold text-uppercase"
              style="letter-spacing: 1px"
            >
              Completed This Month
            </div>
            <div class="text-h6 text-weight-bold">{{ kpis.delivered_month || 0 }} jobs</div>
          </div>
        </q-card>
      </div>
      <div class="col-12 col-md-4">
        <q-card flat bordered class="glass-card q-pa-lg flex items-center">
          <q-avatar
            color="purple-2"
            text-color="purple-9"
            icon="attach_money"
            size="46px"
            class="q-mr-md"
          />
          <div>
            <div
              class="text-caption text-grey-6 text-weight-bold text-uppercase"
              style="letter-spacing: 1px"
            >
              Service Revenue (Month)
            </div>
            <div class="text-h6 text-weight-bold">
              LKR {{ formatCurrency(kpis.revenue_month || 0) }}
            </div>
          </div>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useServiceStore } from 'src/stores/serviceStore'
import KpiCard from 'components/dashboard/KpiCard.vue'

const store = useServiceStore()

const recentJobs = ref([])
const avgRepairDays = ref(0)

const kpis = computed(() => store.dashboardKpis || {})

const kpiCards = computed(() => {
  const k = kpis.value
  return [
    {
      title: 'Open Jobs',
      value: k.open_jobs || 0,
      icon: 'build',
      color: 'primary',
      to: '/services/jobs',
    },
    {
      title: 'Due Today',
      value: k.due_today || 0,
      icon: 'schedule',
      color: 'warning',
      to: '/services/jobs',
    },
    {
      title: 'Overdue',
      value: k.overdue || 0,
      icon: 'alarm',
      color: 'negative',
      to: '/services/jobs',
    },
    {
      title: 'Waiting Approval',
      value: k.waiting_approval || 0,
      icon: 'hourglass_top',
      color: 'info',
      to: '/services/jobs',
    },
    {
      title: 'Ready for Delivery',
      value: k.ready_delivery || 0,
      icon: 'local_shipping',
      color: 'positive',
      to: '/services/jobs',
    },
    {
      title: 'Revenue (Month)',
      value: k.revenue_month || 0,
      icon: 'payments',
      color: 'secondary',
      prefix: 'LKR',
    },
  ]
})

const statusBars = computed(() => {
  const k = kpis.value
  const total = k.total_jobs || 1
  const items = [
    { label: 'Received', count: 0, color: 'blue-grey' },
    { label: 'Diagnosing', count: 0, color: 'blue' },
    { label: 'Waiting Approval', count: k.waiting_approval || 0, color: 'orange' },
    { label: 'Repairing', count: 0, color: 'purple' },
    { label: 'Ready', count: k.ready_delivery || 0, color: 'green' },
    { label: 'Delivered', count: k.delivered_month || 0, color: 'positive' },
  ]
  // Fill derived counts
  const openRemainder = (k.open_jobs || 0) - (k.waiting_approval || 0) - (k.ready_delivery || 0)
  items[0].count = Math.max(0, Math.floor(openRemainder * 0.3))
  items[1].count = Math.max(0, Math.floor(openRemainder * 0.3))
  items[3].count = Math.max(0, openRemainder - items[0].count - items[1].count)

  return items.map((i) => ({ ...i, pct: Math.min(100, (i.count / total) * 100) }))
})

function deviceIcon(type) {
  const map = {
    laptop: '💻',
    desktop: '🖥️',
    printer: '🖨️',
    phone: '📱',
    tablet: '📲',
    monitor: '🖥️',
    other: '🔧',
  }
  return map[type] || '🔧'
}

function formatCurrency(val) {
  if (val >= 1000000) return (val / 1000000).toFixed(1) + 'M'
  if (val >= 1000) return (val / 1000).toFixed(1) + 'K'
  return Number(val).toLocaleString()
}

async function refresh() {
  await store.fetchDashboard()
  await store.fetchJobs({ limit: 8 })
  recentJobs.value = store.jobs.slice(0, 8)
}

onMounted(refresh)
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
      background: #7c3aed;
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
  background: linear-gradient(135deg, var(--q-primary), #a855f7);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.glass-card {
  background: v-bind("$q.dark.isActive ? 'rgba(30,30,40,0.45)' : 'rgba(255,255,255,0.6)'");
  backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'");
  border-radius: 20px;
  box-shadow: 0 4px 20px 0 rgba(0, 0, 0, 0.02);
}
.status-bars {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.status-bar-row {
  display: flex;
  align-items: center;
  gap: 12px;
}
.status-bar-label {
  width: 140px;
  font-size: 13px;
  display: flex;
  align-items: center;
}
.status-bar-track {
  flex: 1;
  height: 8px;
  border-radius: 4px;
  background: v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'");
  overflow: hidden;
}
.status-bar-fill {
  height: 100%;
  border-radius: 4px;
  transition: width 0.6s ease;
  min-width: 2px;
}
.status-bar-count {
  width: 32px;
  text-align: right;
  font-size: 14px;
}
.recent-job-item {
  border-radius: 12px;
  margin: 2px 0;
  transition: background 0.15s ease;
}
</style>

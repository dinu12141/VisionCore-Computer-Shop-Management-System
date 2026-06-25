<template>
  <q-page class="q-pa-lg">
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bolder q-ma-none text-gradient">Service Reports</h1>
        <div class="text-subtitle2 text-grey-6">
          Analytics & insights for device service operations
        </div>
      </div>
      <div class="col-auto q-gutter-sm">
        <q-btn-dropdown outline color="primary" icon="calendar_today" :label="periodLabel">
          <q-list dense>
            <q-item clickable v-close-popup @click="period = 'week'"
              ><q-item-section>This Week</q-item-section></q-item
            >
            <q-item clickable v-close-popup @click="period = 'month'"
              ><q-item-section>This Month</q-item-section></q-item
            >
            <q-item clickable v-close-popup @click="period = 'quarter'"
              ><q-item-section>This Quarter</q-item-section></q-item
            >
            <q-item clickable v-close-popup @click="period = 'year'"
              ><q-item-section>This Year</q-item-section></q-item
            >
          </q-list>
        </q-btn-dropdown>
      </div>
    </div>

    <!-- Summary Cards -->
    <div class="row q-col-gutter-lg q-mb-xl">
      <div v-for="card in summaryCards" :key="card.title" class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered class="glass-card q-pa-md" style="height: 100%; display: flex; align-items: center;">
          <div class="row items-center no-wrap full-width">
            <q-avatar
              :color="card.avatarColor"
              :text-color="card.iconColor"
              :icon="card.icon"
              size="40px"
              class="q-mr-sm"
            />
            <div class="col" style="min-width: 0;">
              <div
                class="text-grey-6 text-weight-bold text-uppercase"
                style="letter-spacing: 0.5px; font-size: 10px; min-height: 26px; display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; margin-bottom: 2px;"
              >
                {{ card.title }}
              </div>
              <div 
                class="text-weight-bolder" 
                style="font-size: clamp(0.95rem, 1.5vw, 1.25rem); line-height: 1.2; word-break: break-word; letter-spacing: -0.01em;"
              >
                {{ card.value }}
              </div>
            </div>
          </div>
        </q-card>
      </div>
    </div>

    <!-- Charts Row -->
    <div class="row q-col-gutter-lg q-mb-xl">
      <!-- Common Issues -->
      <div class="col-12 col-lg-6">
        <q-card flat bordered class="glass-card q-pa-lg" style="min-height: 320px">
          <div class="text-subtitle1 text-weight-bold q-mb-md">Most Common Issues</div>
          <div v-if="loading" class="flex flex-center" style="height: 200px">
            <q-spinner-dots color="primary" size="36px" />
          </div>
          <q-list v-else separator>
            <q-item v-for="(issue, idx) in commonIssues" :key="idx" class="q-py-sm">
              <q-item-section avatar>
                <q-avatar
                  :color="issueColors[idx % issueColors.length]"
                  text-color="white"
                  size="32px"
                  class="text-weight-bold"
                  style="font-size: 13px"
                >
                  {{ idx + 1 }}
                </q-avatar>
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ issue.title }}</q-item-label>
                <q-item-label caption>{{ issue.category }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge color="primary" :label="`${issue.count} jobs`" />
              </q-item-section>
            </q-item>
            <q-item v-if="!commonIssues.length">
              <q-item-section class="text-center text-grey">No data</q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <!-- Device Type Distribution -->
      <div class="col-12 col-lg-6">
        <q-card flat bordered class="glass-card q-pa-lg" style="min-height: 320px">
          <div class="text-subtitle1 text-weight-bold q-mb-md">Jobs by Device Type</div>
          <div v-if="loading" class="flex flex-center" style="height: 200px">
            <q-spinner-dots color="primary" size="36px" />
          </div>
          <div v-else class="device-bars">
            <div v-for="bar in deviceBars" :key="bar.type" class="device-bar-row">
              <div class="device-bar-label text-capitalize">{{ bar.type }}</div>
              <div class="device-bar-track">
                <div
                  class="device-bar-fill"
                  :style="{ width: bar.pct + '%', background: bar.color }"
                ></div>
              </div>
              <div class="device-bar-count text-weight-bold">{{ bar.count }}</div>
            </div>
          </div>
        </q-card>
      </div>
    </div>

    <!-- Overdue Aging -->
    <div class="row q-col-gutter-lg">
      <div class="col-12">
        <q-card flat bordered class="glass-card q-pa-lg">
          <div class="text-subtitle1 text-weight-bold q-mb-md">Overdue Jobs</div>
          <q-table
            :rows="overdueJobs"
            :columns="overdueColumns"
            row-key="id"
            flat
            class="bg-transparent"
            :dark="$q.dark.isActive"
            :loading="loading"
            :pagination="{ rowsPerPage: 10 }"
            @row-click="(_, row) => $router.push(`/services/jobs/${row.id}`)"
            style="cursor: pointer"
          >
            <template v-slot:body-cell-days_overdue="props">
              <q-td :props="props">
                <q-badge
                  :color="
                    props.row.days_overdue > 7
                      ? 'red'
                      : props.row.days_overdue > 3
                        ? 'orange'
                        : 'amber'
                  "
                  :label="`${props.row.days_overdue} days`"
                />
              </q-td>
            </template>
            <template v-slot:no-data>
              <div class="full-width text-center q-pa-lg text-grey-5">
                <q-icon name="check_circle" size="40px" color="positive" /><br />
                No overdue jobs! 🎉
              </div>
            </template>
          </q-table>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'
import { useServiceStore } from 'src/stores/serviceStore'

const $q = useQuasar()
const authStore = useAuthStore()
const serviceStore = useServiceStore()
const loading = ref(true)
const period = ref('month')

const totalCompleted = ref(0)
const totalRevenue = ref(0)
const avgRepairDays = ref(0)
const totalJobs = ref(0)
const commonIssues = ref([])
const deviceDistribution = ref([])
const overdueJobs = ref([])

const issueColors = ['blue', 'purple', 'orange', 'teal', 'red', 'green', 'amber']

const periodLabel = computed(() => {
  const map = { week: 'This Week', month: 'This Month', quarter: 'This Quarter', year: 'This Year' }
  return map[period.value] || 'Period'
})

const summaryCards = computed(() => [
  {
    title: 'Total Jobs',
    value: totalJobs.value,
    icon: 'build',
    avatarColor: 'blue-2',
    iconColor: 'blue-9',
  },
  {
    title: 'Completed',
    value: totalCompleted.value,
    icon: 'check_circle',
    avatarColor: 'green-2',
    iconColor: 'green-9',
  },
  {
    title: 'Revenue',
    value: `LKR ${Number(totalRevenue.value).toLocaleString()}`,
    icon: 'payments',
    avatarColor: 'purple-2',
    iconColor: 'purple-9',
  },
  {
    title: 'Avg Repair Time',
    value: `${avgRepairDays.value} days`,
    icon: 'timer',
    avatarColor: 'orange-2',
    iconColor: 'orange-9',
  },
])

const deviceBars = computed(() => {
  const total = deviceDistribution.value.reduce((s, d) => s + d.count, 0) || 1
  const colors = ['#4f46e5', '#06b6d4', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#64748b']
  return deviceDistribution.value.map((d, i) => ({
    ...d,
    pct: (d.count / total) * 100,
    color: colors[i % colors.length],
  }))
})

const overdueColumns = [
  { name: 'job_no', label: 'Job #', field: 'job_no', align: 'left' },
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'device_type', label: 'Device', field: 'device_type', align: 'left' },
  { name: 'estimated_fix_date', label: 'ETA', field: 'estimated_fix_date', align: 'left' },
  { name: 'days_overdue', label: 'Overdue', field: 'days_overdue', align: 'center' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
]

async function loadData() {
  const companyId = authStore.currentBranch?.company_id
  if (!companyId) return
  loading.value = true

  try {
    // Total jobs + completed + revenue
    const { data: jobs } = await supabase
      .from('service_jobs')
      .select(
        'id, status, total_final_cost, received_date, delivered_date, estimated_fix_date, device_type, customer:customers(name)',
      )
      .eq('company_id', companyId)

    const all = jobs || []
    totalJobs.value = all.length
    const completed = all.filter((j) => ['delivered', 'closed'].includes(j.status))
    totalCompleted.value = completed.length
    totalRevenue.value = completed.reduce((s, j) => s + Number(j.total_final_cost || 0), 0)

    // Avg repair time
    const times = completed
      .filter((j) => j.delivered_date && j.received_date)
      .map((j) => (new Date(j.delivered_date) - new Date(j.received_date)) / 86400000)
    avgRepairDays.value = times.length
      ? Math.round(times.reduce((a, b) => a + b, 0) / times.length)
      : 0

    // Device distribution
    const devMap = {}
    all.forEach((j) => {
      devMap[j.device_type] = (devMap[j.device_type] || 0) + 1
    })
    deviceDistribution.value = Object.entries(devMap)
      .map(([type, count]) => ({ type, count }))
      .sort((a, b) => b.count - a.count)

    // Overdue jobs
    const today = new Date().toISOString().split('T')[0]
    overdueJobs.value = all
      .filter(
        (j) =>
          j.estimated_fix_date &&
          j.estimated_fix_date < today &&
          !['delivered', 'closed', 'cancelled'].includes(j.status),
      )
      .map((j) => ({
        ...j,
        customer_name: j.customer?.name || 'Walk-in',
        days_overdue: Math.ceil((new Date() - new Date(j.estimated_fix_date)) / 86400000),
      }))
      .sort((a, b) => b.days_overdue - a.days_overdue)

    // Common issues
    const diag = await serviceStore.fetchCommonIssues()
    const issueMap = {}
    diag.forEach((d) => {
      const key = d.error_title
      if (!issueMap[key]) issueMap[key] = { title: key, category: d.category, count: 0 }
      issueMap[key].count++
    })
    commonIssues.value = Object.values(issueMap)
      .sort((a, b) => b.count - a.count)
      .slice(0, 8)
  } catch (err) {
    console.error('Report load error:', err)
  } finally {
    loading.value = false
  }
}

onMounted(loadData)
</script>

<style scoped lang="scss">
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
.device-bars {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.device-bar-row {
  display: flex;
  align-items: center;
  gap: 12px;
}
.device-bar-label {
  width: 100px;
  font-size: 13px;
}
.device-bar-track {
  flex: 1;
  height: 10px;
  border-radius: 5px;
  background: v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'");
  overflow: hidden;
}
.device-bar-fill {
  height: 100%;
  border-radius: 5px;
  transition: width 0.6s ease;
}
.device-bar-count {
  width: 36px;
  text-align: right;
  font-size: 14px;
}
</style>

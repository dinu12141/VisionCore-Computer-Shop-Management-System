<template>
  <q-page class="q-pa-lg">
    <!-- Header -->
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bolder q-ma-none text-gradient">Service Jobs</h1>
        <div class="text-subtitle2 text-grey-6">Manage all device repair & service tickets</div>
      </div>
      <div class="col-auto q-gutter-sm">
        <q-btn color="primary" icon="add" label="New Job" @click="$router.push('/services/new')" />
      </div>
    </div>

    <!-- Filters -->
    <q-card flat bordered class="glass-card q-mb-lg">
      <q-card-section>
        <div class="row q-col-gutter-xs items-center">
          <div class="col-12 col-md-4">
            <q-input
              v-model="filters.search"
              dense
              outlined
              clearable
              placeholder="Search job #, brand, customer name, phone, email etc..."
              :dark="$q.dark.isActive"
            >
              <template v-slot:prepend><q-icon name="search" /></template>
            </q-input>
          </div>
          <div class="col-6 col-md-2">
            <q-select
              v-model="filters.status"
              :options="statusOptions"
              dense
              outlined
              clearable
              emit-value
              map-options
              label="Status"
              :dark="$q.dark.isActive"
            />
          </div>
          <div class="col-6 col-md-2">
            <q-select
              v-model="filters.priority"
              :options="priorityOptions"
              dense
              outlined
              clearable
              emit-value
              map-options
              label="Priority"
              :dark="$q.dark.isActive"
            />
          </div>
          <div class="col-6 col-md-2">
            <q-select
              v-model="filters.device_type"
              :options="deviceOptions"
              dense
              outlined
              clearable
              emit-value
              map-options
              label="Device Type"
              :dark="$q.dark.isActive"
            />
          </div>
          <div class="col-6 col-md-2 flex items-center">
            <q-toggle
              v-model="filters.overdue"
              label="Overdue Only"
              dense
              :dark="$q.dark.isActive"
              color="negative"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Jobs Table -->
    <q-card flat bordered class="glass-card">
      <q-table
        :rows="store.jobs"
        :columns="columns"
        row-key="id"
        flat
        class="bg-transparent"
        :dark="$q.dark.isActive"
        :loading="store.loading"
        :pagination="{ rowsPerPage: 20 }"
        @row-click="(_, row) => $router.push(`/services/jobs/${row.id}`)"
        style="cursor: pointer"
      >
        <!-- Status Column -->
        <template v-slot:body-cell-status="props">
          <q-td :props="props">
            <q-badge
              :color="store.STATUS_COLORS[props.row.status]"
              :label="store.STATUS_LABELS[props.row.status]"
              class="text-capitalize"
            />
          </q-td>
        </template>

        <!-- Priority Column -->
        <template v-slot:body-cell-priority="props">
          <q-td :props="props">
            <q-badge
              :color="store.PRIORITY_COLORS[props.row.priority]"
              :label="props.row.priority"
              class="text-capitalize"
              outline
            />
          </q-td>
        </template>

        <!-- Customer Column -->
        <template v-slot:body-cell-customer="props">
          <q-td :props="props">
            <div class="text-weight-medium">{{ props.row.customer?.name || 'Walk-in' }}</div>
            <div class="text-caption text-grey">{{ props.row.customer?.phone || '' }}</div>
          </q-td>
        </template>

        <!-- Device Column -->
        <template v-slot:body-cell-device="props">
          <q-td :props="props">
            <div class="text-weight-medium text-capitalize">{{ props.row.device_type }}</div>
            <div class="text-caption text-grey">
              {{ props.row.brand || '' }} {{ props.row.model || '' }}
            </div>
          </q-td>
        </template>

        <!-- Payment Column -->
        <template v-slot:body-cell-payment_status="props">
          <q-td :props="props">
            <q-badge
              :color="
                props.row.payment_status === 'paid'
                  ? 'positive'
                  : props.row.payment_status === 'partial'
                    ? 'warning'
                    : 'grey'
              "
              :label="props.row.payment_status"
              class="text-capitalize"
            />
          </q-td>
        </template>

        <!-- Cost Column -->
        <template v-slot:body-cell-cost="props">
          <q-td :props="props">
            <div class="text-weight-bold">
              LKR
              {{
                Number(
                  props.row.total_final_cost || props.row.total_estimated_cost || 0,
                ).toLocaleString()
              }}
            </div>
          </q-td>
        </template>

        <!-- Actions Column -->
        <template v-slot:body-cell-actions="props">
          <q-td :props="props" @click.stop>
            <q-btn
              flat
              round
              dense
              icon="visibility"
              color="primary"
              size="sm"
              @click="$router.push(`/services/jobs/${props.row.id}`)"
            >
              <q-tooltip>View Details</q-tooltip>
            </q-btn>
          </q-td>
        </template>

        <template v-slot:no-data>
          <div class="full-width text-center q-pa-xl text-grey-5">
            <q-icon name="handyman" size="56px" class="q-mb-md" /><br />
            No service jobs found
          </div>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup>
import { reactive, onMounted, watch } from 'vue'
import { useQuasar, debounce } from 'quasar'
import { useServiceStore } from 'src/stores/serviceStore'

const $q = useQuasar()
const store = useServiceStore()

const filters = reactive({
  search: '',
  status: null,
  priority: null,
  device_type: null,
  overdue: false,
})

const statusOptions = [
  { label: 'Received', value: 'received' },
  { label: 'Diagnosing', value: 'diagnosing' },
  { label: 'Waiting Approval', value: 'waiting_approval' },
  { label: 'Repairing', value: 'repairing' },
  { label: 'Ready', value: 'ready' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Closed', value: 'closed' },
  { label: 'Cancelled', value: 'cancelled' },
]

const priorityOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Normal', value: 'normal' },
  { label: 'High', value: 'high' },
  { label: 'Urgent', value: 'urgent' },
]

const deviceOptions = [
  { label: 'Laptop', value: 'laptop' },
  { label: 'Desktop', value: 'desktop' },
  { label: 'Printer', value: 'printer' },
  { label: 'Phone', value: 'phone' },
  { label: 'Tablet', value: 'tablet' },
  { label: 'Monitor', value: 'monitor' },
  { label: 'Other', value: 'other' },
]

const columns = [
  { name: 'job_no', label: 'Job #', align: 'left', field: 'job_no', sortable: true },
  { name: 'customer', label: 'Customer', align: 'left', field: 'customer' },
  { name: 'device', label: 'Device', align: 'left', field: 'device_type' },
  { name: 'priority', label: 'Priority', align: 'center', field: 'priority' },
  { name: 'status', label: 'Status', align: 'center', field: 'status', sortable: true },
  {
    name: 'received_date',
    label: 'Received',
    align: 'left',
    field: 'received_date',
    sortable: true,
  },
  {
    name: 'estimated_fix_date',
    label: 'ETA',
    align: 'left',
    field: 'estimated_fix_date',
    sortable: true,
  },
  { name: 'payment_status', label: 'Payment', align: 'center', field: 'payment_status' },
  { name: 'cost', label: 'Cost', align: 'right', field: 'total_estimated_cost', sortable: true },
  { name: 'actions', label: '', align: 'center', field: 'actions' },
]

async function executeSearch() {
  try {
    await store.fetchJobs({ ...filters })
  } catch (err) {
    if (err.name !== 'AbortError') {
      $q.notify({ type: 'negative', message: 'Failed to load jobs: ' + err.message })
    }
  }
}

const debouncedSearch = debounce(executeSearch, 300)

watch(
  filters,
  () => {
    debouncedSearch()
  },
  { deep: true },
)

onMounted(executeSearch)
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
</style>

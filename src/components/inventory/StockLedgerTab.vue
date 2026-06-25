<template>
  <div class="q-pa-md">
    <!-- Filters -->
    <div class="row items-center q-mb-md q-gutter-sm">
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="search"
        placeholder="Search item or doc #..."
        style="min-width: 250px"
      >
        <template #prepend><q-icon name="search" /></template>
      </q-input>
      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="docTypeFilter"
        :options="docTypeOptions"
        label="Doc Type"
        emit-value
        map-options
        style="min-width: 180px"
      />
      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="directionFilter"
        :options="directionOptions"
        label="Direction"
        emit-value
        map-options
        style="min-width: 120px"
      />
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="dateFrom"
        type="date"
        label="From"
        style="min-width: 150px"
      />
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="dateTo"
        type="date"
        label="To"
        style="min-width: 150px"
      />
      <q-space />
      <q-btn outline color="grey-5" icon="refresh" round dense @click="reload">
        <q-tooltip>Refresh</q-tooltip>
      </q-btn>
    </div>

    <!-- Ledger Table (Read Only) -->
    <q-card
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      flat
      bordered
    >
      <q-card-section class="q-pb-sm">
        <div class="text-h6">
          <q-icon name="menu_book" class="q-mr-sm" />Stock Ledger — Audit Trail
        </div>
      </q-card-section>
      <q-card-section class="q-pt-none">
        <q-table
          :rows="entries"
          :columns="columns"
          row-key="id"
          :dark="$q.dark.isActive"
          flat
          bordered
          dense
          class="bg-transparent"
          :table-header-class="
            $q.dark.isActive ? 'text-grey-5 text-uppercase' : 'text-grey-7 text-uppercase'
          "
          :loading="loading"
          :filter="search"
          :rows-per-page-options="[15, 30, 50]"
        >
          <!-- Direction badge -->
          <template #body-cell-direction="props">
            <q-td :props="props">
              <q-badge :color="props.value === 'IN' ? 'green' : 'red'" class="text-weight-bold">
                <q-icon
                  :name="props.value === 'IN' ? 'arrow_downward' : 'arrow_upward'"
                  size="14px"
                  class="q-mr-xs"
                />
                {{ props.value }}
              </q-badge>
            </q-td>
          </template>

          <!-- Doc Type -->
          <template #body-cell-doc_type="props">
            <q-td :props="props">
              <q-chip dense size="sm" :color="getDocColor(props.value)" text-color="white">
                {{ props.value }}
              </q-chip>
            </q-td>
          </template>

          <!-- Costs -->
          <template #body-cell-unit_cost="props">
            <q-td :props="props">{{ formatCurrency(props.value) }}</q-td>
          </template>

          <template #body-cell-total_cost="props">
            <q-td :props="props">
              <span class="text-weight-bold">{{ formatCurrency(props.value) }}</span>
            </q-td>
          </template>

          <!-- Posted At -->
          <template #body-cell-posted_at="props">
            <q-td :props="props">
              <span class="text-caption">{{ formatDateTime(props.value) }}</span>
            </q-td>
          </template>

          <!-- No data -->
          <template #no-data>
            <div class="full-width row flex-center text-grey-5 q-pa-lg">
              <q-icon size="2em" name="menu_book" class="q-mr-sm" />
              <span>No ledger entries found</span>
            </div>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useStockLedger } from 'src/services/inventoryService'

const { entries, loading, fetchLedger, cleanup } = useStockLedger()

onUnmounted(() => {
  cleanup()
})

const search = ref('')
const docTypeFilter = ref('')
const directionFilter = ref('')
const dateFrom = ref('')
const dateTo = ref('')

const docTypeOptions = [
  { label: 'All Types', value: '' },
  { label: 'GRN', value: 'GRN' },
  { label: 'GIN', value: 'GIN' },
  { label: 'Transfer', value: 'TRANSFER' },
  { label: 'Adjustment', value: 'ADJUSTMENT' },
  { label: 'Stock Count', value: 'STOCK_COUNT' },
  { label: 'BOM Deduct', value: 'BOM_DEDUCT' },
]

const directionOptions = [
  { label: 'All', value: '' },
  { label: 'IN', value: 'IN' },
  { label: 'OUT', value: 'OUT' },
]

function buildFilters() {
  return {
    docType: docTypeFilter.value || undefined,
    direction: directionFilter.value || undefined,
    dateFrom: dateFrom.value || undefined,
    dateTo: dateTo.value || undefined,
    search: search.value || undefined,
  }
}

async function reload() {
  await fetchLedger(buildFilters())
}

onMounted(() => reload())

watch([docTypeFilter, directionFilter, dateFrom, dateTo], () => reload())

const columns = [
  {
    name: 'posted_at',
    label: 'Date/Time',
    field: 'posted_at',
    align: 'left',
    sortable: true,
    style: 'width: 140px',
  },
  { name: 'doc_type', label: 'Type', field: 'doc_type', align: 'center', sortable: true },
  { name: 'doc_number', label: 'Doc #', field: 'doc_number', align: 'left', sortable: true },
  { name: 'warehouse_name', label: 'Warehouse', field: 'warehouse_name', align: 'left' },
  { name: 'item_code', label: 'Code', field: 'item_code', align: 'left' },
  { name: 'item_name', label: 'Item', field: 'item_name', align: 'left' },
  { name: 'direction', label: 'Dir', field: 'direction', align: 'center', sortable: true },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right', sortable: true },
  { name: 'uom_code', label: 'UOM', field: 'uom_code', align: 'center' },
  { name: 'unit_cost', label: 'Unit Cost', field: 'unit_cost', align: 'right' },
  { name: 'total_cost', label: 'Total Cost', field: 'total_cost', align: 'right', sortable: true },
  { name: 'posted_by_name', label: 'By', field: 'posted_by_name', align: 'left' },
]

function getDocColor(type) {
  const map = {
    GRN: 'green-9',
    GIN: 'red-9',
    TRANSFER: 'blue-9',
    ADJUSTMENT: 'orange-9',
    STOCK_COUNT: 'purple-9',
    BOM_DEDUCT: 'cyan-9',
  }
  return map[type] || 'grey-8'
}

function formatCurrency(val) {
  return 'LKR ' + Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}

function formatDateTime(val) {
  if (!val) return '-'
  const d = new Date(val)
  return (
    d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  )
}
</script>

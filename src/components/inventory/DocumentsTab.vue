<template>
  <div class="q-pa-md">
    <!-- Filters -->
    <div class="row items-center q-mb-md q-gutter-sm">
      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="docTypeFilter"
        :options="docTypeOptions"
        label="Document Type"
        emit-value
        map-options
        style="min-width: 200px"
      />
      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="statusFilter"
        :options="statusOptions"
        label="Status"
        emit-value
        map-options
        style="min-width: 150px"
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
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="search"
        placeholder="Search doc #..."
        style="min-width: 200px"
      >
        <template #prepend><q-icon name="search" /></template>
      </q-input>
      <q-space />
      <q-btn outline color="grey-5" icon="refresh" round dense @click="reload">
        <q-tooltip>Refresh</q-tooltip>
      </q-btn>
      <q-btn color="primary" icon="add" label="New Document" @click="$emit('create-document')" />
    </div>

    <!-- Documents Table -->
    <q-card
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      flat
      bordered
    >
      <q-card-section>
        <q-table
          :rows="documents"
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
          :rows-per-page-options="[10, 25, 50]"
          @row-click="(evt, row) => $emit('view-document', row)"
          row-class="cursor-pointer"
        >
          <!-- Doc Type badge -->
          <template #body-cell-doc_type="props">
            <q-td :props="props">
              <q-chip
                dense
                size="sm"
                :color="getDocColor(props.value)"
                text-color="white"
                :icon="getDocIcon(props.value)"
              >
                {{ props.value }}
              </q-chip>
            </q-td>
          </template>

          <!-- Status chip -->
          <template #body-cell-status="props">
            <q-td :props="props">
              <q-chip
                dense
                size="sm"
                :color="getStatusColor(props.value)"
                :text-color="getStatusTextColor(props.value)"
                :icon="getStatusIcon(props.value)"
                class="text-weight-bold text-uppercase"
              >
                {{ props.value }}
              </q-chip>
            </q-td>
          </template>

          <!-- Cost formatting -->
          <template #body-cell-total_cost="props">
            <q-td :props="props">
              <span class="text-weight-bold">{{ formatCurrency(props.value) }}</span>
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props">
              <q-btn
                v-if="props.row.status === 'draft'"
                flat
                dense
                round
                icon="edit"
                size="sm"
                color="orange"
                @click.stop="$emit('edit-document', props.row)"
              >
                <q-tooltip>Edit draft</q-tooltip>
              </q-btn>
            </q-td>
          </template>

          <!-- No data -->
          <template #no-data>
            <div class="full-width row flex-center text-grey-5 q-pa-lg">
              <q-icon size="2em" name="description" class="q-mr-sm" />
              <span>No documents found matching your filters</span>
            </div>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { useDocumentList } from 'src/services/inventoryService'

defineEmits(['create-document', 'view-document', 'edit-document'])

const { documents, loading, listDocuments } = useDocumentList()

const search = ref('')
const docTypeFilter = ref('')
const statusFilter = ref('')
const dateFrom = ref('')
const dateTo = ref('')

const docTypeOptions = [
  { label: 'All Types', value: '' },
  { label: 'PO', value: 'PO' },
  { label: 'GRN', value: 'GRN' },
  { label: 'GIN', value: 'GIN' },
  { label: 'Transfer', value: 'TRANSFER' },
  { label: 'Adjustment', value: 'ADJUSTMENT' },
  { label: 'Stock Count', value: 'STOCK_COUNT' },
]

const statusOptions = [
  { label: 'All Statuses', value: '' },
  { label: 'Draft', value: 'draft' },
  { label: 'Posted', value: 'posted' },
  { label: 'Cancelled', value: 'cancelled' },
]

function buildFilters() {
  return {
    docType: docTypeFilter.value || undefined,
    status: statusFilter.value || undefined,
    dateFrom: dateFrom.value || undefined,
    dateTo: dateTo.value || undefined,
    search: search.value || undefined,
  }
}

async function reload() {
  await listDocuments(buildFilters())
}

onMounted(() => reload())

// Re-fetch when filters change (debounced via watchers)
watch([docTypeFilter, statusFilter, dateFrom, dateTo], () => reload())

const columns = [
  {
    name: 'doc_type',
    label: 'Type',
    field: 'doc_type',
    align: 'left',
    sortable: true,
    style: 'width: 120px',
  },
  { name: 'doc_number', label: 'Doc #', field: 'doc_number', align: 'left', sortable: true },
  { name: 'doc_date', label: 'Date', field: 'doc_date', align: 'center', sortable: true },
  { name: 'warehouse_name', label: 'Warehouse', field: 'warehouse_name', align: 'left' },
  {
    name: 'supplier_or_target',
    label: 'Supplier / Target',
    align: 'left',
    field: (row) => row.supplier_name || row.target_warehouse_name || '-',
  },
  { name: 'total_qty', label: 'Qty', field: 'total_qty', align: 'right', sortable: true },
  { name: 'total_cost', label: 'Total Cost', field: 'total_cost', align: 'right', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
  { name: 'created_by_name', label: 'Created By', field: 'created_by_name', align: 'left' },
  { name: 'actions', label: '', field: 'actions', align: 'center', style: 'width: 80px' },
]

function getDocColor(type) {
  const map = {
    PO: 'indigo-9',
    GRN: 'green-9',
    GIN: 'red-9',
    TRANSFER: 'blue-9',
    ADJUSTMENT: 'orange-9',
    STOCK_COUNT: 'purple-9',
    BOM_DEDUCT: 'cyan-9',
  }
  return map[type] || 'grey-8'
}

function getDocIcon(type) {
  const map = {
    PO: 'shopping_cart',
    GRN: 'archive',
    GIN: 'unarchive',
    TRANSFER: 'swap_horiz',
    ADJUSTMENT: 'tune',
    STOCK_COUNT: 'fact_check',
    BOM_DEDUCT: 'restaurant',
  }
  return map[type] || 'description'
}

function getStatusColor(s) {
  const map = { draft: 'grey-8', posted: 'green-9', cancelled: 'red-9' }
  return map[s] || 'grey-8'
}

function getStatusTextColor(s) {
  const map = { draft: 'grey-3', posted: 'green-1', cancelled: 'red-1' }
  return map[s] || 'grey-3'
}

function getStatusIcon(s) {
  const map = { draft: 'edit_note', posted: 'verified', cancelled: 'cancel' }
  return map[s] || 'info'
}

function formatCurrency(val) {
  return 'LKR ' + Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}
</script>

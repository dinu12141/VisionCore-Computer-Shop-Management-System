<template>
  <div class="q-pa-md">
    <!-- Filters -->
    <div class="row items-center q-mb-md q-gutter-sm">
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="search"
        placeholder="Search items..."
        style="min-width: 250px"
      >
        <template #prepend><q-icon name="search" /></template>
      </q-input>

      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="warehouseFilter"
        :options="warehouseOptions"
        label="Warehouse"
        emit-value
        map-options
        clearable
        style="min-width: 200px"
      />

      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="statusFilter"
        :options="statusOptions"
        label="Stock Status"
        emit-value
        map-options
        clearable
        style="min-width: 180px"
      />

      <q-space />

      <q-btn outline color="grey-5" icon="refresh" round dense @click="fetchStockOnHand">
        <q-tooltip>Refresh Stock</q-tooltip>
      </q-btn>
    </div>

    <!-- Stock Table -->
    <q-card
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      flat
      bordered
    >
      <q-card-section>
        <q-table
          :rows="filteredStock"
          :columns="columns"
          row-key="id"
          :dark="$q.dark.isActive"
          flat
          dense
          class="bg-transparent"
          :loading="loading"
          :filter="search"
          :rows-per-page-options="[12, 24, 48]"
        >
          <!-- Warehouse Cell -->
          <template #body-cell-warehouse_name="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <q-icon
                  :name="getWhIcon(props.row.warehouse_type)"
                  :color="getWhColor(props.row.warehouse_type)"
                  size="18px"
                  class="q-mr-sm"
                />
                {{ props.value }}
              </div>
            </q-td>
          </template>

          <!-- Qty Cell -->
          <template #body-cell-qty_on_hand="props">
            <q-td :props="props" class="text-right">
              <span class="text-h6 text-weight-bold" :class="getQtyColor(props.row)">
                {{ props.value.toLocaleString() }}
              </span>
              <span class="text-caption text-grey-5 q-ml-xs">{{ props.row.uom_code }}</span>
            </q-td>
          </template>

          <!-- Status Cell -->
          <template #body-cell-stock_status="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="getStatusColor(props.value)"
                class="text-weight-bold text-uppercase"
                style="padding: 4px 8px"
              >
                {{ props.value.replace('_', ' ') }}
              </q-badge>
            </q-td>
          </template>

          <!-- Value Cell -->
          <template #body-cell-total_value="props">
            <q-td :props="props" class="text-right">
              <span class="text-weight-medium">{{ formatCurrency(props.value) }}</span>
            </q-td>
          </template>

          <!-- No data -->
          <template #no-data>
            <div class="full-width row flex-center text-grey-5 q-pa-xl">
              <q-icon size="3em" name="inventory_2" class="q-mr-md" />
              <div>
                <div class="text-h6">No stock records found</div>
                <div class="text-caption">Try adjusting your filters or refreshing the data</div>
              </div>
            </div>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useStockDashboard, useWarehouseList } from 'src/services/inventoryService'

const { stockOnHand, loading, fetchStockOnHand, cleanup } = useStockDashboard()
const { warehouses, listWarehouses } = useWarehouseList()

const search = ref('')
const warehouseFilter = ref(null)
const statusFilter = ref(null)

onMounted(() => {
  fetchStockOnHand()
  listWarehouses()
})

onUnmounted(() => {
  cleanup()
})

const warehouseOptions = computed(() => [
  { label: 'All Warehouses', value: null },
  ...warehouses.value.map((w) => ({ label: w.name, value: w.id })),
])

const statusOptions = [
  { label: 'All Statuses', value: null },
  { label: 'Normal', value: 'normal' },
  { label: 'Low Stock', value: 'low_stock' },
  { label: 'Out of Stock', value: 'out_of_stock' },
  { label: 'Overstock', value: 'overstock' },
]

const filteredStock = computed(() => {
  let result = stockOnHand.value

  if (warehouseFilter.value) {
    result = result.filter((s) => s.warehouse_id === warehouseFilter.value)
  }

  if (statusFilter.value) {
    result = result.filter((s) => s.stock_status === statusFilter.value)
  }

  return result
})

const columns = [
  {
    name: 'item_name',
    label: 'Item Name',
    field: 'item_name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'item_code',
    label: 'Code',
    field: 'item_code',
    align: 'left',
    sortable: true,
  },
  {
    name: 'warehouse_name',
    label: 'Warehouse',
    field: 'warehouse_name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'qty_on_hand',
    label: 'On Hand',
    field: 'qty_on_hand',
    align: 'right',
    sortable: true,
  },
  {
    name: 'stock_status',
    label: 'Status',
    field: 'stock_status',
    align: 'center',
    sortable: true,
  },
  {
    name: 'total_value',
    label: 'Stock Value',
    field: 'total_value',
    align: 'right',
    sortable: true,
  },
]

function getWhIcon(type) {
  const map = {
    main_store: 'warehouse',
    kitchen: 'soup_kitchen',
    bar: 'local_bar',
    freezer: 'ac_unit',
    dry_store: 'inventory_2',
  }
  return map[type] || 'store'
}

function getWhColor(type) {
  const map = {
    main_store: 'teal',
    kitchen: 'orange',
    bar: 'purple',
    freezer: 'cyan',
    dry_store: 'brown',
  }
  return map[type] || 'grey'
}

function getStatusColor(status) {
  const map = {
    normal: 'green-8',
    low_stock: 'orange-9',
    out_of_stock: 'red-9',
    overstock: 'blue-8',
  }
  return map[status] || 'grey'
}

function getQtyColor(row) {
  if (row.qty_on_hand <= 0) return 'text-red'
  if (row.stock_status === 'low_stock') return 'text-orange'
  return 'text-primary'
}

function formatCurrency(val) {
  return 'LKR ' + Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}
</script>

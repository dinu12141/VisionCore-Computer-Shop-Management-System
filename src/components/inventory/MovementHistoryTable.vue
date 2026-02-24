<template>
  <q-table
    flat
    bordered
    :title="title"
    :rows="movements"
    :columns="columns"
    row-key="id"
    :filter="filter"
    :dark="$q.dark.isActive"
    color="primary"
  >
    <template #top-right>
      <q-input
        dense
        outlined
        debounce="300"
        v-model="filter"
        placeholder="Search movements..."
        :dark="$q.dark.isActive"
      >
        <template v-slot:append>
          <q-icon name="search" />
        </template>
      </q-input>
      <div class="q-ml-sm">
        <q-btn flat icon="cloud_download" label="Export" @click="exportTable" />
      </div>
    </template>

    <template #body-cell-type="props">
      <q-td :props="props">
        <q-chip
          :color="getTypeColor(props.value)"
          text-color="white"
          dense
          class="text-weight-bold"
        >
          {{ props.value }}
        </q-chip>
      </q-td>
    </template>

    <template #body-cell-quantity="props">
      <q-td :props="props">
        <span :class="getQuantityColor(props.row.type)">
          {{ props.row.type === 'OUT' || props.row.type === 'WASTAGE' ? '-' : '+'
          }}{{ props.value }} {{ props.row.unit }}
        </span>
      </q-td>
    </template>
  </q-table>
</template>

<script setup>
import { ref } from 'vue'

defineProps({
  title: {
    type: String,
    default: 'Movement History',
  },
})

const filter = ref('')

// Mock Data
const movements = ref([
  {
    id: 1,
    date: '2024-02-17 10:30',
    item: 'Tomato',
    type: 'IN',
    quantity: 50,
    unit: 'kg',
    reason: 'Purchase Order #1234',
    performedBy: 'Admin',
  },
  {
    id: 2,
    date: '2024-02-17 11:15',
    item: 'Onion',
    type: 'OUT',
    quantity: 5,
    unit: 'kg',
    reason: 'Kitchen Use',
    performedBy: 'Chef John',
  },
  {
    id: 3,
    date: '2024-02-16 18:45',
    item: 'Cheese',
    type: 'WASTAGE',
    quantity: 2,
    unit: 'kg',
    reason: 'Expired',
    performedBy: 'Manager',
  },
  {
    id: 4,
    date: '2024-02-16 09:00',
    item: 'Flour',
    type: 'IN',
    quantity: 100,
    unit: 'kg',
    reason: 'Purchase Order #1230',
    performedBy: 'Admin',
  },
  {
    id: 5,
    date: '2024-02-15 14:20',
    item: 'Chicken',
    type: 'ADJUSTMENT',
    quantity: 2,
    unit: 'kg',
    reason: 'Stock Take Correction',
    performedBy: 'Manager',
  },
  {
    id: 6,
    date: '2024-02-15 12:00',
    item: 'Tomato',
    type: 'OUT',
    quantity: 10,
    unit: 'kg',
    reason: 'Kitchen Use',
    performedBy: 'Chef John',
  },
])

const columns = [
  { name: 'date', align: 'left', label: 'Date & Time', field: 'date', sortable: true },
  { name: 'item', align: 'left', label: 'Item Name', field: 'item', sortable: true },
  { name: 'type', align: 'center', label: 'Type', field: 'type', sortable: true },
  { name: 'quantity', align: 'right', label: 'Quantity', field: 'quantity', sortable: true },
  { name: 'reason', align: 'left', label: 'Reason / Reference', field: 'reason' },
  { name: 'performedBy', align: 'left', label: 'Performed By', field: 'performedBy' },
]

const getTypeColor = (type) => {
  switch (type) {
    case 'IN':
      return 'positive'
    case 'OUT':
      return 'primary'
    case 'ADJUSTMENT':
      return 'warning'
    case 'WASTAGE':
      return 'negative'
    default:
      return 'grey'
  }
}

const getQuantityColor = (type) => {
  switch (type) {
    case 'IN':
      return 'text-positive'
    case 'OUT':
      return 'text-primary'
    case 'ADJUSTMENT':
      return 'text-warning'
    case 'WASTAGE':
      return 'text-negative'
    default:
      return 'text-grey'
  }
}

const exportTable = () => {
  console.log('Exporting table...')
  // Implementation for export would go here
}
</script>

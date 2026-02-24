<template>
  <q-card
    flat
    bordered
    class="q-pa-sm"
    :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
  >
    <q-card-section>
      <div class="text-h6">Recent Orders</div>
    </q-card-section>
    <q-table
      :rows="rows"
      :columns="columns"
      row-key="id"
      flat
      :pagination="{ rowsPerPage: 5 }"
      hide-pagination
      :dark="$q.dark.isActive"
      class="bg-transparent"
    >
      <template v-slot:body-cell-status="props">
        <q-td :props="props">
          <q-badge :color="getStatusColor(props.value)" :label="props.value" />
        </q-td>
      </template>
      <template v-slot:body-cell-action="props">
        <q-td :props="props" class="q-gutter-xs">
          <q-btn flat round dense icon="print" size="sm" color="grey-7" />
          <q-btn flat round dense icon="arrow_forward" size="sm" color="primary" />
        </q-td>
      </template>
    </q-table>
  </q-card>
</template>

<script setup>
const columns = [
  { name: 'id', label: 'Order #', field: 'id', align: 'left', sortable: true },
  { name: 'items', label: 'Items', field: 'items', align: 'left' },
  { name: 'table', label: 'Table', field: 'table', align: 'left' },
  { name: 'total', label: 'Total', field: 'total', format: (val) => `$${val}`, sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'action', label: 'Action', field: 'action', align: 'right' },
]

const rows = [
  { id: 'ORD-001', items: '2x Pizza, 1x Cola', table: 'T-05', total: 45.0, status: 'Pending' },
  { id: 'ORD-002', items: '1x Burger, 1x Fries', table: 'T-02', total: 18.5, status: 'Completed' },
  { id: 'ORD-003', items: '3x Pasta', table: 'T-08', total: 36.0, status: 'Preparing' },
  { id: 'ORD-004', items: '2x Salad, 1x Water', table: 'T-01', total: 22.0, status: 'Delivered' },
  { id: 'ORD-005', items: '1x Steak', table: 'T-04', total: 35.0, status: 'Pending' },
]

function getStatusColor(status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'warning'
    case 'preparing':
      return 'info'
    case 'delivered':
      return 'positive'
    case 'completed':
      return 'positive'
    default:
      return 'grey'
  }
}
</script>

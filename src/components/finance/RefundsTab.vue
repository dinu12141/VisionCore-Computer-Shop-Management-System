<template>
  <div>
    <DataTable title="Refunds" :rows="refunds" :columns="columns" :filter="filter">
      <template #top-right>
        <q-input
          dense
          outlined
          v-model="filter"
          placeholder="Search refunds..."
          :dark="$q.dark.isActive"
        >
          <template v-slot:append>
            <q-icon name="search" />
          </template>
        </q-input>
      </template>

      <template #body-cell-status="props">
        <q-td :props="props">
          <StatusChip :status="props.value" />
        </q-td>
      </template>

      <template #body-cell-reason="props">
        <q-td :props="props" style="max-width: 200px; white-space: normal">
          {{ props.value }}
        </q-td>
      </template>

      <template #body-cell-amount="props">
        <q-td :props="props">
          <div class="text-red">-{{ props.value }}</div>
        </q-td>
      </template>
    </DataTable>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import DataTable from 'components/common/DataTable.vue'
import StatusChip from 'components/common/StatusChip.vue'

const filter = ref('')

const columns = [
  { name: 'id', label: 'Refund ID', align: 'left', field: 'refundId', sortable: true },
  { name: 'date', label: 'Date', align: 'left', field: 'date', sortable: true },
  { name: 'invoice', label: 'Original Invoice', align: 'left', field: 'originalInvoice' },
  { name: 'reason', label: 'Reason', align: 'left', field: 'reason' },
  { name: 'amount', label: 'Amount', align: 'right', field: 'amount', sortable: true },
  { name: 'status', label: 'Status', align: 'center', field: 'status' },
]

const refunds = ref([
  {
    id: 1,
    refundId: 'REF-001',
    date: '2023-10-25 04:00 PM',
    originalInvoice: 'INV-1004',
    reason: 'Customer cancelled order before preparation',
    amount: 'LKR 1,500.00',
    status: 'Completed',
  },
  {
    id: 2,
    refundId: 'REF-002',
    date: '2023-10-24 08:00 PM',
    originalInvoice: 'INV-0998',
    reason: 'Wrong item served',
    amount: 'LKR 1,250.00',
    status: 'Processing',
  },
])
</script>

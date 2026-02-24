<template>
  <q-card flat bordered class="glass-container fit overflow-hidden">
    <q-card-section class="row items-center">
      <div class="text-h6 text-weight-bold">Outstanding Collections</div>
      <q-space />
      <q-btn flat color="primary" label="View All" to="/collections/outstanding" dense />
    </q-card-section>

    <q-table
      flat
      :rows="data"
      :columns="columns"
      row-key="invoice_id"
      :loading="loading"
      hide-bottom
      class="bg-transparent dashboard-table"
      :pagination="{ rowsPerPage: 10 }"
    >
      <template v-slot:body-cell-collection_date="props">
        <q-td :props="props">
          <div :class="isOverdue(props.value) ? 'text-negative text-weight-bold' : ''">
            {{ formatDate(props.value) }}
            <q-badge
              v-if="isOverdue(props.value)"
              color="negative"
              label="Overdue"
              size="xs"
              class="q-ml-xs"
            />
          </div>
        </q-td>
      </template>

      <template v-slot:body-cell-balance="props">
        <q-td :props="props" class="text-weight-bold">
          LKR {{ props.value.toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
        </q-td>
      </template>

      <template v-slot:body-cell-actions="props">
        <q-td :props="props" class="text-right">
          <q-btn
            flat
            round
            color="primary"
            icon="visibility"
            size="sm"
            :to="`/billing/history?invoice_no=${props.row.invoice_no}`"
          >
            <q-tooltip>View Invoice</q-tooltip>
          </q-btn>
          <q-btn
            flat
            round
            color="positive"
            icon="add_card"
            size="sm"
            @click="$emit('add-payment', props.row)"
          >
            <q-tooltip>Add Payment</q-tooltip>
          </q-btn>
        </q-td>
      </template>
    </q-table>

    <div v-if="!loading && data.length === 0" class="flex flex-center q-pa-xl text-grey-6">
      <q-icon name="check_circle" size="48px" class="q-mb-md block" />
      <div>No outstanding collections found.</div>
    </div>
  </q-card>
</template>

<script setup>
import { date } from 'quasar'

defineProps({
  data: { type: Array, default: () => [] },
  loading: Boolean,
})

defineEmits(['add-payment'])

const columns = [
  {
    name: 'collection_date',
    label: 'Due Date',
    field: 'collection_date',
    align: 'left',
    sortable: true,
  },
  { name: 'invoice_no', label: 'Invoice #', field: 'invoice_no', align: 'left' },
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'balance', label: 'Balance', field: 'balance', align: 'right', sortable: true },
  { name: 'actions', label: '', field: 'actions', align: 'right' },
]

function formatDate(d) {
  if (!d) return '-'
  return date.formatDate(d, 'DD MMM YYYY')
}

function isOverdue(d) {
  if (!d) return false
  return new Date(d) < new Date().setHours(0, 0, 0, 0)
}
</script>

<style lang="scss">
.dashboard-table {
  .q-table__middle {
    max-height: 400px;
  }
  thead tr th {
    position: sticky;
    top: 0;
    z-index: 1;
    background: v-bind("$q.dark.isActive ? '#1d1d1d' : '#fff'");
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 0.5px;
    color: #888;
  }
}
</style>

<template>
  <div>
    <DataTable
      title="Recent Payments"
      :rows="reportStore.paymentSummary"
      :columns="columns"
      :filter="filter"
      :loading="reportStore.loading"
    >
      <template #top-right>
        <q-btn
          color="primary"
          icon="refresh"
          label="Reload"
          class="q-mr-sm"
          @click="fetchData"
          flat
        />
        <q-input
          dense
          outlined
          v-model="filter"
          placeholder="Search collections..."
          :dark="$q.dark.isActive"
        >
          <template v-slot:append>
            <q-icon name="search" />
          </template>
        </q-input>
      </template>

      <template #body-cell-method="props">
        <q-td :props="props">
          <q-chip dense color="primary" text-color="white" icon="payments">
            {{ props.value }}
          </q-chip>
        </q-td>
      </template>

      <template #body-cell-total="props">
        <q-td :props="props" class="text-weight-bold">
          LKR {{ Number(props.value).toLocaleString() }}
        </q-td>
      </template>
    </DataTable>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import DataTable from 'components/common/DataTable.vue'
import { useReportStore } from 'src/stores/reportStore'
import { date } from 'quasar'

const reportStore = useReportStore()
const filter = ref('')

const columns = [
  {
    name: 'method',
    label: 'Payment Method',
    align: 'left',
    field: 'payment_method',
    sortable: true,
  },
  {
    name: 'total',
    label: 'Total Received',
    align: 'right',
    field: 'total_received',
    sortable: true,
  },
]

async function fetchData() {
  const from = date.formatDate(date.subtractFromDate(new Date(), { months: 1 }), 'YYYY-MM-DD')
  const to = date.formatDate(new Date(), 'YYYY-MM-DD')
  await reportStore.fetchPaymentSummary(from, to)
}

onMounted(fetchData)
</script>

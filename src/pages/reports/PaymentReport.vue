<template>
  <q-page class="q-pa-md">
    <PageHeader
      title="Payment Collection Report"
      subtitle="Breakdown of cashflow by payment method"
    >
      <template #actions>
        <ExportButton
          :data="reportStore.paymentSummary"
          :date-from="filter.from"
          :date-to="filter.to"
          :filters="{}"
          :excel-options="[{ key: 'payment_summary', label: 'Payment Collection' }]"
          :pdf-options="[{ key: 'payment_summary', label: 'Payment Collection' }]"
        />
      </template>
    </PageHeader>

    <div class="row q-col-gutter-md q-mt-md">
      <div class="col-12 col-md-4">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-h6">Filter Period</div>
            <q-input
              v-model="filter.from"
              type="date"
              label="From"
              dense
              outlined
              class="q-mt-md"
            />
            <q-input v-model="filter.to" type="date" label="To" dense outlined class="q-mt-sm" />
            <q-btn
              color="primary"
              label="Update Report"
              @click="fetchData"
              class="full-width q-mt-md"
              :loading="reportStore.loading"
            />
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-md-8">
        <q-card flat bordered>
          <q-table
            title="Collections by Method"
            :rows="reportStore.paymentSummary"
            :columns="columns"
            :loading="reportStore.loading"
            flat
          >
            <template v-slot:body-cell-total="props">
              <q-td :props="props" class="text-weight-bold">
                LKR {{ props.value.toLocaleString() }}
              </q-td>
            </template>
          </q-table>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { reactive, onMounted } from 'vue'
import PageHeader from 'components/common/PageHeader.vue'
import ExportButton from 'components/common/ExportButton.vue'
import { useReportStore } from 'src/stores/reportStore'
import { date } from 'quasar'

const reportStore = useReportStore()
const filter = reactive({
  from: date.formatDate(date.startOfDate(new Date(), 'month'), 'YYYY-MM-DD'),
  to: date.formatDate(new Date(), 'YYYY-MM-DD'),
})

const columns = [
  {
    name: 'method',
    label: 'Payment Method',
    field: 'payment_method',
    align: 'left',
    sortable: true,
  },
  {
    name: 'total',
    label: 'Total Received',
    field: 'total_received',
    align: 'right',
    sortable: true,
  },
]

let cleanup = null

async function fetchData() {
  await reportStore.fetchPaymentSummary(filter.from, filter.to)

  if (cleanup) cleanup()
  cleanup = reportStore.setupRealtime('payment', filter.from, filter.to)
}

onMounted(fetchData)

import { onUnmounted } from 'vue'
onUnmounted(() => {
  if (cleanup) cleanup()
})
</script>

<template>
  <q-page class="q-pa-md">
    <PageHeader
      title="Detailed Sales Report"
      subtitle="Track sales by payment status (Paid, Unpaid, Outstanding)"
    >
      <template #actions>
        <ExportButton
          :data="reportStore.invoiceList"
          :date-from="filter.from"
          :date-to="filter.to"
          :filters="{ status: filter.status, payment_status: filter.paymentStatus }"
          :excel-options="[{ key: 'invoice_list', label: 'Invoice Registry' }]"
          :pdf-options="[{ key: 'invoice_list', label: 'Invoice Registry' }]"
        />
      </template>
    </PageHeader>

    <q-card flat bordered class="q-mt-md">
      <q-card-section class="row q-col-gutter-sm items-center">
        <div class="col-12 col-sm-3">
          <q-input v-model="filter.from" type="date" label="From" dense outlined />
        </div>
        <div class="col-12 col-sm-3">
          <q-input v-model="filter.to" type="date" label="To" dense outlined />
        </div>
        <div class="col-12 col-sm-2">
          <q-select
            v-model="filter.status"
            :options="['issued', 'draft', 'cancelled']"
            label="Status"
            dense
            outlined
            clearable
          />
        </div>
        <div class="col-12 col-sm-2">
          <q-select
            v-model="filter.paymentStatus"
            :options="[
              { label: 'Full Paid', value: 'paid' },
              { label: 'Unpaid', value: 'unpaid' },
              { label: 'Outstanding', value: 'outstanding' },
              { label: 'Partial Payment', value: 'partial' },
            ]"
            map-options
            emit-value
            label="Payment Status"
            dense
            outlined
            clearable
          />
        </div>
        <div class="col-12 col-sm-2">
          <q-btn
            color="primary"
            icon="search"
            label="Search"
            @click="fetchData"
            class="full-width"
            unelevated
          />
        </div>
      </q-card-section>

      <q-separator />

      <q-table
        :rows="reportStore.invoiceList"
        :columns="columns"
        :loading="reportStore.loading"
        flat
        row-key="id"
        class="invoice-report-table"
      >
        <template v-slot:body-cell-invoice_no="props">
          <q-td :props="props" class="text-weight-bold text-primary">
            {{ props.value }}
          </q-td>
        </template>

        <template v-slot:body-cell-payment_status="props">
          <q-td :props="props" align="center">
            <q-badge :color="getPaymentStatusColor(props.row)" class="q-pa-xs">
              {{ getPaymentStatusLabel(props.row) }}
            </q-badge>
          </q-td>
        </template>

        <template v-slot:body-cell-status="props">
          <q-td :props="props">
            <q-badge :color="getStatusColor(props.value)" outline>{{
              props.value.toUpperCase()
            }}</q-badge>
          </q-td>
        </template>

        <template v-slot:body-cell-total="props">
          <q-td :props="props" class="text-weight-bold">
            {{ formatCurrency(props.value) }}
          </q-td>
        </template>

        <template v-slot:body-cell-paid="props">
          <q-td :props="props" class="text-green text-weight-medium">
            {{ formatCurrency(props.value || 0) }}
          </q-td>
        </template>

        <template v-slot:body-cell-balance="props">
          <q-td :props="props" :class="props.value > 0 ? 'text-red text-weight-bold' : 'text-grey'">
            {{ formatCurrency(props.value || 0) }}
          </q-td>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup>
import { reactive, onMounted, onUnmounted } from 'vue'
import PageHeader from 'components/common/PageHeader.vue'
import ExportButton from 'components/common/ExportButton.vue'
import { useReportStore } from 'src/stores/reportStore'
import { date } from 'quasar'

const reportStore = useReportStore()
const filter = reactive({
  from: date.formatDate(date.startOfDate(new Date(), 'month'), 'YYYY-MM-DD'),
  to: date.formatDate(new Date(), 'YYYY-MM-DD'),
  status: null,
  paymentStatus: null,
})

const columns = [
  { name: 'invoice_no', label: 'Invoice #', field: 'invoice_no', align: 'left', sortable: true },
  { name: 'invoice_date', label: 'Date', field: 'invoice_date', align: 'left', sortable: true },
  { name: 'customer', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'total', label: 'Grand Total', field: 'total', align: 'right', sortable: true },
  { name: 'paid', label: 'Paid', field: 'paid_amount', align: 'right' },
  { name: 'balance', label: 'Balance', field: 'balance', align: 'right' },
  { name: 'payment_status', label: 'Payment Status', field: (row) => row, align: 'center' },
  { name: 'status', label: 'Inv Status', field: 'status', align: 'center' },
]

function formatCurrency(val) {
  return 'LKR ' + (Number(val) || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}

function getStatusColor(status) {
  if (status === 'issued') return 'indigo'
  if (status === 'cancelled') return 'red'
  return 'grey'
}

function getPaymentStatusLabel(row) {
  if (row.balance <= 0) return 'FULL PAID'
  if (row.paid_amount > 0) return 'PARTIAL'
  return 'UNPAID'
}

function getPaymentStatusColor(row) {
  if (row.balance <= 0) return 'green'
  if (row.paid_amount > 0) return 'orange'
  return 'red-6'
}

let cleanup = null

async function fetchData() {
  await reportStore.fetchInvoiceList(filter.from, filter.to, filter.status, filter.paymentStatus)

  if (cleanup) cleanup()
  cleanup = reportStore.setupRealtime('invoice', filter.from, filter.to, {
    status: filter.status,
    paymentStatus: filter.paymentStatus,
  })
}

onMounted(fetchData)

onUnmounted(() => {
  if (cleanup) cleanup()
})
</script>

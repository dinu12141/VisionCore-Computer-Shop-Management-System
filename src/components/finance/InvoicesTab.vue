<template>
  <div>
    <DataTable
      title="Invoice Registry"
      :rows="reportStore.invoiceList"
      :columns="columns"
      :filter="filter"
      :loading="reportStore.loading || loadingInvoice"
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
          placeholder="Search items..."
          :dark="$q.dark.isActive"
        >
          <template v-slot:append>
            <q-icon name="search" />
          </template>
        </q-input>
      </template>

      <template #body-cell-status="props">
        <q-td :props="props">
          <q-badge
            :color="
              props.value === 'issued' ? 'green' : props.value === 'cancelled' ? 'red' : 'grey'
            "
          >
            {{ props.value }}
          </q-badge>
        </q-td>
      </template>

      <template #body-cell-total="props">
        <q-td :props="props" class="text-weight-bold">
          LKR {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
        </q-td>
      </template>

      <template #body-cell-paid="props">
        <q-td :props="props">
          LKR {{ Number(props.value).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
        </q-td>
      </template>

      <template #body-cell-actions="props">
        <q-td :props="props" class="q-gutter-xs">
          <q-btn
            flat
            round
            dense
            icon="visibility"
            color="primary"
            size="sm"
            @click="viewInvoice(props.row)"
          >
            <q-tooltip>View Invoice</q-tooltip>
          </q-btn>
          <q-btn
            flat
            round
            dense
            icon="print"
            color="secondary"
            size="sm"
            @click="printInvoice(props.row)"
          >
            <q-tooltip>Print Invoice</q-tooltip>
          </q-btn>
        </q-td>
      </template>
    </DataTable>

    <!-- Invoice Print/Preview Dialog -->
    <InvoicePrint
      v-if="showPrintDialog"
      v-model="showPrintDialog"
      :invoice="selectedInvoice"
      :auto-print="shouldAutoPrint"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useQuasar, date } from 'quasar'
import DataTable from 'components/common/DataTable.vue'
import InvoicePrint from 'src/components/billing/InvoicePrint.vue'
import { useReportStore } from 'src/stores/reportStore'
import { useInvoiceStore } from 'src/stores/invoiceStore'

const $q = useQuasar()
const reportStore = useReportStore()
const invoiceStore = useInvoiceStore()

const filter = ref('')
const loadingInvoice = ref(false)
const showPrintDialog = ref(false)
const selectedInvoice = ref(null)
const shouldAutoPrint = ref(false)

const columns = [
  { name: 'invoice_no', label: 'Invoice #', align: 'left', field: 'invoice_no', sortable: true },
  { name: 'date', label: 'Date', align: 'left', field: 'invoice_date', sortable: true },
  { name: 'customer', label: 'Customer', align: 'left', field: 'customer_name' },
  { name: 'total', label: 'Total', align: 'right', field: 'total', sortable: true },
  { name: 'paid', label: 'Paid', align: 'right', field: 'paid_amount' },
  { name: 'status', label: 'Status', align: 'center', field: 'status', sortable: true },
  { name: 'actions', label: 'Actions', align: 'right', field: 'actions' },
]

async function fetchData() {
  const from = date.formatDate(date.subtractFromDate(new Date(), { months: 1 }), 'YYYY-MM-DD')
  const to = date.formatDate(new Date(), 'YYYY-MM-DD')
  await reportStore.fetchInvoiceList(from, to)
}

async function viewInvoice(row) {
  loadingInvoice.value = true
  try {
    selectedInvoice.value = await invoiceStore.getInvoice(row.id)
    shouldAutoPrint.value = false
    showPrintDialog.value = true
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to load invoice: ' + err.message })
  } finally {
    loadingInvoice.value = false
  }
}

async function printInvoice(row) {
  loadingInvoice.value = true
  try {
    selectedInvoice.value = await invoiceStore.getInvoice(row.id)
    shouldAutoPrint.value = true
    showPrintDialog.value = true
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to load invoice: ' + err.message })
  } finally {
    loadingInvoice.value = false
  }
}

onMounted(fetchData)
</script>

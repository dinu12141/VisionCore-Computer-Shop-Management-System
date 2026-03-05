<template>
  <q-page class="q-pa-md" :class="$q.dark.isActive ? 'bg-dark' : 'bg-grey-1'">
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bold q-my-none text-primary">Invoice History</h1>
        <p class="text-grey-7 q-mb-none">View and search past invoices</p>
      </div>
      <div class="col-auto">
        <q-btn color="primary" icon="add" label="New Invoice" rounded unelevated to="/billing" />
      </div>
    </div>

    <!-- Stats Summary -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stats-card" flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-7">Today's Invoices</div>
            <div class="text-h5 text-weight-bold">{{ todayStats.count }}</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stats-card" flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-7">Today's Sales</div>
            <div class="text-h5 text-weight-bold text-primary">
              {{ formatCurrency(todayStats.total) }}
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Filters -->
    <q-card class="q-mb-lg no-border shadow-2 border-radius-lg">
      <q-card-section class="q-pa-md">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-input
              v-model="filters.search"
              placeholder="Customer name or phone..."
              outlined
              dense
              :bg-color="$q.dark.isActive ? undefined : 'white'"
              @update:model-value="debouncedFetch"
            >
              <template v-slot:prepend>
                <q-icon name="search" color="primary" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-3">
            <q-input
              v-model="filters.invoice_no"
              placeholder="Invoice No. (e.g. INV-2026-000001)"
              outlined
              dense
              :bg-color="$q.dark.isActive ? undefined : 'white'"
              @update:model-value="debouncedFetch"
            />
          </div>
          <div class="col-12 col-sm-3">
            <q-input
              v-model="filters.dateFrom"
              type="date"
              label="From Date"
              outlined
              dense
              stack-label
              @update:model-value="fetchInvoices"
            />
          </div>
          <div class="col-12 col-sm-2">
            <q-btn
              flat
              color="grey-7"
              icon="restart_alt"
              label="Reset"
              @click="resetFilters"
              class="full-width"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Invoices Table -->
    <q-table
      :rows="invoices"
      :columns="columns"
      row-key="id"
      flat
      bordered
      :loading="loading"
      :pagination="pagination"
      class="border-radius-lg"
    >
      <template v-slot:body-cell-invoice_no="props">
        <q-td :props="props">
          <div class="row items-center no-wrap">
            <span class="text-weight-bold text-primary text-subtitle1">{{ props.value }}</span>
            <q-badge
              v-if="props.row.is_vat_invoice"
              color="deep-orange"
              text-color="white"
              class="q-ml-sm"
              style="font-size: 9px; padding: 2px 6px"
              >TAX</q-badge
            >
          </div>
          <div class="text-caption text-grey-7">{{ formatDate(props.row.created_at) }}</div>
        </q-td>
      </template>

      <template v-slot:body-cell-customer="props">
        <q-td :props="props">
          <div class="text-weight-medium text-subtitle1">
            {{ props.row.customer_snapshot?.name || 'Walk-in' }}
          </div>
          <div class="text-caption text-grey-7" v-if="props.row.customer_snapshot?.phone">
            {{ props.row.customer_snapshot?.phone }}
          </div>
        </q-td>
      </template>

      <template v-slot:body-cell-total="props">
        <q-td :props="props" align="right">
          <div class="text-weight-bold text-subtitle1">{{ formatCurrency(props.value) }}</div>
          <div
            v-if="props.row.balance > 0"
            class="text-caption text-negative text-weight-bold cursor-pointer"
            @click="goToCollections(props.row)"
          >
            Due: {{ formatCurrency(props.row.balance) }}
          </div>
          <div v-else-if="props.row.payment_status === 'PAID'" class="text-caption text-positive">
            FULL PAID
          </div>
        </q-td>
      </template>

      <template v-slot:body-cell-payment_type="props">
        <q-td :props="props" align="center">
          <q-chip
            :color="getStatusColor(props.row.payment_status)"
            text-color="white"
            size="sm"
            class="text-weight-bold text-uppercase"
          >
            {{ props.row.payment_status || props.value }}
          </q-chip>
        </q-td>
      </template>

      <template v-slot:body-cell-actions="props">
        <q-td :props="props" align="center" class="q-gutter-xs">
          <q-btn flat round dense icon="visibility" color="primary" @click="viewInvoice(props.row)">
            <q-tooltip>View Invoice</q-tooltip>
          </q-btn>
          <q-btn
            flat
            round
            dense
            icon="edit"
            color="blue"
            @click="$router.push(`/billing?editId=${props.row.id}`)"
          >
            <q-tooltip>Edit Invoice</q-tooltip>
          </q-btn>
          <q-btn flat round dense icon="print" color="secondary" @click="printInvoice(props.row)">
            <q-tooltip>Print Invoice</q-tooltip>
          </q-btn>
          <q-btn
            flat
            round
            dense
            icon="download"
            color="deep-orange"
            @click.stop="downloadInvoice(props.row)"
            :loading="downloadingId === props.row.id"
          >
            <q-tooltip>Download PDF</q-tooltip>
          </q-btn>
          <q-btn
            flat
            round
            dense
            icon="delete"
            color="negative"
            @click="confirmDeleteInvoice(props.row)"
          >
            <q-tooltip>Delete Invoice</q-tooltip>
          </q-btn>
          <q-btn
            v-if="props.row.balance > 0"
            flat
            round
            dense
            icon="payments"
            color="green"
            @click="$router.push(`/collections/outstanding?search=${props.row.invoice_no}`)"
          >
            <q-tooltip>Manage Payments</q-tooltip>
          </q-btn>
        </q-td>
      </template>

      <template v-slot:no-data>
        <div class="full-width column flex-center q-pa-xl">
          <q-icon name="receipt_long" size="64px" color="grey-4" />
          <div class="text-h6 text-grey-5 q-mt-md">No invoices found</div>
          <q-btn
            flat
            color="primary"
            label="Try changing filters or search"
            @click="resetFilters"
            v-if="hasFilters"
          />
        </div>
      </template>
    </q-table>

    <!-- Unified Invoice Print Dialog -->
    <InvoicePrint
      v-if="showPrintDialog"
      v-model="showPrintDialog"
      :invoice="selectedInvoice"
      :auto-print="shouldAutoPrint"
    />
  </q-page>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useInvoiceStore } from 'src/stores/invoiceStore'
import { debounce } from 'quasar'
import { renderInvoiceHTML } from 'src/utils/renderInvoiceHTML'
import { downloadInvoicePDF } from 'src/utils/downloadInvoicePDF'
import InvoicePrint from 'src/components/billing/InvoicePrint.vue'

const $q = useQuasar()
const router = useRouter()
const invoiceStore = useInvoiceStore()
const invoices = ref([])
const loading = ref(false)
const downloadingId = ref(null)

// Dialog states
const showPrintDialog = ref(false)
const selectedInvoice = ref(null)
const shouldAutoPrint = ref(false)

const filters = reactive({
  search: '',
  invoice_no: '',
  dateFrom: '',
  dateTo: '',
})

const pagination = ref({
  rowsPerPage: 20,
})

const columns = [
  { name: 'invoice_no', label: 'Invoice Info', align: 'left', field: 'invoice_no', sortable: true },
  {
    name: 'customer',
    label: 'Customer',
    align: 'left',
    field: 'customer_snapshot',
    sortable: false,
  },
  { name: 'payment_type', label: 'Type', align: 'center', field: 'payment_type', sortable: true },
  { name: 'total', label: 'Total Amount', align: 'right', field: 'total', sortable: true },
  { name: 'actions', label: 'Actions', align: 'center', field: 'id', sortable: false },
]

const todayStats = computed(() => {
  const today = new Date().toISOString().split('T')[0]
  const todayInvoices = invoices.value.filter((inv) => inv.invoice_date === today)
  return {
    count: todayInvoices.length,
    total: todayInvoices.reduce((sum, inv) => sum + Number(inv.total), 0),
  }
})

const hasFilters = computed(() => {
  return filters.search || filters.invoice_no || filters.dateFrom
})

async function fetchInvoices() {
  loading.value = true
  try {
    invoices.value = await invoiceStore.fetchInvoices(filters)
  } finally {
    loading.value = false
  }
}

const debouncedFetch = debounce(fetchInvoices, 500)

function resetFilters() {
  filters.search = ''
  filters.invoice_no = ''
  filters.dateFrom = ''
  fetchInvoices()
}

function getStatusColor(status) {
  const colors = {
    PAID: 'green',
    PARTIAL: 'orange',
    UNPAID: 'red',
    CANCELLED: 'grey-7',
  }
  return colors[status] || 'grey'
}

function formatDate(date) {
  if (!date) return ''
  return new Date(date).toLocaleString('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  })
}

function formatCurrency(val) {
  return (
    'LKR ' +
    Number(val || 0).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  )
}

function goToCollections(invoice) {
  router.push(`/collections/outstanding?search=${invoice.invoice_no}`)
}

async function viewInvoice(invoice) {
  loading.value = true
  try {
    const fullInvoice = await invoiceStore.getInvoice(invoice.id)
    selectedInvoice.value = fullInvoice
    shouldAutoPrint.value = false
    showPrintDialog.value = true
  } finally {
    loading.value = false
  }
}

async function printInvoice(invoice) {
  loading.value = true
  try {
    const fullInvoice = await invoiceStore.getInvoice(invoice.id)
    selectedInvoice.value = fullInvoice
    shouldAutoPrint.value = true
    showPrintDialog.value = true
  } finally {
    loading.value = false
  }
}

async function downloadInvoice(invoice) {
  downloadingId.value = invoice.id
  try {
    const fullInvoice = await invoiceStore.getInvoice(invoice.id)
    const html = renderInvoiceHTML({
      ...fullInvoice,
      is_vat_invoice: !!fullInvoice.is_vat_invoice,
    })
    await downloadInvoicePDF(html, fullInvoice.invoice_no || 'Invoice')
    $q.notify({
      type: 'positive',
      icon: 'download',
      message: `${fullInvoice.invoice_no}.pdf downloaded!`,
    })
  } catch (err) {
    $q.notify({ type: 'negative', message: 'PDF download failed: ' + err.message })
  } finally {
    downloadingId.value = null
  }
}

function confirmDeleteInvoice(invoice) {
  $q.dialog({
    title: 'Delete Invoice',
    message: `Are you sure you want to delete invoice <b>${invoice.invoice_no}</b>? This action cannot be undone and may affect inventory/financial records.`,
    html: true,
    cancel: true,
    persistent: true,
    ok: { label: 'Delete', color: 'negative', flat: true },
  }).onOk(async () => {
    loading.value = true
    try {
      await invoiceStore.deleteInvoice(invoice.id)
      $q.notify({ type: 'positive', message: 'Invoice deleted successfully' })
      fetchInvoices()
    } catch (err) {
      $q.notify({ type: 'negative', message: 'Failed to delete invoice: ' + err.message })
    } finally {
      loading.value = false
    }
  })
}

onMounted(async () => {
  const queryInvoiceNo = router.currentRoute.value.query.invoice_no
  if (queryInvoiceNo) {
    filters.invoice_no = queryInvoiceNo
    await fetchInvoices()

    // Auto-open the dialog if exactly one invoice found
    if (invoices.value.length === 1) {
      viewInvoice(invoices.value[0])
    }
  } else {
    fetchInvoices()
  }
})
</script>

<style scoped>
.stats-card {
  border-radius: 12px;
  transition: transform 0.2s;
}
.stats-card:hover {
  transform: translateY(-4px);
}
.border-radius-lg {
  border-radius: 16px;
}
</style>

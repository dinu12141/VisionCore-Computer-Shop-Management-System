<template>
  <q-page class="q-pa-md" :class="$q.dark.isActive ? 'bg-dark' : 'bg-grey-1'">
    <!-- Page Header -->
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bolder q-ma-none" style="color: #1a1a2e">
          <q-icon name="receipt_long" class="q-mr-sm" style="color: #6c63ff" />
          All Invoices
        </h1>
        <div class="text-grey-6 q-mt-xs">View, print and download every invoice in the system</div>
      </div>
      <div class="col-auto q-gutter-sm">
        <q-btn unelevated color="primary" icon="add" label="New Invoice" rounded to="/billing" />
        <q-btn
          v-if="invoices.length > 0"
          flat
          color="grey-7"
          icon="download"
          label="Export CSV"
          rounded
          @click="exportCSV"
        />
      </div>
    </div>

    <!-- Stats Row -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-6 col-sm-3">
        <q-card class="stat-card" flat>
          <q-card-section class="q-pa-md">
            <div class="row items-center no-wrap">
              <q-icon name="receipt" size="32px" color="primary" class="q-mr-sm" />
              <div>
                <div class="text-caption text-grey-6">Total Invoices</div>
                <div class="text-h6 text-weight-bold">{{ invoices.length }}</div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-sm-3">
        <q-card class="stat-card" flat>
          <q-card-section class="q-pa-md">
            <div class="row items-center no-wrap">
              <q-icon name="payments" size="32px" color="positive" class="q-mr-sm" />
              <div>
                <div class="text-caption text-grey-6">Total Revenue</div>
                <div class="text-h6 text-weight-bold text-positive">
                  {{ formatCurrency(totalRevenue) }}
                </div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-sm-3">
        <q-card class="stat-card" flat>
          <q-card-section class="q-pa-md">
            <div class="row items-center no-wrap">
              <q-icon name="warning_amber" size="32px" color="negative" class="q-mr-sm" />
              <div>
                <div class="text-caption text-grey-6">Total Outstanding</div>
                <div class="text-h6 text-weight-bold text-negative">
                  {{ formatCurrency(totalOutstanding) }}
                </div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-sm-3">
        <q-card class="stat-card" flat>
          <q-card-section class="q-pa-md">
            <div class="row items-center no-wrap">
              <q-icon name="receipt_long" size="32px" color="deep-orange" class="q-mr-sm" />
              <div>
                <div class="text-caption text-grey-6">Tax Invoices</div>
                <div class="text-h6 text-weight-bold text-deep-orange">{{ taxInvoiceCount }}</div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Filters -->
    <q-card flat class="q-mb-md filter-card">
      <q-card-section class="q-pa-md">
        <div class="row q-col-gutter-sm items-center">
          <div class="col-12 col-sm-4">
            <q-input
              v-model="filters.search"
              placeholder="Search by customer, phone..."
              outlined
              dense
              clearable
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
              placeholder="Invoice No. (e.g. INV-2026-001)"
              outlined
              dense
              clearable
              :bg-color="$q.dark.isActive ? undefined : 'white'"
              @update:model-value="debouncedFetch"
            />
          </div>
          <div class="col-6 col-sm-2">
            <q-input
              v-model="filters.dateFrom"
              type="date"
              label="From"
              outlined
              dense
              stack-label
              @update:model-value="fetchInvoices"
            />
          </div>
          <div class="col-6 col-sm-2">
            <q-input
              v-model="filters.dateTo"
              type="date"
              label="To"
              outlined
              dense
              stack-label
              @update:model-value="fetchInvoices"
            />
          </div>
          <div class="col-12 col-sm-1">
            <q-btn flat color="grey-7" icon="restart_alt" @click="resetFilters" class="full-width">
              <q-tooltip>Reset Filters</q-tooltip>
            </q-btn>
          </div>
        </div>

        <!-- Type filter chips -->
        <div class="row q-mt-sm q-gutter-xs">
          <q-chip
            v-for="chip in typeChips"
            :key="chip.value"
            :outline="filters.type !== chip.value"
            :color="filters.type === chip.value ? 'primary' : 'grey-5'"
            :text-color="filters.type === chip.value ? 'white' : 'grey-7'"
            clickable
            dense
            @click="setTypeFilter(chip.value)"
          >
            {{ chip.label }}
          </q-chip>
        </div>
      </q-card-section>
    </q-card>

    <!-- Invoices Table -->
    <q-table
      :rows="filteredInvoices"
      :columns="columns"
      row-key="id"
      flat
      bordered
      :loading="loading"
      :pagination="pagination"
      class="invoice-table"
      :rows-per-page-options="[20, 50, 100]"
    >
      <template v-slot:body-cell-invoice_no="props">
        <q-td :props="props">
          <div class="row items-center no-wrap">
            <span class="text-weight-bold text-primary">{{ props.value }}</span>
            <q-badge
              v-if="props.row.is_vat_invoice"
              color="deep-orange"
              text-color="white"
              class="q-ml-xs"
              style="font-size: 9px"
              >TAX</q-badge
            >
          </div>
          <div class="text-caption text-grey-6">{{ formatDate(props.row.created_at) }}</div>
        </q-td>
      </template>

      <template v-slot:body-cell-customer="props">
        <q-td :props="props">
          <div class="text-weight-medium">
            {{ props.row.customer_snapshot?.name || 'Walk-in' }}
          </div>
          <div class="text-caption text-grey-6">
            {{ props.row.customer_snapshot?.phone || '' }}
          </div>
        </q-td>
      </template>

      <template v-slot:body-cell-status="props">
        <q-td :props="props" align="center">
          <q-chip
            :color="getStatusColor(props.row.payment_status)"
            text-color="white"
            size="sm"
            dense
            class="text-weight-bold text-uppercase"
          >
            {{ props.row.payment_status || 'ISSUED' }}
          </q-chip>
        </q-td>
      </template>

      <template v-slot:body-cell-total="props">
        <q-td :props="props" align="right">
          <div class="text-weight-bold">{{ formatCurrency(props.value) }}</div>
          <div v-if="props.row.balance > 0" class="text-caption text-negative text-weight-bold">
            Due: {{ formatCurrency(props.row.balance) }}
          </div>
          <div v-else class="text-caption text-positive">PAID</div>
        </q-td>
      </template>

      <template v-slot:body-cell-actions="props">
        <q-td :props="props" align="center">
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
          <q-btn
            flat
            round
            dense
            icon="download"
            color="teal"
            size="sm"
            @click="downloadInvoice(props.row)"
          >
            <q-tooltip>Download as PDF</q-tooltip>
          </q-btn>
          <q-btn
            v-if="props.row.balance > 0"
            flat
            round
            dense
            icon="payments"
            color="green"
            size="sm"
            @click="$router.push(`/collections/outstanding?search=${props.row.invoice_no}`)"
          >
            <q-tooltip>Manage Payment</q-tooltip>
          </q-btn>
        </q-td>
      </template>

      <template v-slot:no-data>
        <div class="full-width column flex-center q-pa-xl">
          <q-icon name="receipt_long" size="64px" color="grey-4" />
          <div class="text-h6 text-grey-5 q-mt-md">No invoices found</div>
          <q-btn
            v-if="hasFilters"
            flat
            color="primary"
            label="Reset Filters"
            @click="resetFilters"
          />
        </div>
      </template>
    </q-table>

    <!-- Invoice Print/View Dialog -->
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
import { useQuasar, debounce } from 'quasar'
import { useInvoiceStore } from 'src/stores/invoiceStore'
import { renderInvoiceHTML } from 'src/utils/renderInvoiceHTML'
import { toJpeg } from 'html-to-image'
import { jsPDF } from 'jspdf'
import InvoicePrint from 'src/components/billing/InvoicePrint.vue'

const $q = useQuasar()
const invoiceStore = useInvoiceStore()

const invoices = ref([])
const loading = ref(false)
const showPrintDialog = ref(false)
const selectedInvoice = ref(null)
const shouldAutoPrint = ref(false)

const filters = reactive({
  search: '',
  invoice_no: '',
  dateFrom: '',
  dateTo: '',
  type: 'all', // 'all' | 'tax' | 'normal'
})

const pagination = ref({ rowsPerPage: 20 })

const typeChips = [
  { label: 'All Invoices', value: 'all' },
  { label: 'Tax Invoices', value: 'tax' },
  { label: 'Normal Invoices', value: 'normal' },
]

const columns = [
  { name: 'invoice_no', label: 'Invoice', field: 'invoice_no', align: 'left', sortable: true },
  {
    name: 'customer',
    label: 'Customer',
    field: 'customer_snapshot',
    align: 'left',
    sortable: false,
  },
  { name: 'status', label: 'Status', field: 'payment_status', align: 'center', sortable: true },
  { name: 'total', label: 'Amount', field: 'total', align: 'right', sortable: true },
  { name: 'actions', label: 'Actions', field: 'id', align: 'center', sortable: false },
]

// --- Computed ---
const filteredInvoices = computed(() => {
  if (filters.type === 'tax') return invoices.value.filter((i) => i.is_vat_invoice)
  if (filters.type === 'normal') return invoices.value.filter((i) => !i.is_vat_invoice)
  return invoices.value
})

const totalRevenue = computed(() =>
  invoices.value.reduce((sum, i) => sum + Number(i.total || 0), 0),
)
const totalOutstanding = computed(() =>
  invoices.value.reduce((sum, i) => sum + Number(i.balance || 0), 0),
)
const taxInvoiceCount = computed(() => invoices.value.filter((i) => i.is_vat_invoice).length)
const hasFilters = computed(
  () =>
    filters.search ||
    filters.invoice_no ||
    filters.dateFrom ||
    filters.dateTo ||
    filters.type !== 'all',
)

// --- Data Fetch ---
async function fetchInvoices() {
  loading.value = true
  try {
    invoices.value = await invoiceStore.fetchInvoices(filters)
  } finally {
    loading.value = false
  }
}

const debouncedFetch = debounce(fetchInvoices, 400)

function resetFilters() {
  filters.search = ''
  filters.invoice_no = ''
  filters.dateFrom = ''
  filters.dateTo = ''
  filters.type = 'all'
  fetchInvoices()
}

function setTypeFilter(val) {
  filters.type = val
}

// --- Actions ---
async function viewInvoice(invoice) {
  loading.value = true
  try {
    selectedInvoice.value = await invoiceStore.getInvoice(invoice.id)
    shouldAutoPrint.value = false
    showPrintDialog.value = true
  } finally {
    loading.value = false
  }
}

async function printInvoice(invoice) {
  loading.value = true
  try {
    selectedInvoice.value = await invoiceStore.getInvoice(invoice.id)
    shouldAutoPrint.value = true
    showPrintDialog.value = true
  } finally {
    loading.value = false
  }
}

async function downloadInvoice(invoice) {
  loading.value = true
  const notify = $q.notify({ type: 'ongoing', message: 'Generating PDF...', timeout: 0 })
  let iframe = null
  try {
    const full = await invoiceStore.getInvoice(invoice.id)
    const html = renderInvoiceHTML(full)

    // Use an iframe so the full HTML document (with <style> tags) renders correctly
    iframe = document.createElement('iframe')
    iframe.style.cssText =
      'position:fixed;left:-9999px;top:0;width:794px;height:1123px;border:none;opacity:0;pointer-events:none;'
    document.body.appendChild(iframe)

    // Write the complete invoice HTML into the iframe
    iframe.contentDocument.open()
    iframe.contentDocument.write(html)
    iframe.contentDocument.close()

    // Wait for the iframe to fully render (fonts, layout, images)
    await new Promise((r) => setTimeout(r, 600))

    // Target the invoice body element inside the iframe
    const target = iframe.contentDocument.body
    const contentHeight = target.scrollHeight

    // Resize iframe to the actual content height so nothing is clipped
    iframe.style.height = contentHeight + 'px'
    await new Promise((r) => setTimeout(r, 100))

    // Capture as JPEG (much smaller file than PNG, good enough for documents)
    const imgData = await toJpeg(target, {
      quality: 0.88,
      pixelRatio: 1.5,
      backgroundColor: '#ffffff',
      width: 794,
      height: contentHeight,
    })

    document.body.removeChild(iframe)
    iframe = null

    // Calculate PDF dimensions: A4 width (210mm) × proportional height
    const img = new Image()
    img.src = imgData
    await new Promise((r) => {
      img.onload = r
    })

    const pdfWidth = 210
    const pdfHeight = Math.round((img.height / img.width) * pdfWidth)

    // Single custom-height page — exactly fits the invoice, zero blank space
    const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: [pdfWidth, pdfHeight] })
    pdf.addImage(imgData, 'JPEG', 0, 0, pdfWidth, pdfHeight)
    pdf.save(`${full.invoice_no}.pdf`)

    notify({ type: 'positive', message: `${full.invoice_no}.pdf downloaded!`, timeout: 3000 })
  } catch {
    notify({ type: 'negative', message: 'Failed to generate PDF', timeout: 3000 })
  } finally {
    if (iframe) document.body.removeChild(iframe)
    loading.value = false
  }
}

function exportCSV() {
  const rows = filteredInvoices.value
  const headers = [
    'Invoice No',
    'Date',
    'Customer',
    'Phone',
    'Total (LKR)',
    'Paid (LKR)',
    'Balance (LKR)',
    'Status',
    'Type',
  ]
  const csvRows = rows.map((inv) => [
    inv.invoice_no,
    inv.invoice_date || inv.created_at?.split('T')[0],
    inv.customer_snapshot?.name || 'Walk-in',
    inv.customer_snapshot?.phone || '',
    Number(inv.total || 0).toFixed(2),
    Number(inv.paid_amount || 0).toFixed(2),
    Number(inv.balance || 0).toFixed(2),
    inv.payment_status || 'ISSUED',
    inv.is_vat_invoice ? 'TAX INVOICE' : 'INVOICE',
  ])
  const csvContent = [headers, ...csvRows].map((r) => r.join(',')).join('\n')
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.setAttribute('download', `invoices_${new Date().toISOString().split('T')[0]}.csv`)
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
  $q.notify({ type: 'positive', message: 'CSV exported successfully!' })
}

// --- Formatters ---
function formatCurrency(val) {
  return 'LKR ' + Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}

function formatDate(date) {
  if (!date) return ''
  return new Date(date).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })
}

function getStatusColor(status) {
  const map = { PAID: 'green', PARTIAL: 'orange', UNPAID: 'red', CANCELLED: 'grey-7' }
  return map[status] || 'grey'
}

onMounted(() => fetchInvoices())
</script>

<style scoped>
.stat-card {
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.06);
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}
.stat-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.08);
}
.filter-card {
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.06);
}
.invoice-table {
  border-radius: 16px;
}
</style>

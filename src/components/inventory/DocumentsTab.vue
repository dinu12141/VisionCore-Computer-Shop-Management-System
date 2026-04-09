<template>
  <div class="q-pa-md">
    <!-- Filters + Actions -->
    <div class="row items-center q-mb-md q-gutter-sm">
      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="docTypeFilter"
        :options="docTypeOptions"
        label="Document Type"
        emit-value
        map-options
        style="min-width: 200px"
      />
      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="statusFilter"
        :options="statusOptions"
        label="Status"
        emit-value
        map-options
        style="min-width: 150px"
      />
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="dateFrom"
        type="date"
        label="From"
        style="min-width: 150px"
      />
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="dateTo"
        type="date"
        label="To"
        style="min-width: 150px"
      />
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="search"
        placeholder="Search doc #..."
        style="min-width: 200px"
      >
        <template #prepend><q-icon name="search" /></template>
      </q-input>
      <q-space />
      <q-btn outline color="grey-5" icon="refresh" round dense @click="reload">
        <q-tooltip>Refresh</q-tooltip>
      </q-btn>
      <q-btn color="teal" icon="summarize" label="Summary Report" @click="openSummaryReport">
        <q-tooltip>Generate a Summary Report of all visible documents</q-tooltip>
      </q-btn>
      <q-btn
        v-if="authStore.hasAnyRole(['admin', 'manager', 'inventory'])"
        color="primary"
        icon="add"
        label="New Document"
        @click="$emit('create-document')"
      />
    </div>

    <!-- Documents Table -->
    <q-card
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      flat
      bordered
    >
      <q-card-section>
        <q-table
          :rows="documents"
          :columns="columns"
          row-key="id"
          :dark="$q.dark.isActive"
          flat
          bordered
          dense
          class="bg-transparent"
          :table-header-class="
            $q.dark.isActive ? 'text-grey-5 text-uppercase' : 'text-grey-7 text-uppercase'
          "
          :loading="loading"
          :filter="search"
          :rows-per-page-options="[10, 25, 50]"
          @row-click="(evt, row) => $emit('view-document', row)"
          row-class="cursor-pointer"
        >
          <!-- Doc Type badge -->
          <template #body-cell-doc_type="props">
            <q-td :props="props">
              <q-chip
                dense
                size="sm"
                :color="getDocColor(props.value)"
                text-color="white"
                :icon="getDocIcon(props.value)"
              >
                {{ props.value }}
              </q-chip>
            </q-td>
          </template>

          <!-- Status chip -->
          <template #body-cell-status="props">
            <q-td :props="props">
              <q-chip
                dense
                size="sm"
                :color="getStatusColor(props.value)"
                :text-color="getStatusTextColor(props.value)"
                :icon="getStatusIcon(props.value)"
                class="text-weight-bold text-uppercase"
              >
                {{ props.value }}
              </q-chip>
            </q-td>
          </template>

          <!-- Cost formatting -->
          <template #body-cell-total_cost="props">
            <q-td :props="props">
              <span class="text-weight-bold">{{ formatCurrency(props.value) }}</span>
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props">
              <q-btn
                flat
                dense
                round
                icon="receipt_long"
                size="sm"
                color="teal"
                @click.stop="printDocument(props.row)"
              >
                <q-tooltip>View / Print Report</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'draft' && authStore.hasAnyRole(['admin', 'manager', 'inventory'])"
                flat
                dense
                round
                icon="edit"
                size="sm"
                color="orange"
                @click.stop="$emit('edit-document', props.row)"
              >
                <q-tooltip>Edit draft</q-tooltip>
              </q-btn>
            </q-td>
          </template>

          <!-- No data -->
          <template #no-data>
            <div class="full-width row flex-center text-grey-5 q-pa-lg">
              <q-icon size="2em" name="description" class="q-mr-sm" />
              <span>No documents found matching your filters</span>
            </div>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- Individual Document Report Loading Dialog -->
    <q-dialog v-model="printLoading" persistent>
      <q-card style="min-width: 250px" class="text-center q-pa-lg">
        <q-spinner color="primary" size="40px" />
        <div class="q-mt-md">Generating Report...</div>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useDocumentList, fetchDocumentById } from 'src/services/inventoryService'
import { useAuthStore } from 'src/stores/auth'

const $q = useQuasar()
const authStore = useAuthStore()

defineEmits(['create-document', 'view-document', 'edit-document'])

const { documents, loading, listDocuments } = useDocumentList()

const search = ref('')
const docTypeFilter = ref('')
const statusFilter = ref('')
const dateFrom = ref('')
const dateTo = ref('')
const printLoading = ref(false)

const docTypeOptions = [
  { label: 'All Types', value: '' },
  { label: 'PO', value: 'PO' },
  { label: 'GRN', value: 'GRN' },
  { label: 'GIN', value: 'GIN' },
  { label: 'Transfer', value: 'TRANSFER' },
  { label: 'Adjustment', value: 'ADJUSTMENT' },
  { label: 'Stock Count', value: 'STOCK_COUNT' },
]

const statusOptions = [
  { label: 'All Statuses', value: '' },
  { label: 'Draft', value: 'draft' },
  { label: 'Posted', value: 'posted' },
  { label: 'Cancelled', value: 'cancelled' },
]

function buildFilters() {
  return {
    docType: docTypeFilter.value || undefined,
    status: statusFilter.value || undefined,
    dateFrom: dateFrom.value || undefined,
    dateTo: dateTo.value || undefined,
    search: search.value || undefined,
  }
}

async function reload() {
  await listDocuments(buildFilters())
}

onMounted(() => reload())
watch([docTypeFilter, statusFilter, dateFrom, dateTo], () => reload())

/* ─────────────────────────────────────────────
   Columns
───────────────────────────────────────────── */
const columns = [
  {
    name: 'doc_type',
    label: 'Type',
    field: 'doc_type',
    align: 'left',
    sortable: true,
    style: 'width: 120px',
  },
  { name: 'doc_number', label: 'Doc #', field: 'doc_number', align: 'left', sortable: true },
  { name: 'doc_date', label: 'Date', field: 'doc_date', align: 'center', sortable: true },
  { name: 'warehouse_name', label: 'Warehouse', field: 'warehouse_name', align: 'left' },
  {
    name: 'supplier_or_target',
    label: 'Supplier / Target',
    align: 'left',
    field: (row) => row.supplier_name || row.target_warehouse_name || '-',
  },
  { name: 'total_qty', label: 'Qty', field: 'total_qty', align: 'right', sortable: true },
  { name: 'total_cost', label: 'Total Cost', field: 'total_cost', align: 'right', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
  { name: 'created_by_name', label: 'Created By', field: 'created_by_name', align: 'left' },
  { name: 'actions', label: '', field: 'actions', align: 'center', style: 'width: 100px' },
]

/* ─────────────────────────────────────────────
   Color / Icon helpers
───────────────────────────────────────────── */
function getDocColor(type) {
  const map = {
    PO: 'indigo-9',
    GRN: 'green-9',
    GIN: 'red-9',
    TRANSFER: 'blue-9',
    ADJUSTMENT: 'orange-9',
    STOCK_COUNT: 'purple-9',
    BOM_DEDUCT: 'cyan-9',
  }
  return map[type] || 'grey-8'
}
function getDocIcon(type) {
  const map = {
    PO: 'shopping_cart',
    GRN: 'archive',
    GIN: 'unarchive',
    TRANSFER: 'swap_horiz',
    ADJUSTMENT: 'tune',
    STOCK_COUNT: 'fact_check',
    BOM_DEDUCT: 'restaurant',
  }
  return map[type] || 'description'
}
function getStatusColor(s) {
  return { draft: 'grey-8', posted: 'green-9', cancelled: 'red-9' }[s] || 'grey-8'
}
function getStatusTextColor(s) {
  return { draft: 'grey-3', posted: 'green-1', cancelled: 'red-1' }[s] || 'grey-3'
}
function getStatusIcon(s) {
  return { draft: 'edit_note', posted: 'verified', cancelled: 'cancel' }[s] || 'info'
}
function formatCurrency(val) {
  return 'LKR ' + Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}

/* ─────────────────────────────────────────────
   INDIVIDUAL DOCUMENT REPORT
───────────────────────────────────────────── */
async function printDocument(row) {
  printLoading.value = true
  try {
    const { header, lines } = await fetchDocumentById(row.id)
    const html = buildDocumentReportHTML(header, lines)
    openPrintWindow(html, `${row.doc_type}_${row.doc_number}`, true)
  } catch (e) {
    $q.notify({ type: 'negative', message: 'Failed to load document: ' + e.message })
  } finally {
    printLoading.value = false
  }
}

/* ─────────────────────────────────────────────
   SUMMARY REPORT (all visible documents)
───────────────────────────────────────────── */
function openSummaryReport() {
  if (!documents.value.length) {
    $q.notify({ type: 'warning', message: 'No documents to report. Adjust filters first.' })
    return
  }

  const now = new Date().toLocaleString()
  const filters = buildFilters()

  // Stats
  const totalDocs = documents.value.length
  const totalCost = documents.value.reduce((s, d) => s + Number(d.total_cost || 0), 0)
  const totalQty = documents.value.reduce((s, d) => s + Number(d.total_qty || 0), 0)
  const byType = {}
  const byStatus = {}
  documents.value.forEach((d) => {
    byType[d.doc_type] = (byType[d.doc_type] || 0) + 1
    byStatus[d.status] = (byStatus[d.status] || 0) + 1
  })

  /* Stats cards row */
  const statsHTML = `
    <div class="stats-row">
      <div class="stat-box"><div class="stat-val">${totalDocs}</div><div class="stat-lbl">Total Documents</div></div>
      <div class="stat-box"><div class="stat-val">${totalQty.toLocaleString()}</div><div class="stat-lbl">Total Quantity</div></div>
      <div class="stat-box"><div class="stat-val">LKR ${totalCost.toLocaleString(undefined, { minimumFractionDigits: 2 })}</div><div class="stat-lbl">Total Cost</div></div>
    </div>`

  /* Breakdown tables */
  const byTypeRows = Object.entries(byType)
    .map(([k, v]) => `<tr><td>${k}</td><td style="text-align:right">${v}</td></tr>`)
    .join('')
  const byStatusRows = Object.entries(byStatus)
    .map(([k, v]) => `<tr><td>${k.toUpperCase()}</td><td style="text-align:right">${v}</td></tr>`)
    .join('')

  const breakdownHTML = `
    <div class="breakdown-grid">
      <div>
        <div class="section-title">By Document Type</div>
        <table><thead><tr><th>Type</th><th>Count</th></tr></thead><tbody>${byTypeRows}</tbody></table>
      </div>
      <div>
        <div class="section-title">By Status</div>
        <table><thead><tr><th>Status</th><th>Count</th></tr></thead><tbody>${byStatusRows}</tbody></table>
      </div>
    </div>`

  /* Documents detail table */
  const docRows = documents.value
    .map(
      (d) => `
    <tr>
      <td><span class="badge badge-${d.doc_type.toLowerCase()}">${d.doc_type}</span></td>
      <td>${d.doc_number || '-'}</td>
      <td>${d.doc_date || '-'}</td>
      <td>${d.warehouse_name || '-'}</td>
      <td>${d.supplier_name || d.target_warehouse_name || '-'}</td>
      <td style="text-align:right">${Number(d.total_qty || 0).toLocaleString()}</td>
      <td style="text-align:right">LKR ${Number(d.total_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}</td>
      <td><span class="status-badge status-${d.status}">${d.status.toUpperCase()}</span></td>
      <td>${d.created_by_name || '-'}</td>
    </tr>`,
    )
    .join('')

  const filterDesc =
    [
      filters.docType ? `Type: ${filters.docType}` : null,
      filters.status ? `Status: ${filters.status}` : null,
      filters.dateFrom ? `From: ${filters.dateFrom}` : null,
      filters.dateTo ? `To: ${filters.dateTo}` : null,
      filters.search ? `Search: "${filters.search}"` : null,
    ]
      .filter(Boolean)
      .join(' | ') || 'All Documents'

  const html = `
<!DOCTYPE html><html><head><title>Inventory Summary Report</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:'Segoe UI',sans-serif; padding:32px; color:#1a1a2e; font-size:13px; }
  .header { display:flex; align-items:center; justify-content:space-between; border-bottom:3px solid #4f46e5; padding-bottom:18px; margin-bottom:24px; }
  .header .left h1 { font-size:22px; color:#4f46e5; }
  .header .left h2 { font-size:14px; color:#555; margin-top:4px; }
  .header .logo img { max-height:70px; }
  .meta { display:flex; gap:24px; margin-bottom:20px; font-size:12px; color:#555; }
  .stats-row { display:grid; grid-template-columns:repeat(3,1fr); gap:16px; margin-bottom:24px; }
  .stat-box { border:1px solid #e0e0e0; border-radius:10px; padding:14px; text-align:center; }
  .stat-val { font-size:20px; font-weight:700; color:#4f46e5; }
  .stat-lbl { font-size:11px; color:#888; margin-top:4px; }
  .breakdown-grid { display:grid; grid-template-columns:1fr 1fr; gap:24px; margin-bottom:24px; }
  .section-title { font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:1px; color:#4f46e5; border-bottom:1px solid #e0e0e0; padding-bottom:5px; margin-bottom:10px; }
  table { width:100%; border-collapse:collapse; }
  th, td { border:1px solid #ddd; padding:6px 8px; text-align:left; font-size:12px; }
  th { background:#f8f9fa; font-weight:600; }
  tr:nth-child(even) { background:#fafafa; }
  .badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:10px; font-weight:700; color:#fff; }
  .badge-po { background:#3730a3; }
  .badge-grn { background:#166534; }
  .badge-gin { background:#991b1b; }
  .badge-transfer { background:#1e40af; }
  .badge-adjustment { background:#92400e; }
  .badge-stock_count { background:#6b21a8; }
  .status-badge { display:inline-block; padding:2px 6px; border-radius:4px; font-size:10px; font-weight:700; }
  .status-posted { background:#d1fae5; color:#065f46; }
  .status-draft  { background:#e5e7eb; color:#374151; }
  .status-cancelled { background:#fee2e2; color:#991b1b; }
  .footer { text-align:center; margin-top:24px; font-size:10px; color:#999; border-top:1px solid #eee; padding-top:10px; }
  @media print {
    @page { margin: 0; }
    body { padding:10px; }
    .stats-row, .breakdown-grid { break-inside:avoid; }
    th, td { padding:4px 6px; font-size:10px; }
    .stat-val { font-size:16px; }
  }
</style></head><body>
  <div class="header">
    <div class="left">
      <h1>VISION COMPUTERS</h1>
      <h2>Inventory — Summary Report</h2>
    </div>
    <div class="logo"><img src="/logo.jpg" alt="Logo"></div>
  </div>
  <div class="meta">
    <span><strong>Generated:</strong> ${now}</span>
    <span><strong>Filters:</strong> ${filterDesc}</span>
  </div>
  ${statsHTML}
  ${breakdownHTML}
  <div class="section-title" style="margin-bottom:10px">Document Details</div>
  <table>
    <thead>
      <tr>
        <th>Type</th><th>Doc #</th><th>Date</th><th>Warehouse</th>
        <th>Supplier / Target</th><th>Qty</th><th>Total Cost</th>
        <th>Status</th><th>Created By</th>
      </tr>
    </thead>
    <tbody>${docRows}</tbody>
    <tfoot>
      <tr style="font-weight:700;background:#f0f0ff">
        <td colspan="5">TOTAL</td>
        <td style="text-align:right">${totalQty.toLocaleString()}</td>
        <td style="text-align:right">LKR ${totalCost.toLocaleString(undefined, { minimumFractionDigits: 2 })}</td>
        <td colspan="2"></td>
      </tr>
    </tfoot>
  </table>
  <div class="footer">Vision Computers ERP &nbsp;|&nbsp; Confidential &nbsp;|&nbsp; ${now}</div>
</body></html>`

  openPrintWindow(html, 'Inventory_Summary_Report', false)
}

/* ─────────────────────────────────────────────
   INDIVIDUAL DOCUMENT HTML builder
───────────────────────────────────────────── */
function buildDocumentReportHTML(header, lines) {
  const docTypeLabel =
    {
      PO: 'Purchase Order',
      GRN: 'Goods Receipt Note',
      GIN: 'Goods Issue Note',
      TRANSFER: 'Stock Transfer',
      ADJUSTMENT: 'Stock Adjustment',
      STOCK_COUNT: 'Stock Count',
    }[header.doc_type] || header.doc_type

  const lineRows = lines
    .map(
      (l, i) => `
    <tr>
      <td style="text-align:center">${i + 1}</td>
      <td>${l.item_code || '-'}</td>
      <td>${l.item_name || '-'}</td>
      <td style="text-align:center">${l.uom_code || '-'}</td>
      <td style="text-align:right">${Number(l.quantity || 0).toLocaleString()}</td>
      <td style="text-align:right">LKR ${Number(l.unit_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}</td>
      <td style="text-align:right">LKR ${Number(l.line_total || l.quantity * l.unit_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}</td>
      <td>${l.batch_no || '-'}</td>
      <td>${l.notes || '-'}</td>
    </tr>`,
    )
    .join('')

  const grandTotal = lines.reduce(
    (s, l) => s + Number(l.line_total || l.quantity * l.unit_cost || 0),
    0,
  )
  const totalQty = lines.reduce((s, l) => s + Number(l.quantity || 0), 0)

  return `<!DOCTYPE html><html><head><title>${docTypeLabel} - ${header.doc_number}</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:'Segoe UI',sans-serif; padding:32px; color:#1a1a2e; font-size:13px; }
  .header { display:flex; align-items:center; justify-content:space-between; border-bottom:3px solid #4f46e5; padding-bottom:18px; margin-bottom:24px; }
  .header .left h1 { font-size:22px; color:#4f46e5; }
  .header .left h2 { font-size:14px; color:#555; margin-top:4px; }
  .header .logo img { max-height:70px; }
  .info-grid { display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-bottom:20px; font-size:13px; }
  .info-row { display:flex; gap:8px; }
  .info-label { font-weight:600; color:#555; min-width:150px; }
  .section-title { font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:1px; color:#4f46e5; border-bottom:1px solid #e0e0e0; padding-bottom:5px; margin-bottom:12px; margin-top:20px; }
  table { width:100%; border-collapse:collapse; }
  th, td { border:1px solid #ddd; padding:7px 9px; text-align:left; font-size:12px; }
  th { background:#f8f9fa; font-weight:600; }
  tr:nth-child(even) { background:#fafafa; }
  .status-badge { display:inline-block; padding:3px 10px; border-radius:20px; font-weight:700; font-size:11px; }
  .status-posted { background:#d1fae5; color:#065f46; }
  .status-draft  { background:#e5e7eb; color:#374151; }
  .status-cancelled { background:#fee2e2; color:#991b1b; }
  .totals-section { margin-top:16px; display:flex; justify-content:flex-end; }
  .totals-box { border:1px solid #e0e0e0; border-radius:8px; padding:12px 20px; min-width:260px; }
  .totals-box .row { display:flex; justify-content:space-between; margin-bottom:6px; font-size:13px; }
  .totals-box .grand { font-size:16px; font-weight:700; color:#4f46e5; border-top:2px solid #4f46e5; padding-top:8px; margin-top:4px; }
  .footer { text-align:center; margin-top:40px; font-size:10px; color:#999; border-top:1px solid #eee; padding-top:10px; }
  @media print {
    @page { margin: 0; }
    body { padding:10px; }
    th, td { padding:4px 6px; font-size:10px; }
  }
</style></head><body>
  <div class="header">
    <div class="left">
      <h1>VISION COMPUTERS</h1>
      <h2>${docTypeLabel}</h2>
    </div>
    <div class="logo"><img src="/logo.jpg" alt="Logo"></div>
  </div>

  <div class="info-grid">
    <div>
      <div class="info-row"><span class="info-label">Document #:</span> <strong>${header.doc_number || '-'}</strong></div>
      <div class="info-row"><span class="info-label">Date:</span> ${header.doc_date || '-'}</div>
      <div class="info-row"><span class="info-label">Status:</span> <span class="status-badge status-${header.status}">${(header.status || '').toUpperCase()}</span></div>
      <div class="info-row"><span class="info-label">Reference #:</span> ${header.reference_no || '-'}</div>
    </div>
    <div>
      <div class="info-row"><span class="info-label">Warehouse:</span> ${header.warehouse_name || '-'}</div>
      <div class="info-row"><span class="info-label">Supplier:</span> ${header.supplier_name || '-'}</div>
      <div class="info-row"><span class="info-label">Target Warehouse:</span> ${header.target_warehouse_name || '-'}</div>
      <div class="info-row"><span class="info-label">Created By:</span> ${header.created_by_name || '-'}</div>
    </div>
  </div>
  ${header.remarks ? `<div style="margin-bottom:16px;padding:10px;background:#f8f9fa;border-radius:6px;font-size:12px"><strong>Remarks:</strong> ${header.remarks}</div>` : ''}

  <div class="section-title">Line Items</div>
  <table>
    <thead>
      <tr>
        <th>#</th><th>Code</th><th>Item Name</th><th>UOM</th>
        <th>Qty</th><th>Unit Cost</th><th>Line Total</th>
        <th>Batch</th><th>Notes</th>
      </tr>
    </thead>
    <tbody>${lineRows}</tbody>
    <tfoot>
      <tr style="font-weight:700;background:#f0f0ff">
        <td colspan="4">TOTAL</td>
        <td style="text-align:right">${totalQty.toLocaleString()}</td>
        <td></td>
        <td style="text-align:right">LKR ${grandTotal.toLocaleString(undefined, { minimumFractionDigits: 2 })}</td>
        <td colspan="2"></td>
      </tr>
    </tfoot>
  </table>

  <div class="totals-section">
    <div class="totals-box">
      <div class="row"><span>Total Lines:</span><span>${lines.length}</span></div>
      <div class="row"><span>Total Quantity:</span><span>${totalQty.toLocaleString()}</span></div>
      <div class="row grand"><span>Grand Total:</span><span>LKR ${grandTotal.toLocaleString(undefined, { minimumFractionDigits: 2 })}</span></div>
    </div>
  </div>

  <div class="footer">Vision Computers ERP &nbsp;|&nbsp; ${docTypeLabel} &nbsp;|&nbsp; ${header.doc_number} &nbsp;|&nbsp; Confidential</div>
</body></html>`
}

/* ─────────────────────────────────────────────
   Open print window — print or view
───────────────────────────────────────────── */
function openPrintWindow(html, filename, autoPrint) {
  const win = window.open('', '_blank')
  if (!win) {
    $q.notify({ type: 'negative', message: 'Popup blocked. Please allow popups for this site.' })
    return
  }

  // Build toolbar HTML without nesting script tags inside template literals
  const scriptOpen = '<' + 'script>'
  const scriptClose = '<' + '/script>'

  const toolbarHTML = `
    <div id="vctoolbar" style="position:fixed;top:0;left:0;right:0;background:#4f46e5;padding:8px 16px;display:flex;gap:10px;align-items:center;z-index:9999">
      <span style="color:#fff;font-weight:600;flex:1">📄 ${filename.replace(/_/g, ' ')}</span>
      <button onclick="window.print()" style="background:#fff;color:#4f46e5;border:none;padding:6px 14px;border-radius:6px;cursor:pointer;font-weight:600">🖨️ Print</button>
      <button onclick="vcDownload()" style="background:#10b981;color:#fff;border:none;padding:6px 14px;border-radius:6px;cursor:pointer;font-weight:600">⬇️ Download HTML</button>
      <button onclick="document.getElementById('vctoolbar').style.display='none'" style="background:transparent;color:#fff;border:1px solid #fff;padding:6px 10px;border-radius:6px;cursor:pointer">✕</button>
    </div>
    <div style="height:50px"></div>
    ${scriptOpen}
      var _vcFilename = '${filename.replace(/'/g, '')}';
      function vcDownload() {
        var blob = new Blob([document.documentElement.outerHTML], { type: 'text/html' });
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = _vcFilename + '_' + new Date().toISOString().slice(0, 10) + '.html';
        a.click();
      }
    ${scriptClose}
  `

  const finalHtml = html.replace('</body>', toolbarHTML + '</body>')
  win.document.write(finalHtml)
  win.document.close()
  if (autoPrint) {
    setTimeout(() => win.print(), 600)
  }
}
</script>

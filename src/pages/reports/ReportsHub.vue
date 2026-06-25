<template>
  <q-page class="q-pa-lg">
    <!-- ── Header ─────────────────────────────────────────────────────── -->
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bolder q-ma-none text-gradient">Reports Hub</h1>
        <div class="text-subtitle2 text-grey-6 q-mt-xs">
          Full reports — suppliers, items, inventory, service &amp; finance
        </div>
      </div>
      <div class="col-auto">
        <img src="/logo.png" alt="Vision Computers" style="max-height: 64px; object-fit: contain" />
      </div>
    </div>

    <!-- ── Report Type Tabs ───────────────────────────────────────────── -->
    <q-tabs
      v-model="tab"
      dense
      align="left"
      narrow-indicator
      :dark="$q.dark.isActive"
      active-color="primary"
      indicator-color="primary"
      class="q-mb-md"
    >
      <q-tab name="suppliers" icon="local_shipping" label="Suppliers" />
      <q-tab name="items" icon="inventory_2" label="Items / Products" />
      <q-tab name="low_stock" icon="warning" label="Low Stock" />
      <q-tab name="inv_docs" icon="description" label="Inventory Documents" />
      <q-tab name="service" icon="build" label="Service" />
      <q-tab name="finance" icon="account_balance" label="Finance" />
    </q-tabs>

    <q-tab-panels v-model="tab" animated :dark="$q.dark.isActive" class="bg-transparent">
      <!-- ════════════════════════════════════════
           SUPPLIERS
      ═══════════════════════════════════════════ -->
      <q-tab-panel name="suppliers" class="q-pa-none">
        <ReportCard
          title="Supplier Directory"
          icon="local_shipping"
          color="indigo"
          :loading="supplierLoading"
          :rows="filteredSuppliers"
          :columns="supplierCols"
          report-key="supplier_list"
          @reload="loadSuppliers"
        >
          <template #filters>
            <q-input
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="supplierSearch"
              placeholder="Search supplier..."
              style="min-width: 220px"
              clearable
            >
              <template #prepend><q-icon name="search" /></template>
            </q-input>
            <q-select
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="supplierStatus"
              :options="statusOpts"
              emit-value
              map-options
              label="Status"
              style="min-width: 140px"
            />
          </template>
          <template #stat-extra>
            <StatBox
              label="Active"
              :value="suppliers.filter((s) => s.is_active).length"
              color="positive"
            />
            <StatBox
              label="Inactive"
              :value="suppliers.filter((s) => !s.is_active).length"
              color="negative"
            />
          </template>
        </ReportCard>
      </q-tab-panel>

      <!-- ════════════════════════════════════════
           ITEMS / PRODUCTS
      ═══════════════════════════════════════════ -->
      <q-tab-panel name="items" class="q-pa-none">
        <ReportCard
          title="Product / Item Registry"
          icon="inventory_2"
          color="teal"
          :loading="itemLoading"
          :rows="filteredItems"
          :columns="itemCols"
          report-key="item_list"
          @reload="loadItems"
        >
          <template #filters>
            <q-input
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="itemSearch"
              placeholder="Search item..."
              style="min-width: 220px"
              clearable
            >
              <template #prepend><q-icon name="search" /></template>
            </q-input>
            <q-select
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="itemCategoryFilter"
              :options="categoryOpts"
              emit-value
              map-options
              label="Category"
              style="min-width: 180px"
            />
            <q-select
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="itemStatusFilter"
              :options="statusOpts"
              emit-value
              map-options
              label="Status"
              style="min-width: 140px"
            />
          </template>
          <template #stat-extra>
            <StatBox label="Total Items" :value="items.length" color="primary" />
            <StatBox
              label="Stock Value"
              :value="
                'LKR ' +
                items
                  .reduce((s, i) => s + Number(i.total_qty || 0) * Number(i.cost_price || 0), 0)
                  .toLocaleString()
              "
              color="teal"
            />
          </template>
        </ReportCard>
      </q-tab-panel>

      <!-- ════════════════════════════════════════
           LOW STOCK
      ═══════════════════════════════════════════ -->
      <q-tab-panel name="low_stock" class="q-pa-none">
        <ReportCard
          title="Low Stock Alert"
          icon="warning"
          color="orange"
          :loading="itemLoading"
          :rows="lowStockItems"
          :columns="lowStockCols"
          report-key="item_list_low_stock"
          @reload="loadItems"
        >
          <template #filters>
            <q-input
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="lowStockSearch"
              placeholder="Search item..."
              style="min-width: 220px"
              clearable
            >
              <template #prepend><q-icon name="search" /></template>
            </q-input>
            <q-select
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="lowStockCategoryFilter"
              :options="categoryOpts"
              emit-value
              map-options
              label="Category"
              style="min-width: 180px"
            />
          </template>
          <template #stat-extra>
            <StatBox label="Low / Out of Stock" :value="lowStockItems.length" color="orange" />
            <StatBox
              label="Out of Stock"
              :value="lowStockItems.filter((i) => Number(i.total_qty || 0) <= 0).length"
              color="negative"
            />
          </template>
        </ReportCard>
      </q-tab-panel>

      <!-- ════════════════════════════════════════
           INVENTORY DOCUMENTS
      ═══════════════════════════════════════════ -->
      <q-tab-panel name="inv_docs" class="q-pa-none">
        <ReportCard
          title="Inventory Documents Summary"
          icon="description"
          color="blue"
          :loading="docLoading"
          :rows="filteredDocs"
          :columns="docCols"
          report-key="inventory_docs"
          @reload="loadDocs"
        >
          <template #filters>
            <q-select
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="docTypeFilter"
              :options="docTypeOpts"
              emit-value
              map-options
              label="Type"
              style="min-width: 160px"
            />
            <q-select
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="docStatusFilter"
              :options="docStatusOpts"
              emit-value
              map-options
              label="Status"
              style="min-width: 140px"
            />
            <q-input
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="docDateFrom"
              type="date"
              label="From"
              style="min-width: 140px"
            />
            <q-input
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="docDateTo"
              type="date"
              label="To"
              style="min-width: 140px"
            />
          </template>
          <template #stat-extra>
            <StatBox
              label="Posted"
              :value="filteredDocs.filter((d) => d.status === 'posted').length"
              color="positive"
            />
            <StatBox
              label="Total Cost"
              :value="
                'LKR ' +
                filteredDocs
                  .reduce((s, d) => s + Number(d.total_cost || 0), 0)
                  .toLocaleString(undefined, { minimumFractionDigits: 2 })
              "
              color="blue"
            />
          </template>
        </ReportCard>
      </q-tab-panel>

      <!-- ════════════════════════════════════════
           SERVICE REPORT
       ═══════════════════════════════════════════ -->
      <q-tab-panel name="service" class="q-pa-none">
        <!-- Sub-tabs: Revenue vs Full Detail -->
        <q-tabs
          v-model="serviceSubTab"
          dense
          align="left"
          narrow-indicator
          active-color="purple"
          indicator-color="purple"
          class="q-mb-md"
        >
          <q-tab name="revenue" icon="bar_chart" label="Revenue Report" />
          <q-tab name="full" icon="summarize" label="Full Detail Report" />
        </q-tabs>

        <!-- Revenue Report -->
        <div v-if="serviceSubTab === 'revenue'">
          <ReportCard
            title="Service Revenue Report"
            icon="bar_chart"
            color="purple"
            :loading="serviceLoading"
            :rows="filteredService"
            :columns="serviceCols"
            report-key="service_sales"
            @reload="loadService"
          >
            <template #filters>
              <q-btn-group flat>
                <q-btn
                  v-for="r in dateRanges"
                  :key="r.v"
                  :label="r.l"
                  :flat="serviceRange !== r.v"
                  :unelevated="serviceRange === r.v"
                  :color="serviceRange === r.v ? 'primary' : 'grey-7'"
                  size="sm"
                  no-caps
                  @click="setServiceRange(r.v)"
                />
              </q-btn-group>
              <q-input
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="serviceSearch"
                placeholder="Search job..."
                style="min-width: 200px"
                clearable
              >
                <template #prepend><q-icon name="search" /></template>
              </q-input>
            </template>
            <template #stat-extra>
              <StatBox label="Total Jobs" :value="serviceJobs.length" color="purple" />
              <StatBox
                label="Revenue"
                :value="
                  'LKR ' +
                  serviceJobs
                    .reduce((s, j) => s + Number(j.total_final_cost || 0), 0)
                    .toLocaleString()
                "
                color="positive"
              />
            </template>
          </ReportCard>
        </div>

        <!-- Full Detail Report -->
        <div v-if="serviceSubTab === 'full'">
          <ReportCard
            title="Service Full Detail Report"
            icon="summarize"
            color="deep-purple"
            :loading="serviceLoading"
            :rows="filteredServiceFull"
            :columns="serviceFullCols"
            report-key="service_full_report"
            @reload="loadService"
          >
            <template #filters>
              <q-btn-group flat>
                <q-btn
                  v-for="r in dateRanges"
                  :key="r.v"
                  :label="r.l"
                  :flat="serviceRange !== r.v"
                  :unelevated="serviceRange === r.v"
                  :color="serviceRange === r.v ? 'primary' : 'grey-7'"
                  size="sm"
                  no-caps
                  @click="setServiceRange(r.v)"
                />
              </q-btn-group>
              <q-select
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="serviceStatusFilter"
                :options="serviceStatusOpts"
                emit-value
                map-options
                label="Status"
                style="min-width: 150px"
              />
              <q-select
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="servicePaymentFilter"
                :options="servicePaymentOpts"
                emit-value
                map-options
                label="Payment"
                style="min-width: 150px"
              />
              <q-input
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="serviceFullSearch"
                placeholder="Search customer / job..."
                style="min-width: 220px"
                clearable
              >
                <template #prepend><q-icon name="search" /></template>
              </q-input>
            </template>
            <template #stat-extra>
              <StatBox label="Total Jobs" :value="serviceJobs.length" color="deep-purple" />
              <StatBox
                label="Completed"
                :value="serviceJobs.filter((j) => j.status === 'completed').length"
                color="positive"
              />
              <StatBox
                label="Revenue"
                :value="
                  'LKR ' +
                  serviceJobs
                    .reduce((s, j) => s + Number(j.total_final_cost || 0), 0)
                    .toLocaleString()
                "
                color="teal"
              />
              <StatBox
                label="Outstanding"
                :value="
                  'LKR ' +
                  serviceJobs
                    .filter((j) => j.payment_status !== 'paid')
                    .reduce((s, j) => s + Number(j.total_final_cost || 0), 0)
                    .toLocaleString()
                "
                color="negative"
              />
            </template>
          </ReportCard>
        </div>
      </q-tab-panel>

      <!-- ════════════════════════════════════════
           FINANCE REPORT
      ═══════════════════════════════════════════ -->
      <q-tab-panel name="finance" class="q-pa-none">
        <ReportCard
          title="Finance Overview — Invoice Registry"
          icon="account_balance"
          color="indigo"
          :loading="financeLoading"
          :rows="filteredFinance"
          :columns="financeCols"
          report-key="invoice_list"
          @reload="loadFinance"
        >
          <template #filters>
            <q-btn-group flat>
              <q-btn
                v-for="r in dateRanges"
                :key="r.v"
                :label="r.l"
                :flat="financeRange !== r.v"
                :unelevated="financeRange === r.v"
                :color="financeRange === r.v ? 'primary' : 'grey-7'"
                size="sm"
                no-caps
                @click="setFinanceRange(r.v)"
              />
            </q-btn-group>
            <q-select
              :dark="$q.dark.isActive"
              outlined
              dense
              v-model="financeStatus"
              :options="financeStatusOpts"
              emit-value
              map-options
              label="Payment Status"
              style="min-width: 160px"
            />
          </template>
          <template #stat-extra>
            <StatBox
              label="Total Billed"
              :value="
                'LKR ' +
                financeInvoices.reduce((s, i) => s + Number(i.total || 0), 0).toLocaleString()
              "
              color="primary"
            />
            <StatBox
              label="Outstanding"
              :value="
                'LKR ' +
                financeInvoices.reduce((s, i) => s + Number(i.balance || 0), 0).toLocaleString()
              "
              color="negative"
            />
          </template>
        </ReportCard>
      </q-tab-panel>
    </q-tab-panels>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, defineComponent, h } from 'vue'
import { useQuasar, date } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'
import { useReportStore } from 'src/stores/reportStore'
import ExportButton from 'src/components/common/ExportButton.vue'
import { useSupplierList, useItemsList, useDocumentList } from 'src/services/inventoryService'

const $q = useQuasar()
const auth = useAuthStore()
const reportStore = useReportStore()
const tab = ref('suppliers')

const getCompanyId = () => auth.currentBranch?.company_id

/* ── Stat Box helper component ──────────────────────────────────────── */
const StatBox = defineComponent({
  props: { label: String, value: [String, Number], color: { type: String, default: 'primary' } },
  setup(props) {
    return () =>
      h('div', { class: 'stat-box' }, [
        h('div', { class: `stat-val text-${props.color}` }, props.value),
        h('div', { class: 'stat-lbl' }, props.label),
      ])
  },
})

/* ── Report Card sub-component ──────────────────────────────────────── */
const ReportCard = defineComponent({
  name: 'ReportCard',
  props: {
    title: String,
    icon: String,
    color: String,
    loading: Boolean,
    rows: Array,
    columns: Array,
    reportKey: String,
  },
  emits: ['reload'],
  setup(props, { slots, emit }) {
    return () =>
      h('div', [
        /* Stat bar */
        h('div', { class: 'row items-center q-mb-sm q-gutter-sm' }, [
          h('div', { class: `text-subtitle1 text-weight-bold text-${props.color}` }, [
            h('q-icon', { name: props.icon, class: 'q-mr-xs' }),
            props.title,
          ]),
          h('q-space'),
          slots['stat-extra']?.(),
        ]),
        /* Filter bar */
        h('div', { class: 'row items-center q-mb-md q-gutter-sm flex-wrap' }, [
          slots['filters']?.(),
          h('q-space'),
          h('q-btn', {
            flat: true,
            round: true,
            dense: true,
            icon: 'refresh',
            color: 'grey-6',
            onClick: () => emit('reload'),
          }),
          h(ExportButton, {
            data: props.rows,
            excelOptions: [{ key: props.reportKey, label: props.title }],
            pdfOptions: [{ key: props.reportKey, label: props.title }],
          }),
        ]),
        /* Table */
        h(
          'q-card',
          { flat: true, bordered: true, class: $q.dark.isActive ? 'bg-grey-9' : 'bg-white' },
          [
            h('q-inner-loading', { showing: props.loading }),
            h('q-table', {
              rows: props.rows,
              columns: props.columns,
              rowKey: 'id',
              dark: $q.dark.isActive,
              flat: true,
              dense: true,
              class: 'bg-transparent',
              loading: props.loading,
              rowsPerPageOptions: [15, 25, 50, 100],
              tableHeaderClass: $q.dark.isActive
                ? 'text-grey-5 text-uppercase'
                : 'text-grey-7 text-uppercase',
            }),
          ],
        ),
      ])
  },
})

/* ─────────────────────────────────────────────
   Date range helpers
───────────────────────────────────────────── */
const dateRanges = [
  { l: 'Today', v: 'today' },
  { l: 'Week', v: 'week' },
  { l: 'Month', v: 'month' },
  { l: 'Year', v: 'year' },
]

function getRange(key) {
  const now = new Date()
  const fmt = (d) => date.formatDate(d, 'YYYY-MM-DD')
  if (key === 'today') return { from: fmt(now), to: fmt(now) }
  if (key === 'week') return { from: fmt(date.subtractFromDate(now, { days: 7 })), to: fmt(now) }
  if (key === 'year') return { from: fmt(date.startOfDate(now, 'year')), to: fmt(now) }
  return { from: fmt(date.startOfDate(now, 'month')), to: fmt(now) }
}

const statusOpts = [
  { label: 'All', value: '' },
  { label: 'Active', value: 'active' },
  { label: 'Inactive', value: 'inactive' },
]

/* ─────────────────────────────────────────────
   SUPPLIERS
───────────────────────────────────────────── */
const { suppliers, loading: supplierLoading, listSuppliers } = useSupplierList()
const supplierSearch = ref('')
const supplierStatus = ref('')

const filteredSuppliers = computed(() => {
  let rows = suppliers.value
  if (supplierStatus.value === 'active') rows = rows.filter((s) => s.is_active)
  if (supplierStatus.value === 'inactive') rows = rows.filter((s) => !s.is_active)
  if (supplierSearch.value)
    rows = rows.filter((s) =>
      [s.name, s.code, s.contact_person, s.phone, s.email].some((v) =>
        v?.toLowerCase().includes(supplierSearch.value.toLowerCase()),
      ),
    )
  return rows
})

const supplierCols = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'contact_person', label: 'Contact', field: 'contact_person', align: 'left' },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'tax_id', label: 'Tax ID', field: 'tax_id', align: 'left' },
  {
    name: 'is_active',
    label: 'Status',
    field: (r) => (r.is_active ? 'Active' : 'Inactive'),
    align: 'center',
    sortable: true,
  },
]

function loadSuppliers() {
  listSuppliers()
}

/* ─────────────────────────────────────────────
   ITEMS
───────────────────────────────────────────── */
const { items, loading: itemLoading, listItems } = useItemsList()
const itemSearch = ref('')
const itemCategoryFilter = ref('')
const itemStatusFilter = ref('')
const lowStockSearch = ref('')
const lowStockCategoryFilter = ref('')

const categoryOpts = computed(() => {
  const cats = [...new Set(items.value.map((i) => i.category_name).filter(Boolean))]
  return [{ label: 'All Categories', value: '' }, ...cats.map((c) => ({ label: c, value: c }))]
})

const filteredItems = computed(() => {
  let rows = items.value
  if (itemStatusFilter.value === 'active') rows = rows.filter((i) => i.is_active)
  if (itemStatusFilter.value === 'inactive') rows = rows.filter((i) => !i.is_active)
  if (itemCategoryFilter.value)
    rows = rows.filter((i) => i.category_name === itemCategoryFilter.value)
  if (itemSearch.value)
    rows = rows.filter((i) =>
      [i.name, i.code, i.brand, i.category_name].some((v) =>
        v?.toLowerCase().includes(itemSearch.value.toLowerCase()),
      ),
    )
  return rows
})

const lowStockItems = computed(() => {
  let rows = items.value.filter(
    (i) => i.is_active && Number(i.total_qty || 0) <= Number(i.reorder_level || 0),
  )
  if (lowStockCategoryFilter.value)
    rows = rows.filter((i) => i.category_name === lowStockCategoryFilter.value)
  if (lowStockSearch.value)
    rows = rows.filter((i) =>
      [i.name, i.code, i.brand].some((v) =>
        v?.toLowerCase().includes(lowStockSearch.value.toLowerCase()),
      ),
    )
  return rows.sort((a, b) => Number(a.total_qty || 0) - Number(b.total_qty || 0))
})

const itemCols = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Product Name', field: 'name', align: 'left', sortable: true },
  {
    name: 'category_name',
    label: 'Category',
    field: 'category_name',
    align: 'left',
    sortable: true,
  },
  { name: 'brand', label: 'Brand', field: 'brand', align: 'left' },
  { name: 'uom_code', label: 'UOM', field: 'uom_code', align: 'center' },
  { name: 'total_qty', label: 'Stock', field: 'total_qty', align: 'right', sortable: true },
  { name: 'reorder_level', label: 'Reorder', field: 'reorder_level', align: 'right' },
  {
    name: 'cost_price',
    label: 'Cost Price',
    field: (r) =>
      'LKR ' + Number(r.cost_price || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
  },
  {
    name: 'sale_price',
    label: 'Sale Price',
    field: (r) =>
      'LKR ' + Number(r.sale_price || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
  },
  {
    name: 'is_active',
    label: 'Status',
    field: (r) => (r.is_active ? 'Active' : 'Inactive'),
    align: 'center',
    sortable: true,
  },
]

const lowStockCols = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Product Name', field: 'name', align: 'left', sortable: true },
  { name: 'category_name', label: 'Category', field: 'category_name', align: 'left' },
  { name: 'brand', label: 'Brand', field: 'brand', align: 'left' },
  { name: 'total_qty', label: 'Current Stock', field: 'total_qty', align: 'right', sortable: true },
  { name: 'reorder_level', label: 'Reorder Level', field: 'reorder_level', align: 'right' },
  {
    name: 'shortage',
    label: 'Shortage',
    field: (r) => Math.max(0, Number(r.reorder_level || 0) - Number(r.total_qty || 0)),
    align: 'right',
  },
  { name: 'supplier_name', label: 'Supplier', field: 'supplier_name', align: 'left' },
]

function loadItems() {
  listItems()
}

/* ─────────────────────────────────────────────
   INVENTORY DOCUMENTS
───────────────────────────────────────────── */
const { documents: docs, loading: docLoading, listDocuments } = useDocumentList()
const docTypeFilter = ref('')
const docStatusFilter = ref('')
const docDateFrom = ref('')
const docDateTo = ref('')

const docTypeOpts = [
  { label: 'All Types', value: '' },
  { label: 'PO', value: 'PO' },
  { label: 'GRN', value: 'GRN' },
  { label: 'GIN', value: 'GIN' },
  { label: 'Transfer', value: 'TRANSFER' },
  { label: 'Adjustment', value: 'ADJUSTMENT' },
  { label: 'Stock Count', value: 'STOCK_COUNT' },
]

const docStatusOpts = [
  { label: 'All', value: '' },
  { label: 'Posted', value: 'posted' },
  { label: 'Draft', value: 'draft' },
  { label: 'Cancelled', value: 'cancelled' },
]

const filteredDocs = computed(() => {
  let rows = docs.value
  if (docTypeFilter.value) rows = rows.filter((d) => d.doc_type === docTypeFilter.value)
  if (docStatusFilter.value) rows = rows.filter((d) => d.status === docStatusFilter.value)
  if (docDateFrom.value) rows = rows.filter((d) => d.doc_date >= docDateFrom.value)
  if (docDateTo.value) rows = rows.filter((d) => d.doc_date <= docDateTo.value)
  return rows
})

const docCols = [
  { name: 'doc_type', label: 'Type', field: 'doc_type', align: 'left', sortable: true },
  { name: 'doc_number', label: 'Doc #', field: 'doc_number', align: 'left', sortable: true },
  { name: 'doc_date', label: 'Date', field: 'doc_date', align: 'center', sortable: true },
  { name: 'warehouse_name', label: 'Warehouse', field: 'warehouse_name', align: 'left' },
  {
    name: 'party',
    label: 'Supplier/Target',
    field: (r) => r.supplier_name || r.target_warehouse_name || '-',
    align: 'left',
  },
  { name: 'total_qty', label: 'Qty', field: 'total_qty', align: 'right', sortable: true },
  {
    name: 'total_cost',
    label: 'Cost',
    field: (r) =>
      'LKR ' + Number(r.total_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
    sortable: true,
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
  { name: 'created_by_name', label: 'By', field: 'created_by_name', align: 'left' },
]

function loadDocs() {
  listDocuments({
    docType: docTypeFilter.value || undefined,
    status: docStatusFilter.value || undefined,
    dateFrom: docDateFrom.value || undefined,
    dateTo: docDateTo.value || undefined,
  })
}

/* ─────────────────────────────────────────────
   SERVICE
───────────────────────────────────────────── */
const serviceJobs = ref([])
const serviceLoading = ref(false)
const serviceRange = ref('month')
const serviceSearch = ref('')
const serviceSubTab = ref('revenue')
const serviceStatusFilter = ref('')
const servicePaymentFilter = ref('')
const serviceFullSearch = ref('')

const serviceStatusOpts = [
  { label: 'All Status', value: '' },
  { label: 'Pending', value: 'pending' },
  { label: 'In Progress', value: 'in_progress' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]

const servicePaymentOpts = [
  { label: 'All Payment', value: '' },
  { label: 'Unpaid', value: 'unpaid' },
  { label: 'Partial', value: 'partial' },
  { label: 'Paid', value: 'paid' },
]

function setServiceRange(v) {
  serviceRange.value = v
  loadService()
}

const filteredService = computed(() => {
  if (!serviceSearch.value) return serviceJobs.value
  return serviceJobs.value.filter((j) =>
    [j.job_no, j.customer_name, j.device_type, j.brand, j.model].some((v) =>
      v?.toLowerCase().includes(serviceSearch.value.toLowerCase()),
    ),
  )
})

const filteredServiceFull = computed(() => {
  let rows = serviceJobs.value
  if (serviceStatusFilter.value) rows = rows.filter((j) => j.status === serviceStatusFilter.value)
  if (servicePaymentFilter.value)
    rows = rows.filter((j) => j.payment_status === servicePaymentFilter.value)
  if (serviceFullSearch.value) {
    const q = serviceFullSearch.value.toLowerCase()
    rows = rows.filter((j) =>
      [
        j.job_no,
        j.customer_name,
        j.customer_phone,
        j.device_type,
        j.brand,
        j.model,
        j.serial_no,
        j.issue_reported_by_customer,
      ].some((v) => v?.toLowerCase().includes(q)),
    )
  }
  return rows
})

const serviceCols = [
  { name: 'job_no', label: 'Job #', field: 'job_no', align: 'left', sortable: true },
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'device_type', label: 'Device', field: 'device_type', align: 'left' },
  {
    name: 'brand',
    label: 'Brand/Model',
    field: (r) => `${r.brand || ''} ${r.model || ''}`.trim(),
    align: 'left',
  },
  {
    name: 'received_date',
    label: 'Received',
    field: 'received_date',
    align: 'center',
    sortable: true,
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'center' },
  {
    name: 'total_final_cost',
    label: 'Final Cost',
    field: (r) =>
      'LKR ' +
      Number(r.total_final_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
    sortable: true,
  },
]

const serviceFullCols = [
  { name: 'job_no', label: 'Job #', field: 'job_no', align: 'left', sortable: true },
  {
    name: 'received_date',
    label: 'Received',
    field: 'received_date',
    align: 'center',
    sortable: true,
  },
  {
    name: 'completion_date',
    label: 'Completed',
    field: 'completion_date',
    align: 'center',
    sortable: true,
  },
  {
    name: 'customer_name',
    label: 'Customer',
    field: 'customer_name',
    align: 'left',
    sortable: true,
  },
  { name: 'customer_phone', label: 'Phone', field: 'customer_phone', align: 'left' },
  { name: 'device_type', label: 'Device', field: 'device_type', align: 'left' },
  {
    name: 'brand_model',
    label: 'Brand/Model',
    field: (r) => `${r.brand || ''} ${r.model || ''}`.trim(),
    align: 'left',
  },
  { name: 'serial_no', label: 'Serial No', field: 'serial_no', align: 'left' },
  {
    name: 'issue_reported',
    label: 'Issue Reported',
    field: 'issue_reported_by_customer',
    align: 'left',
  },
  { name: 'inspection_notes', label: 'Inspection Notes', field: 'inspection_notes', align: 'left' },
  { name: 'technician', label: 'Technician', field: 'technician_name', align: 'left' },
  { name: 'warranty_days', label: 'Warranty (Days)', field: 'warranty_days', align: 'center' },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
  {
    name: 'payment_status',
    label: 'Payment',
    field: 'payment_status',
    align: 'center',
    sortable: true,
  },
  {
    name: 'total_estimated_cost',
    label: 'Est. Cost',
    field: (r) =>
      'LKR ' +
      Number(r.total_estimated_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
  },
  {
    name: 'total_final_cost',
    label: 'Final Cost',
    field: (r) =>
      'LKR ' +
      Number(r.total_final_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
    sortable: true,
  },
]

async function loadService() {
  const companyId = getCompanyId()
  if (!companyId) return
  serviceLoading.value = true
  try {
    const { from, to } = getRange(serviceRange.value)
    const { data } = await supabase
      .from('service_jobs')
      .select(
        `id, job_no, device_type, brand, model, serial_no,
         status, payment_status,
         total_estimated_cost, total_final_cost,
         received_date, completion_date, estimated_fix_date,
         issue_reported_by_customer, inspection_notes,
         technician_name, warranty_days,
         customer:customers(name, phone)`,
      )
      .eq('company_id', companyId)
      .gte('received_date', from)
      .lte('received_date', to)
      .order('received_date', { ascending: false })
    serviceJobs.value = (data || []).map((j) => ({
      ...j,
      customer_name: j.customer?.name || 'Walk-in',
      customer_phone: j.customer?.phone || '-',
    }))
  } finally {
    serviceLoading.value = false
  }
}

/* ─────────────────────────────────────────────
   FINANCE
───────────────────────────────────────────── */
const financeInvoices = ref([])
const financeLoading = ref(false)
const financeRange = ref('month')
const financeStatus = ref('')

function setFinanceRange(v) {
  financeRange.value = v
  loadFinance()
}

const financeStatusOpts = [
  { label: 'All', value: '' },
  { label: 'Paid', value: 'paid' },
  { label: 'Partial', value: 'partial' },
  { label: 'Unpaid', value: 'unpaid' },
]

const filteredFinance = computed(() => {
  if (!financeStatus.value) return financeInvoices.value
  return financeInvoices.value.filter((i) => i.payment_status === financeStatus.value)
})

const financeCols = [
  { name: 'invoice_no', label: 'Invoice #', field: 'invoice_no', align: 'left', sortable: true },
  {
    name: 'date',
    label: 'Date',
    field: (r) => r.created_at?.slice(0, 10) || '',
    align: 'center',
    sortable: true,
  },
  {
    name: 'customer',
    label: 'Customer',
    field: (r) => r.customer_snapshot?.name || 'Walk-in',
    align: 'left',
  },
  {
    name: 'total',
    label: 'Total',
    field: (r) =>
      'LKR ' + Number(r.total || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
    sortable: true,
  },
  {
    name: 'paid_amount',
    label: 'Paid',
    field: (r) =>
      'LKR ' + Number(r.paid_amount || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
  },
  {
    name: 'balance',
    label: 'Balance',
    field: (r) =>
      'LKR ' + Number(r.balance || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
    align: 'right',
    sortable: true,
  },
  { name: 'payment_type', label: 'Method', field: 'payment_type', align: 'center' },
  {
    name: 'payment_status',
    label: 'Status',
    field: 'payment_status',
    align: 'center',
    sortable: true,
  },
]

async function loadFinance() {
  if (!getCompanyId()) return
  financeLoading.value = true
  try {
    const { from, to } = getRange(financeRange.value)
    financeInvoices.value = await reportStore.fetchFinanceInvoices(from, to)
  } finally {
    financeLoading.value = false
  }
}

/* ─────────────────────────────────────────────
   Init
───────────────────────────────────────────── */
onMounted(() => {
  loadSuppliers()
  loadItems()
  loadDocs()
  loadService()
  loadFinance()
})
</script>

<style scoped>
.text-gradient {
  background: linear-gradient(135deg, #6366f1, #a855f7);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}
.stat-box {
  text-align: center;
  padding: 6px 14px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 10px;
  min-width: 100px;
}
.stat-val {
  font-size: 15px;
  font-weight: 800;
}
.stat-lbl {
  font-size: 10px;
  color: #9ca3af;
  text-transform: uppercase;
  letter-spacing: 0.6px;
}
</style>

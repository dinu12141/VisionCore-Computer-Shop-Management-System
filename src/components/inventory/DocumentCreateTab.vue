<template>
  <div class="q-pa-md">
    <!-- Header + Actions -->
    <div class="row items-center q-mb-md">
      <q-btn
        flat
        icon="arrow_back"
        label="Back to Documents"
        color="grey-5"
        @click="$emit('back')"
      />
      <q-space />
      <PostButton
        v-if="header.doc_type"
        :status="docStatus"
        :disabled="lines.length === 0"
        :saving="saving"
        :posting="posting"
        @save-draft="saveDraft"
        @post="onPost"
        @cancel="discardDraft"
        @cancel-posted="onCancelPosted"
      />
      <q-btn
        v-if="header.doc_type === 'PO' && header.id"
        color="indigo"
        icon="email"
        label="Email PO"
        class="q-ml-sm"
        @click="showEmailDialog = true"
      />
      <q-btn
        v-if="header.id"
        color="secondary"
        icon="print"
        label="Print"
        class="q-ml-sm"
        @click="showPrintDialog = true"
      />
      <q-btn
        v-if="header.id"
        color="accent"
        icon="download"
        label="Export"
        class="q-ml-sm"
        @click="showExportDialog = true"
      />
    </div>

    <!-- Step 1: Document Type Selection (ONLY for new) -->
    <div v-if="isNew && !header.doc_type" class="column items-center q-pa-xl">
      <div
        class="text-h4 text-weight-bolder q-mb-xl"
        :class="$q.dark.isActive ? 'text-white' : 'text-grey-9'"
      >
        Select Document Type
      </div>
      <div class="row q-col-gutter-lg justify-center" style="max-width: 900px">
        <div v-for="type in docTypeItems" :key="type.value" class="col-12 col-sm-6 col-md-4">
          <q-card
            class="cursor-pointer hover-card text-center q-pa-lg"
            :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
            flat
            bordered
            @click="header.doc_type = type.value"
          >
            <q-icon :name="type.icon" size="48px" :color="type.color" />
            <div class="text-h6 q-mt-md">{{ type.label }}</div>
            <div class="text-caption text-grey-5">{{ type.desc }}</div>
          </q-card>
        </div>
      </div>
    </div>

    <template v-else>
      <q-card
        v-if="isNew && header.doc_type === 'GRN' && !selectedPOId"
        :class="$q.dark.isActive ? 'bg-primary text-white' : 'bg-blue-1 text-blue-9'"
        class="q-mb-md"
        flat
        bordered
      >
        <q-card-section>
          <div class="row items-center q-gutter-md">
            <q-icon name="shopping_cart" size="32px" />
            <div>
              <div class="text-h6 text-weight-bold">Import from Purchase Order</div>
              <div class="text-caption">Select a posted PO to auto-fill items and supplier.</div>
            </div>
            <q-space />
            <q-select
              v-model="selectedPOId"
              :options="openPOOptions"
              label="Select Posted PO"
              :dark="$q.dark.isActive"
              outlined
              dense
              emit-value
              map-options
              style="min-width: 400px"
              @update:model-value="loadFromPO"
            >
              <template v-slot:no-option>
                <q-item>
                  <q-item-section class="text-grey"> No posted POs found </q-item-section>
                </q-item>
              </template>
            </q-select>
            <q-btn
              flat
              :color="$q.dark.isActive ? 'white' : 'blue-9'"
              icon="refresh"
              @click="refreshOpenPOs"
            />
          </div>
        </q-card-section>
      </q-card>

      <!-- Document Header -->
      <DocumentHeader
        v-model="header"
        :title="isNew ? 'New ' + header.doc_type : header.doc_number || 'Document'"
        :status="docStatus"
        :readonly="docStatus === 'posted' || docStatus === 'cancelled'"
        :show-doc-type="isNew"
        :warehouses="warehouses"
        :suppliers="suppliers"
      />

      <!-- Document Lines -->
      <DocumentLinesTable
        v-model="lines"
        :items="items"
        :doc-type="header.doc_type"
        :readonly="docStatus === 'posted' || docStatus === 'cancelled'"
      />
    </template>

    <!-- Financial Summary (SAP Style) -->
    <q-card
      v-if="header.doc_type"
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-grey-1 text-grey-9'"
      flat
      bordered
    >
      <q-card-section>
        <div class="row items-end">
          <div class="col-12 col-md-8">
            <div class="text-caption text-grey-5 q-mb-xs">Timeline & Audit</div>
            <div class="row q-gutter-md">
              <div v-if="docStatus === 'posted'">
                <span class="text-caption text-grey-5">Posted:</span>
                <span class="q-ml-xs text-weight-bold">{{ formatDateTime(header.posted_at) }}</span>
              </div>
              <div v-if="docStatus === 'cancelled'">
                <span class="text-caption text-grey-5 text-negative">Cancelled:</span>
                <span class="q-ml-xs">{{ formatDateTime(header.cancelled_at) }}</span>
              </div>
              <div>
                <span class="text-caption text-grey-5">Created By:</span>
                <span class="q-ml-xs">{{ header.created_by_name || 'Current User' }}</span>
              </div>
            </div>
          </div>

          <div class="col-12 col-md-4">
            <div class="column q-gutter-y-xs items-end">
              <div class="row full-width justify-between items-center no-wrap">
                <span class="text-grey-5 text-caption">Sub-Total</span>
                <span class="text-subtitle1">{{ formatCurrency(totals.sub) }}</span>
              </div>
              <div class="row full-width justify-between items-center no-wrap">
                <span class="text-grey-5 text-caption">Tax Total</span>
                <span class="text-subtitle1">{{ formatCurrency(totals.tax) }}</span>
              </div>
              <q-separator :dark="$q.dark.isActive" class="full-width q-my-xs" />
              <div
                class="row full-width justify-between items-center no-wrap text-primary text-h6 text-weight-bolder"
              >
                <span>Grand Total</span>
                <span>{{ formatCurrency(totals.grand) }}</span>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <SendEmailDialog v-model="showEmailDialog" :document="header" />
    <PrintPODialog v-model="showPrintDialog" :document="header" :lines="lines" />
    <ExportDocDialog v-model="showExportDialog" :document="header" :lines="lines" />
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useQuasar } from 'quasar'
import DocumentHeader from 'components/inventory/DocumentHeader.vue'
import DocumentLinesTable from 'components/inventory/DocumentLinesTable.vue'
import PostButton from 'components/inventory/PostButton.vue'
import SendEmailDialog from 'components/inventory/SendEmailDialog.vue'
import PrintPODialog from 'components/inventory/PrintPODialog.vue'
import ExportDocDialog from 'components/inventory/ExportDocDialog.vue'
import {
  createDocument,
  updateDraft,
  postDocument,
  cancelDocument,
  deleteDocument,
  fetchDocumentById,
  useWarehouseList,
  useSupplierList,
  useItemsList,
  useUomList,
  listOpenPOs,
} from 'src/services/inventoryService'
import { useAuthStore } from 'src/stores/auth'

function formatDateTime(val) {
  if (!val) return '-'
  const d = new Date(val)
  return (
    d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  )
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

const props = defineProps({
  document: { type: Object, default: null },
})

const emit = defineEmits(['back', 'saved'])
const $q = useQuasar()

const { warehouses, listWarehouses } = useWarehouseList()
const { suppliers, listSuppliers } = useSupplierList()
const { items, listItems } = useItemsList()
const { uoms, listUoms } = useUomList()

const authStore = useAuthStore()
const isAdmin = computed(() => authStore.isAdmin)

const saving = ref(false)
const posting = ref(false)
const showEmailDialog = ref(false)
const showPrintDialog = ref(false)
const showExportDialog = ref(false)

const openPOs = ref([])
const selectedPOId = ref(null)

const openPOOptions = computed(() => {
  console.log('Open POs:', openPOs.value)
  return openPOs.value.map((po) => ({
    label: `${po.doc_number} - ${po.supplier?.name || 'Unknown Supplier'}`,
    value: po.id,
    description: `Date: ${po.doc_date} | Total: ${formatCurrency(po.grand_total)}`,
  }))
})

const docTypeItems = [
  {
    label: 'Purchase Order',
    value: 'PO',
    icon: 'shopping_cart',
    color: 'indigo',
    desc: 'Order items from suppliers',
  },
  {
    label: 'Goods Receipt',
    value: 'GRN',
    icon: 'archive',
    color: 'green',
    desc: 'Receive items into stock',
  },
  {
    label: 'Goods Issue',
    value: 'GIN',
    icon: 'unarchive',
    color: 'red',
    desc: 'Issue items for kitchen/usage',
  },
  {
    label: 'Stock Transfer',
    value: 'TRANSFER',
    icon: 'swap_horiz',
    color: 'blue',
    desc: 'Move items between warehouses',
  },
  {
    label: 'Adjustment',
    value: 'ADJUSTMENT',
    icon: 'tune',
    color: 'orange',
    desc: 'Correction of stock levels',
  },
  {
    label: 'Stock Count',
    value: 'STOCK_COUNT',
    icon: 'fact_check',
    color: 'purple',
    desc: 'Physical inventory count',
  },
]

const isNew = computed(() => !props.document?.id)

const header = reactive({
  doc_type: props.document?.doc_type || '',
  doc_date: props.document?.doc_date || new Date().toISOString().split('T')[0],
  warehouse_id: props.document?.warehouse_id || '',
  target_warehouse_id: props.document?.target_warehouse_id || '',
  supplier_id: props.document?.supplier_id || '',
  reference_no: props.document?.reference_no || '',
  remarks: props.document?.remarks || '',
  doc_number: props.document?.doc_number || '',
  posted_at: props.document?.posted_at || '',
  cancelled_at: props.document?.cancelled_at || '',
  created_by_name: props.document?.created_by_name || '',
  status: props.document?.status || 'draft',
  id: props.document?.id || null,
  supplier_email: props.document?.supplier_email || '',
})

const docStatus = computed(() => header.status)

const totals = computed(() => {
  const subTotal = lines.value.reduce((s, l) => s + (Number(l.line_total) || 0), 0)
  const taxTotal = lines.value.reduce((s, l) => s + (Number(l.tax_amount) || 0), 0)
  return {
    sub: subTotal,
    tax: taxTotal,
    grand: subTotal + taxTotal,
  }
})

const lines = ref([])

watch(
  () => header.supplier_id,
  (newId) => {
    if (newId) {
      const s = suppliers.value.find((item) => item.id === newId)
      if (s) header.supplier_email = s.email
    } else {
      header.supplier_email = ''
    }
  },
)

// Auto-generate Ref No and load POs when Doc Type is selected
watch(
  () => header.doc_type,
  (newType) => {
    if (isNew.value && newType === 'GRN') {
      refreshOpenPOs()
    }

    if (isNew.value && newType && !header.reference_no) {
      const now = new Date()
      const yy = now.getFullYear().toString().slice(-2)
      const mm = (now.getMonth() + 1).toString().padStart(2, '0')
      const dd = now.getDate().toString().padStart(2, '0')
      const rand = Math.random().toString(36).substring(2, 6).toUpperCase()
      header.reference_no = `REF-${newType}-${yy}${mm}${dd}-${rand}`
    }
  },
)

onMounted(async () => {
  // Load reference data in parallel
  await Promise.all([listWarehouses(), listSuppliers(), listItems(), listUoms()])

  if (header.doc_type === 'GRN') {
    refreshOpenPOs()
  }

  // If editing existing document, fetch full lines
  if (props.document?.id) {
    try {
      const { header: h, lines: l } = await fetchDocumentById(props.document.id)
      Object.assign(header, h)
      lines.value = l.map((ln) => ({
        ...ln,
        item_id: ln.item_id,
        uom_id: ln.uom_id,
      }))
    } catch (e) {
      $q.notify({ type: 'negative', message: 'Failed to load document: ' + e.message })
    }
  }
})
async function refreshOpenPOs() {
  try {
    const pos = await listOpenPOs()
    console.log('Fetched Open POs:', pos)
    openPOs.value = pos
  } catch (e) {
    console.error('Failed to load open POs', e)
    $q.notify({ type: 'negative', message: 'Failed to load open POs' })
  }
}

async function loadFromPO(poId) {
  if (!poId) return

  $q.loading.show({ message: 'Fetching PO items...' })
  try {
    const { header: poHeader, lines: poLines } = await fetchDocumentById(poId)

    // 1. Auto-fill header
    if (poHeader.supplier_id) header.supplier_id = poHeader.supplier_id
    if (poHeader.warehouse_id) header.warehouse_id = poHeader.warehouse_id
    header.remarks = `Imported from PO: ${poHeader.doc_number}. ${poHeader.remarks || ''}`

    // 2. Load lines
    lines.value = poLines.map((ln) => ({
      ...ln,
      item_id: ln.item_id,
      uom_id: ln.uom_id,
      quantity: ln.quantity,
      unit_cost: ln.unit_cost,
    }))

    $q.notify({
      type: 'positive',
      message: `Loaded ${poLines.length} items from ${poHeader.doc_number}`,
    })
  } catch (e) {
    $q.notify({ type: 'negative', message: 'Failed to load PO details: ' + e.message })
  } finally {
    $q.loading.hide()
  }
}

function getDefaultUomId(itemId) {
  const item = items.value.find((i) => i.id === itemId)
  if (item?.inventory_uom_id) return item.inventory_uom_id
  if (item?.uom_id) return item.uom_id
  return uoms.value[0]?.id || null
}

function buildLinePayloads() {
  return lines.value.map((l) => ({
    item_id: l.item_id,
    uom_id: l.uom_id || getDefaultUomId(l.item_id),
    quantity: Number(l.quantity) || 0,
    unit_cost: Number(l.unit_cost) || 0,
    batch_no: l.batch_no || null,
    expiry_date: l.expiry_date || null,
    system_qty: l.system_qty ?? null,
    counted_qty: l.counted_qty ?? null,
    variance_qty: l.variance_qty ?? null,
    notes: l.notes || null,
    // SAP Fields
    tax_code: l.tax_code || null,
    tax_amount: Number(l.tax_amount) || 0,
    line_total: Number(l.line_total) || 0,
  }))
}

// Loosen for Draft — only need type and warehouse
function validateDraft() {
  if (!header.doc_type || !header.warehouse_id) {
    $q.notify({ type: 'warning', message: 'Please select document type and warehouse.' })
    return false
  }
  return true
}

// Strict for Post — must have items and valid quantities
function validatePost() {
  if (!validateDraft()) return false

  if (lines.value.length === 0) {
    $q.notify({ type: 'warning', message: 'Please add at least one line item before posting.' })
    return false
  }

  const invalid = lines.value.some((l) => !l.item_id || (Number(l.quantity) || 0) <= 0)
  if (invalid) {
    $q.notify({
      type: 'warning',
      message: 'All lines must have an item and positive quantity to post.',
    })
    return false
  }
  return true
}

async function saveDraft(isSilent = false, shouldEmit = true) {
  if (typeof isSilent !== 'boolean') isSilent = false
  if (!validateDraft()) return
  if (!isSilent) saving.value = true
  try {
    const payload = {
      ...header,
      sub_total: totals.value.sub,
      tax_total: totals.value.tax,
      grand_total: totals.value.grand,
    }

    const linePayloads = buildLinePayloads()

    if (isNew.value) {
      const doc = await createDocument(payload, linePayloads)
      header.id = doc.id
      header.doc_number = doc.doc_number
      header.status = 'draft'
      if (!isSilent) {
        $q.notify({ type: 'positive', message: `Draft saved as ${doc.doc_number}` })
      }
    } else {
      await updateDraft(header.id, payload, linePayloads)
      if (!isSilent) {
        $q.notify({ type: 'positive', message: 'Draft updated' })
      }
    }
    if (shouldEmit) emit('saved')
  } catch (e) {
    if (!isSilent) {
      $q.notify({ type: 'negative', message: e.message || 'Failed to save draft.' })
    }
    if (isSilent) throw e
  } finally {
    if (!isSilent) saving.value = false
  }
}

async function onPost() {
  if (!validatePost()) return

  posting.value = true
  try {
    // 1. Ensure document is saved (Create or Update)
    const payload = {
      ...header,
      sub_total: totals.value.sub,
      tax_total: totals.value.tax,
      grand_total: totals.value.grand,
    }
    const linePayloads = buildLinePayloads()

    if (!header.id) {
      // Create new
      const doc = await createDocument(payload, linePayloads)
      header.id = doc.id
      header.doc_number = doc.doc_number
      header.status = 'draft'
    } else {
      // Update existing
      await updateDraft(header.id, payload, linePayloads)
    }

    // 2. Now Post
    const doc = await postDocument(header.id)
    header.status = 'posted'
    header.posted_at = doc.posted_at || new Date().toISOString()

    $q.notify({
      type: 'positive',
      message: 'Document posted successfully',
      icon: 'verified',
    })
    emit('saved')
  } catch (e) {
    if (e.message?.includes('Posted')) {
      // Edge case: already posted
      emit('saved')
      return
    }
    $q.notify({ type: 'negative', message: e.message || 'Post failed.' })
  } finally {
    posting.value = false
  }
}

async function onCancelPosted() {
  try {
    const doc = await cancelDocument(header.id)
    header.status = 'cancelled'
    header.cancelled_at = doc.cancelled_at || new Date().toISOString()
    $q.notify({
      type: 'info',
      message: 'Document cancelled. Stock levels reversed.',
      icon: 'undo',
    })
    emit('saved')
  } catch (e) {
    $q.notify({ type: 'negative', message: e.message || 'Cancel failed.' })
  }
}

async function discardDraft() {
  if (header.id && !isNew.value) {
    if (!isAdmin.value) {
      $q.notify({ type: 'negative', message: 'Only administrators can delete documents.' })
      return
    }
    try {
      await deleteDocument(header.id)
      $q.notify({ type: 'info', message: 'Draft document deleted.' })
    } catch (e) {
      $q.notify({ type: 'negative', message: e.message || 'Failed to delete draft.' })
      return
    }
  }
  emit('back')
}
</script>
<style scoped>
.hover-card {
  transition: all 0.3s ease;
}
.hover-card:hover {
  transform: translateY(-5px);
  border-color: var(--q-primary);
  background: v-bind("$q.dark.isActive ? '#2a2a2a' : '#f5f5f5'");
}
</style>

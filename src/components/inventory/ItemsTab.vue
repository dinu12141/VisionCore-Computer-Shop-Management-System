<template>
  <div class="q-pa-md">
    <!-- Toolbar -->
    <div class="row items-center q-mb-md q-gutter-sm">
      <q-input
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="filter"
        placeholder="Search items..."
        style="min-width: 250px"
      >
        <template #prepend><q-icon name="search" /></template>
      </q-input>
      <q-select
        :dark="$q.dark.isActive"
        outlined
        dense
        v-model="categoryFilter"
        :options="categoryOptions"
        label="Category"
        emit-value
        map-options
        clearable
        style="min-width: 180px"
      />
      <q-space />
      <q-btn color="primary" icon="add" label="Add Item" @click="openCreate" />
    </div>

    <!-- Items Table -->
    <DataTable
      title="Stock Items"
      :rows="filteredItems"
      :columns="columns"
      filter=""
      :loading="loading"
    >
      <template #body-cell-cost_price="props">
        <q-td :props="props">
          <div class="text-weight-bold text-primary">{{ formatCurrency(props.value) }}</div>
        </q-td>
      </template>

      <template #body-cell-sale_price="props">
        <q-td :props="props">
          <div class="text-weight-bold text-secondary">{{ formatCurrency(props.value) }}</div>
        </q-td>
      </template>

      <template #body-cell-serials="props">
        <q-td :props="props">
          <div v-if="props.value && props.value.length">
            <q-badge
              v-for="(s, idx) in props.value.slice(0, 3)"
              :key="idx"
              color="grey-2"
              text-color="grey-9"
              class="q-mr-xs q-mb-xs"
            >
              {{ s }}
            </q-badge>
            <q-badge v-if="props.value.length > 3" color="blue-1" text-color="blue-9">
              +{{ props.value.length - 3 }} more
            </q-badge>
          </div>
          <div v-else class="text-grey-5 font-italic">No serials</div>
        </q-td>
      </template>

      <!-- Total Qty Cell -->
      <template #body-cell-total_qty="props">
        <q-td :props="props" class="text-right">
          <q-badge
            :color="
              props.value <= 0
                ? 'negative'
                : props.value <= props.row.reorder_level
                  ? 'warning'
                  : 'positive'
            "
            class="text-weight-bold"
          >
            {{ props.value }}
          </q-badge>
          <span class="text-caption text-grey-5 q-ml-xs">{{ props.row.uom_code }}</span>
        </q-td>
      </template>

      <!-- Status Cell -->
      <template #body-cell-is_active="props">
        <q-td :props="props">
          <q-badge
            :color="props.value ? 'green' : 'grey'"
            :label="props.value ? 'Active' : 'Inactive'"
          />
        </q-td>
      </template>

      <template #body-cell-actions="props">
        <q-td :props="props" class="q-gutter-xs">
          <q-btn
            flat
            round
            dense
            color="orange"
            icon="inventory_2"
            @click="openAdjustment(props.row)"
          >
            <q-tooltip>Quick Adjustment</q-tooltip>
          </q-btn>
          <q-btn flat round dense color="primary" icon="edit" @click="editItem(props.row)">
            <q-tooltip>Edit item</q-tooltip>
          </q-btn>
          <q-btn flat round dense color="negative" icon="delete" @click="deleteItem(props.row)">
            <q-tooltip>Deactivate item</q-tooltip>
          </q-btn>
        </q-td>
      </template>
    </DataTable>

    <!-- Quick Adjustment Dialog -->
    <q-dialog v-model="showAdjustDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <div class="text-h6">
            <q-icon name="tune" color="orange" size="24px" class="q-mr-sm" />
            Stock Adjustment: {{ adjustItem?.name }}
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-none">
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-select
                v-model="adjustForm.warehouse_id"
                :options="warehouseOptions"
                label="Warehouse"
                outlined
                dense
                emit-value
                map-options
              />
            </div>
            <div class="col-12">
              <q-input
                v-model.number="adjustForm.quantity"
                type="number"
                label="Quantity Change"
                hint="Positive to add, negative to remove"
                outlined
                dense
                autofocus
              />
            </div>
            <div class="col-12">
              <q-input
                v-model="adjustForm.remarks"
                label="Remarks"
                outlined
                dense
                placeholder="Reason for adjustment"
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="text-primary">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="orange"
            label="Post Adjustment"
            :loading="adjusting"
            @click="postAdjustment"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Add/Edit Product & Serials Dialog -->
    <q-dialog v-model="showDialog" persistent backdrop-filter="blur(4px)">
      <q-card
        style="width: 850px; max-width: 95vw; border-radius: 8px"
        :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      >
        <q-card-section class="row items-center q-pb-none">
          <div class="column">
            <div class="text-h6 text-weight-medium">Add Product & Serials</div>
            <div class="text-caption text-grey-7">Product Name</div>
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator class="q-my-sm" />

        <q-card-section class="q-pa-md">
          <div class="row q-col-gutter-md">
            <!-- Brand, Model and Warranty -->
            <div class="col-4">
              <q-input :dark="$q.dark.isActive" outlined v-model="form.brand" label="Brand" dense />
            </div>
            <div class="col-4">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.model_number"
                label="Model Number"
                dense
              />
            </div>
            <div class="col-4">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.warranty"
                label="Warranty"
                placeholder="e.g. 1 Year, 6 Months"
                dense
              />
            </div>

            <!-- Prices and Attributes -->
            <div class="col-12">
              <div class="text-subtitle2 q-mb-xs text-grey-8">Prices & Category</div>
              <div class="row q-col-gutter-sm">
                <div class="col-3">
                  <div class="row items-center no-wrap">
                    <div class="col">
                      <q-select
                        :dark="$q.dark.isActive"
                        outlined
                        dense
                        v-model="form.category_id"
                        :options="categoryOptions"
                        label="Category"
                        emit-value
                        map-options
                      />
                    </div>
                    <div class="col-auto q-ml-sm">
                      <q-btn flat round dense color="primary" icon="add" @click="promptAddCategory">
                        <q-tooltip>Add New Category</q-tooltip>
                      </q-btn>
                    </div>
                  </div>
                </div>
                <div class="col-3">
                  <q-select
                    :dark="$q.dark.isActive"
                    outlined
                    dense
                    v-model="form.inventory_uom_id"
                    :options="uomOptions"
                    label="Unit (UOM)"
                    emit-value
                    map-options
                  />
                </div>
                <div class="col-3">
                  <q-input
                    :dark="$q.dark.isActive"
                    outlined
                    dense
                    v-model.number="form.cost_price"
                    label="Cost Price (LKR)"
                    type="number"
                    prefix="Rs. "
                  />
                </div>
                <div class="col-3">
                  <q-input
                    :dark="$q.dark.isActive"
                    outlined
                    dense
                    v-model.number="form.sale_price"
                    label="Selling Price (LKR)"
                    type="number"
                    prefix="Rs. "
                  />
                </div>
              </div>
            </div>

            <!-- Attribute Boxes -->
            <div class="col-3">
              <div class="attribute-box q-pa-sm border-grey">
                <div class="text-caption text-weight-bold q-mb-xs">Quick Attributes</div>
                <q-checkbox dense v-model="form.attrs" val="RAM" label="RAM" class="full-width" />
                <q-checkbox
                  dense
                  v-model="form.attrs"
                  val="Motherboard"
                  label="Motherboards GPU"
                  class="full-width"
                />
                <q-checkbox dense v-model="form.attrs" val="SSD" label="SSD" class="full-width" />
              </div>
            </div>
            <div class="col-6">
              <div class="attribute-box q-pa-sm border-grey">
                <div class="text-caption text-weight-bold q-mb-sm text-primary">
                  <q-icon name="inventory_2" class="q-mr-xs" />
                  Stock Control
                </div>
                <div class="row q-col-gutter-sm">
                  <div class="col-6">
                    <q-input
                      v-model.number="form.reorder_level"
                      type="number"
                      label="Reorder Level"
                      hint="Low stock alert level"
                      dense
                      outlined
                      :dark="$q.dark.isActive"
                    />
                  </div>
                  <div class="col-6" v-if="!editingItem">
                    <q-input
                      v-model.number="form.initial_stock"
                      type="number"
                      label="Opening Qty"
                      hint="Initial stock on hand"
                      dense
                      outlined
                      :dark="$q.dark.isActive"
                    />
                  </div>
                  <div class="col-12" v-if="!editingItem && form.initial_stock > 0">
                    <q-select
                      v-model="form.initial_warehouse_id"
                      :options="warehouseOptions"
                      label="Initial Warehouse"
                      dense
                      outlined
                      emit-value
                      map-options
                      :dark="$q.dark.isActive"
                      :rules="[(val) => !!val || 'Required for opening stock']"
                    />
                  </div>
                </div>
              </div>
            </div>

            <!-- Serial Numbers Section -->
            <div class="col-12 q-mt-md">
              <div class="text-subtitle2 text-weight-bold">Serial Numbers</div>
              <div class="text-caption text-grey-7 q-mb-sm">
                Enter each serial numbers separately
              </div>

              <div class="row items-center q-gutter-sm">
                <div class="col">
                  <q-input
                    :dark="$q.dark.isActive"
                    outlined
                    dense
                    v-model="serialInput"
                    placeholder="Scan barcode or type serial number..."
                    ref="serialInputRef"
                    @keydown.enter.prevent="addSerial"
                  >
                    <template #prepend>
                      <q-icon name="qr_code_scanner" color="primary" />
                    </template>
                  </q-input>
                  <div class="text-caption text-grey-6 q-mt-xs">
                    Scan barcode to auto-add, or paste a list and click Add
                  </div>
                </div>
                <div class="column q-gutter-xs">
                  <q-btn
                    unelevated
                    label="Add"
                    color="primary"
                    class="text-weight-bold no-caps"
                    @click="addSerial"
                  />
                  <q-file
                    v-model="serialFile"
                    style="display: none"
                    ref="serialFileRef"
                    @update:model-value="handleSerialFileUpload"
                    accept=".csv, .txt, .xlsx, .xls"
                  />
                  <q-btn
                    unelevated
                    icon="upload_file"
                    color="grey-2"
                    text-color="grey-9"
                    class="no-caps"
                    @click="$refs.serialFileRef.pickFiles()"
                  >
                    <q-tooltip>Upload Excel/CSV/Text</q-tooltip>
                  </q-btn>
                </div>
              </div>

              <div
                class="serials-container q-mt-sm q-pa-sm bg-grey-1"
                style="min-height: 50px; border: 1px solid #ddd; border-radius: 4px"
              >
                <q-chip
                  v-for="(s, idx) in form.serials"
                  :key="idx"
                  removable
                  @remove="removeSerial(idx)"
                  size="sm"
                  color="grey-3"
                  text-color="grey-9"
                  square
                >
                  {{ s }}
                </q-chip>
                <div v-if="form.serials.length === 0" class="text-caption text-grey-5 q-pa-xs">
                  No serials added yet...
                </div>
              </div>
            </div>
          </div>
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md q-gutter-sm">
          <q-btn
            flat
            label="Cancel"
            v-close-popup
            class="text-weight-bold no-caps"
            style="color: #424242"
          />
          <q-btn
            unelevated
            color="primary"
            :label="editingItem ? 'Update' : 'Save'"
            icon="save"
            :loading="saving"
            @click="saveItem"
            class="no-caps q-px-lg"
            style="border-radius: 8px"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup>
import { ref, computed, reactive, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { useQuasar } from 'quasar'
import DataTable from 'components/common/DataTable.vue'
import {
  useItemsList,
  useCategoryList,
  useUomList,
  useWarehouseList,
  createDocument,
  postDocument,
} from 'src/services/inventoryService'
import * as XLSX from 'xlsx'
import { useAuthStore } from 'src/stores/auth'
const $q = useQuasar()
const authStore = useAuthStore()

const {
  items,
  loading,
  listItems,
  createItem,
  updateItem,
  deleteItem: trueDelete,
  generateNextItemCode,
} = useItemsList()
const { categories, listCategories, createCategory } = useCategoryList()
const { uoms, listUoms } = useUomList()
const { warehouses, listWarehouses } = useWarehouseList()

const filter = ref('')
const categoryFilter = ref('')

// Dialog States
const showDialog = ref(false)
const editingItem = ref(null)
const saving = ref(false)

const showAdjustDialog = ref(false)
const adjusting = ref(false)
const adjustItem = ref(null)
const adjustForm = reactive({
  warehouse_id: null,
  quantity: 0,
  remarks: '',
})

const serialInput = ref('')
const serialFile = ref(null)
const serialFileRef = ref(null)
const serialInputRef = ref(null)

const emptyForm = {
  code: '',
  name: '',
  category_id: null,
  inventory_uom_id: null,
  avg_cost: 0,
  reorder_level: 0,
  last_purchase_price: 0,
  brand: '',
  model_number: '',
  cost_price: 0,
  sale_price: 0,
  attrs: [],
  serials: [],
  warranty: '',
  initial_stock: 0,
  initial_warehouse_id: null,
}

const form = reactive({ ...emptyForm })

// Watch for auth context to become available (handles the race condition)
watch(
  () => authStore.currentBranch?.company_id,
  (companyId) => {
    if (companyId) {
      listItems()
      listCategories()
      listUoms()
      listWarehouses()
    }
  },
  { immediate: true },
)

// Global barcode scanner listener
let barcodeBuffer = ''
let barcodeTimer = null

function handleGlobalBarcodeScan(e) {
  // Ignore if user is already typing in an input/textarea/select
  const activeTag = document.activeElement?.tagName?.toLowerCase()
  if (['input', 'textarea', 'select'].includes(activeTag)) return

  if (e.key === 'Enter') {
    if (barcodeBuffer.length >= 3) {
      filter.value = barcodeBuffer // Auto-search the scanned barcode
    }
    barcodeBuffer = ''
  } else if (e.key.length === 1) {
    barcodeBuffer += e.key
    clearTimeout(barcodeTimer)
    barcodeTimer = setTimeout(() => {
      barcodeBuffer = ''
    }, 50) // Barcode keystrokes are very fast
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleGlobalBarcodeScan)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleGlobalBarcodeScan)
})

// Sync initial stock with serials length
watch(
  () => form.serials.length,
  (newLen) => {
    if (!editingItem.value) {
      // Only auto-update if initial_stock is currently 0 or less than serial count
      // This allows user to specify higher opening stock than serials, but not lower
      form.initial_stock = Math.max(form.initial_stock, newLen)
    }
  },
)

function promptAddCategory() {
  $q.dialog({
    title: 'Add Category',
    message: 'Enter the name for the new category:',
    prompt: {
      model: '',
      type: 'text',
      outlined: true,
      dense: true,
    },
    cancel: true,
    persistent: true,
  }).onOk(async (data) => {
    if (data && data.trim()) {
      try {
        const newCat = await createCategory(data.trim())
        form.category_id = newCat.id
        $q.notify({ type: 'positive', message: 'Category added' })
      } catch (err) {
        $q.notify({ type: 'negative', message: err.message || 'Failed to add category' })
      }
    }
  })
}

function addSerial() {
  const text = serialInput.value.trim()
  if (!text) return

  // Split by common delimiters: space, comma, semicolon, newline, tab
  const entries = text.split(/[\s,;\n\t]+/)

  let addedCount = 0
  let duplicateCount = 0
  entries.forEach((s) => {
    const cleanSerial = s.trim()
    if (cleanSerial && !form.serials.includes(cleanSerial)) {
      form.serials.push(cleanSerial)
      addedCount++
    } else if (cleanSerial && form.serials.includes(cleanSerial)) {
      duplicateCount++
    }
  })

  if (addedCount > 0) {
    $q.notify({
      type: 'positive',
      message: `${addedCount} serial${addedCount > 1 ? 's' : ''} added.`,
      timeout: 1000,
    })
  }
  if (duplicateCount > 0) {
    $q.notify({
      type: 'warning',
      message: `${duplicateCount} duplicate serial${duplicateCount > 1 ? 's' : ''} skipped.`,
      timeout: 1500,
    })
  }

  serialInput.value = ''

  // Refocus input for next scan
  nextTick(() => {
    serialInputRef.value?.focus()
  })
}

async function handleSerialFileUpload(file) {
  if (!file) return

  try {
    const reader = new FileReader()

    if (file.name.endsWith('.xlsx') || file.name.endsWith('.xls')) {
      reader.onload = (e) => {
        const data = new Uint8Array(e.target.result)
        const workbook = XLSX.read(data, { type: 'array' })
        const firstSheetName = workbook.SheetNames[0]
        const worksheet = workbook.Sheets[firstSheetName]
        const json = XLSX.utils.sheet_to_json(worksheet, { header: 1 })

        const serialsFromFile = json
          .flat()
          .filter((s) => s && String(s).trim())
          .map((s) => String(s).trim())
        addBatchSerials(serialsFromFile)
      }
      reader.readAsArrayBuffer(file)
    } else {
      reader.onload = (e) => {
        const text = e.target.result
        const serialsFromFile = text.split(/[\s,;\n\t]+/).filter((s) => s.trim())
        addBatchSerials(serialsFromFile)
      }
      reader.readAsText(file)
    }
  } catch (err) {
    console.error('File read error:', err)
    $q.notify({ type: 'negative', message: 'Error reading file.' })
  } finally {
    serialFile.value = null
  }
}

function addBatchSerials(list) {
  let addedCount = 0
  list.forEach((s) => {
    const cleanSerial = s.trim()
    if (cleanSerial && !form.serials.includes(cleanSerial)) {
      form.serials.push(cleanSerial)
      addedCount++
    }
  })

  if (addedCount > 0) {
    $q.notify({
      type: 'positive',
      message: `${addedCount} serial numbers added from file.`,
    })
  } else {
    $q.notify({
      type: 'info',
      message: 'No new serial numbers found in file.',
    })
  }
}

function removeSerial(idx) {
  form.serials.splice(idx, 1)
}

const categoryOptions = computed(() =>
  categories.value.map((c) => ({ label: c.name, value: c.id })),
)

const uomOptions = computed(() => uoms.value.map((u) => ({ label: u.name || u.code, value: u.id })))

const warehouseOptions = computed(() =>
  warehouses.value.map((w) => ({ label: w.name, value: w.id })),
)

const filteredItems = computed(() => {
  let result = items.value

  // Category filter
  if (categoryFilter.value) {
    result = result.filter((i) => i.category_id === categoryFilter.value)
  }

  // Text search filter
  if (filter.value) {
    const q = filter.value.toLowerCase()
    result = result.filter((i) => {
      const code = (i.code || '').toLowerCase()
      const name = (i.name || '').toLowerCase()
      const category = (i.category_name || '').toLowerCase()
      const brand = (i.brand || '').toLowerCase()
      const model = (i.model_number || '').toLowerCase()

      // Check serial numbers (which is a JSONB array)
      const serialsMatch =
        Array.isArray(i.serials) && i.serials.some((s) => String(s).toLowerCase().includes(q))

      return (
        code.includes(q) ||
        name.includes(q) ||
        category.includes(q) ||
        brand.includes(q) ||
        model.includes(q) ||
        serialsMatch
      )
    })
  }

  return result
})

const columns = [
  {
    name: 'code',
    label: 'Code',
    field: 'code',
    align: 'left',
    sortable: true,
  },
  { name: 'name', label: 'Item Name', field: 'name', align: 'left', sortable: true },
  {
    name: 'category_name',
    label: 'Category',
    field: 'category_name',
    align: 'left',
    sortable: true,
  },
  { name: 'uom_code', label: 'UOM', field: 'uom_code', align: 'center' },
  {
    name: 'total_qty',
    label: 'Stock Count',
    field: 'total_qty',
    align: 'right',
    sortable: true,
  },
  {
    name: 'cost_price',
    label: 'Cost Price',
    field: 'cost_price',
    align: 'right',
    sortable: true,
  },
  {
    name: 'sale_price',
    label: 'Sale Price',
    field: 'sale_price',
    align: 'right',
    sortable: true,
  },
  {
    name: 'serials',
    label: 'Serials',
    field: 'serials',
    align: 'left',
    style: 'max-width: 200px; white-space: normal;',
  },
  {
    name: 'reorder_level',
    label: 'Min Stock',
    field: 'reorder_level',
    align: 'center',
    sortable: true,
  },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

function openAdjustment(row) {
  adjustItem.value = row
  adjustForm.warehouse_id = warehouses.value[0]?.id || null
  adjustForm.quantity = 0
  adjustForm.remarks = 'Manual adjustment from registry'
  showAdjustDialog.value = true
}

async function postAdjustment() {
  if (!adjustForm.warehouse_id || !adjustForm.quantity) {
    $q.notify({ type: 'warning', message: 'Warehouse and Quantity are required.' })
    return
  }

  adjusting.value = true
  try {
    const docHeader = {
      doc_type: 'ADJUSTMENT',
      doc_date: new Date().toISOString().split('T')[0],
      warehouse_id: adjustForm.warehouse_id,
      remarks: adjustForm.remarks,
    }

    const docLines = [
      {
        item_id: adjustItem.value.id,
        uom_id: adjustItem.value.inventory_uom_id || adjustItem.value.uom_id,
        quantity: adjustForm.quantity,
        unit_cost: adjustItem.value.cost_price || 0,
      },
    ]

    const doc = await createDocument(docHeader, docLines)
    await postDocument(doc.id)

    $q.notify({
      type: 'positive',
      message: `Stock adjusted by ${adjustForm.quantity}`,
      icon: 'inventory_2',
    })
    showAdjustDialog.value = false
    await listItems()
  } catch (e) {
    $q.notify({ type: 'negative', message: e.message || 'Adjustment failed.' })
  } finally {
    adjusting.value = false
  }
}

function editItem(item) {
  editingItem.value = item
  Object.assign(form, { ...emptyForm, ...item })
  showDialog.value = true
}

async function deleteItem(item) {
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to PERMANENTLY delete ${item.name}? This action cannot be undone.`,
    cancel: true,
    persistent: true,
    ok: { color: 'negative', label: 'Delete' },
  }).onOk(async () => {
    try {
      await trueDelete(item.id)
      $q.notify({ type: 'positive', message: 'Product deleted successfully', icon: 'delete' })
      // No need for listItems() here as service handles state
    } catch (e) {
      console.error('Delete error:', e)
      const errorMsg = e.message || e.details || 'Failed to delete product.'
      const isFkey =
        errorMsg.toLowerCase().includes('foreign key') ||
        errorMsg.toLowerCase().includes('violates foreign key')

      const msg = isFkey
        ? `Cannot delete item: ${errorMsg}. Try deactivating it instead to preserve transaction history.`
        : `Failed to delete product: ${errorMsg}`

      $q.notify({
        type: 'negative',
        message: msg,
        actions: [{ label: 'Dismiss', color: 'white' }],
      })
    }
  })
}

async function openCreate() {
  editingItem.value = null
  Object.assign(form, emptyForm)
  form.serials = []
  form.attrs = []
  showDialog.value = true
  try {
    const nextCode = await generateNextItemCode()
    if (nextCode) form.code = nextCode

    // Auto-select first warehouse if available
    if (warehouses.value.length > 0) {
      form.initial_warehouse_id = warehouses.value[0].id
    }
  } catch (e) {
    console.error('Auto-gen code error:', e)
  }
}

async function saveItem() {
  if (!form.name && !form.brand) {
    $q.notify({ type: 'warning', message: 'Brand or Product Name is required.' })
    return
  }
  saving.value = true
  try {
    if (!form.name) form.name = `${form.brand} ${form.model_number}`.trim()
    if (editingItem.value) {
      const updatePayload = { ...form }
      delete updatePayload.initial_stock
      delete updatePayload.initial_warehouse_id
      await updateItem(editingItem.value.id, updatePayload)
      $q.notify({ type: 'positive', message: 'Product updated!' })
    } else {
      // Create a clean payload for the DB
      const itemPayload = { ...form }
      const openingStock = itemPayload.initial_stock
      const openingWarehouseId = itemPayload.initial_warehouse_id
      delete itemPayload.initial_stock
      delete itemPayload.initial_warehouse_id

      const newItem = await createItem({ ...itemPayload, is_active: true })

      // Handle Initial Stock if provided
      if (openingStock > 0 && openingWarehouseId) {
        try {
          // If the item has serials, the trigger 'trg_sync_serials' already sets stock = serials.length
          // We only need to adjust for the 'extra' non-serialized stock.
          const serialCount = form.serials?.length || 0
          const adjustmentQty = openingStock - serialCount

          if (adjustmentQty <= 0) {
            $q.notify({
              type: 'positive',
              message: `Opening stock of ${openingStock} initialized from serial numbers.`,
              icon: 'qr_code',
            })
          } else {
            const docHeader = {
              doc_type: 'ADJUSTMENT',
              doc_date: new Date().toISOString().split('T')[0],
              warehouse_id: openingWarehouseId,
              remarks: `Opening stock for new item: ${newItem.name} (Non-serialized portion)`,
            }

            const docLines = [
              {
                item_id: newItem.id,
                uom_id: newItem.inventory_uom_id || form.inventory_uom_id,
                quantity: adjustmentQty,
                unit_cost: form.cost_price || 0,
              },
            ]

            const doc = await createDocument(docHeader, docLines)
            await postDocument(doc.id)

            $q.notify({
              type: 'positive',
              message: `Added ${adjustmentQty} units as non-serialized opening stock.`,
              icon: 'inventory_2',
            })
          }
        } catch (err) {
          console.error('Failed to create opening stock document:', err)
          $q.notify({
            type: 'warning',
            message: 'Item created, but failed to add opening stock document.',
          })
        }
      }

      $q.notify({ type: 'positive', message: 'Product created!' })
    }
    showDialog.value = false
  } catch (e) {
    $q.notify({ type: 'negative', message: e.message || 'Failed to save product.' })
  } finally {
    saving.value = false
    await listItems() // Refresh list to see updated stock if any
  }
}

function formatCurrency(val) {
  const num = Number(val)
  if (isNaN(num)) return 'LKR 0.00'
  return 'LKR ' + num.toLocaleString(undefined, { minimumFractionDigits: 2 })
}
</script>

<style scoped>
.attribute-box {
  border: 1px solid #ddd;
  border-radius: 4px;
  height: 100%;
}
.border-grey {
  border: 1px solid #ddd;
}
.serials-container {
  max-height: 120px;
  overflow-y: auto;
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
</style>

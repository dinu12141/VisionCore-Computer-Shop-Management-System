<template>
  <div class="invoice-items-container">
    <q-table
      :rows="items"
      :columns="columns"
      flat
      dense
      hide-bottom
      :pagination="{ rowsPerPage: 0 }"
      separator="horizontal"
      class="invoice-table"
    >
      <template v-slot:body-cell-description="props">
        <q-td :props="props">
          <q-select
            v-model="props.row.description"
            use-input
            hide-selected
            fill-input
            input-debounce="300"
            :options="itemOptions"
            @filter="filterItems"
            @update:model-value="(val) => onItemSelected(val, props.row)"
            @input-value="
              (val) => {
                if (val) props.row.description = val
              }
            "
            @new-value="
              (val, done) => {
                props.row.description = val
                done(val, 'toggle')
              }
            "
            placeholder="Search item or type description..."
            dense
            outlined
            class="full-width"
          >
            <template v-slot:no-option>
              <q-item>
                <q-item-section class="text-grey">
                  No items found. Type to add custom description.
                </q-item-section>
              </q-item>
            </template>
            <template v-slot:option="scope">
              <q-item v-bind="scope.itemProps">
                <q-item-section>
                  <q-item-label>{{ scope.opt.name }}</q-item-label>
                  <q-item-label caption>
                    Code: {{ scope.opt.code }} | Price: {{ formatCurrency(scope.opt.sale_price) }}
                  </q-item-label>
                </q-item-section>
              </q-item>
            </template>
          </q-select>
        </q-td>
      </template>

      <template v-slot:body-cell-serial_number="props">
        <q-td :props="props">
          <q-input
            v-model="props.row.serial_number"
            dense
            outlined
            placeholder="Serial No"
            style="width: 140px"
            @keyup.enter="findItemBySerial(props.row)"
          />
        </q-td>
      </template>
      <template v-slot:body-cell-warranty="props">
        <q-td :props="props">
          <q-input
            v-model="props.row.warranty"
            dense
            outlined
            placeholder="e.g. 1 Year"
            style="width: 120px"
          />
        </q-td>
      </template>

      <template v-slot:body-cell-qty="props">
        <q-td :props="props">
          <q-input
            v-model.number="props.row.qty"
            type="number"
            dense
            outlined
            style="width: 80px"
            @wheel.prevent
            @update:model-value="calculateLine(props.row)"
          />
        </q-td>
      </template>

      <template v-slot:body-cell-unit_price="props">
        <q-td :props="props">
          <q-input
            v-model.number="props.row.unit_price"
            type="number"
            dense
            outlined
            prefix="Rs."
            style="width: 120px"
            @wheel.prevent
            @update:model-value="calculateLine(props.row)"
          />
        </q-td>
      </template>

      <template v-slot:body-cell-discount="props">
        <q-td :props="props">
          <div class="row items-center no-wrap" style="gap: 4px">
            <q-input
              v-model.number="props.row.discount"
              type="number"
              dense
              outlined
              style="width: 80px"
              :suffix="props.row.discount_type === 'percent' ? '%' : ''"
              :prefix="props.row.discount_type === 'amount' ? 'Rs.' : ''"
              @wheel.prevent
              @update:model-value="calculateLine(props.row)"
            />
            <q-btn
              flat
              dense
              round
              size="xs"
              :icon="props.row.discount_type === 'percent' ? 'percent' : 'payments'"
              :color="props.row.discount_type === 'percent' ? 'deep-orange' : 'primary'"
              @click="toggleDiscountType(props.row)"
            >
              <q-tooltip>Switch to {{ props.row.discount_type === 'percent' ? 'Amount (Rs.)' : 'Percentage (%)' }}</q-tooltip>
            </q-btn>
          </div>
        </q-td>
      </template>

      <template v-slot:body-cell-line_total="props">
        <q-td :props="props" align="right">
          <div class="text-weight-bold">{{ formatCurrency(props.row.line_total) }}</div>
          <div v-if="props.row.discount > 0" class="text-caption text-negative" style="font-size: 10px; line-height: 1.2">
            -{{ props.row.discount_type === 'percent' ? props.row.discount + '%' : formatCurrency(props.row.discount) }} off
          </div>
        </q-td>
      </template>

      <template v-slot:body-cell-actions="props">
        <q-td :props="props" align="center">
          <q-btn
            flat
            dense
            round
            icon="delete"
            color="negative"
            @click="removeItem(props.rowIndex)"
          >
            <q-tooltip>Remove Row</q-tooltip>
          </q-btn>
        </q-td>
      </template>
    </q-table>

    <div class="row q-pa-sm">
      <q-btn
        flat
        color="primary"
        icon="add_circle"
        label="Add Line Item"
        @click="addItem"
        class="text-weight-bold"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { useQuasar } from 'quasar'
import { useItemsList } from 'src/services/inventoryService'

const $q = useQuasar()

const props = defineProps({
  items: { type: Array, required: true },
})

const emit = defineEmits(['update:items'])

const { items: inventoryItems, listItems } = useItemsList()
const itemOptions = ref([])

onMounted(async () => {
  await listItems()
  window.addEventListener('keydown', handleGlobalBarcodeScan)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleGlobalBarcodeScan)
})

const columns = [
  { name: 'description', label: 'Item / Description', align: 'left', field: 'description' },
  { name: 'serial_number', label: 'Serial No', align: 'left', field: 'serial_number' },
  { name: 'warranty', label: 'Warranty', align: 'left', field: 'warranty' },
  { name: 'qty', label: 'Quantity', align: 'left', field: 'qty' },
  { name: 'unit_price', label: 'Unit Price', align: 'left', field: 'unit_price' },
  { name: 'discount', label: 'Discount', align: 'left', field: 'discount', style: 'min-width: 140px' },
  { name: 'line_total', label: 'Total', align: 'right', field: 'line_total' },
  { name: 'actions', label: '', align: 'center' },
]

function filterItems(val, update) {
  if (val === '') {
    update(() => {
      itemOptions.value = inventoryItems.value
    })
    return
  }

  update(() => {
    const needle = val.toLowerCase()
    itemOptions.value = inventoryItems.value.filter(
      (v) => v.name.toLowerCase().indexOf(needle) > -1 || v.code.toLowerCase().indexOf(needle) > -1,
    )
  })
}

function onItemSelected(val, row) {
  if (typeof val === 'object' && val !== null) {
    row.product_id = val.id
    row.description = val.name
    row.item_code = val.code
    row.unit_price = val.sale_price || val.selling_price || 0
    row.cost_price = val.cost_price || val.avg_cost || 0
    row.warranty = val.warranty || ''
    if (!row.discount_type) row.discount_type = 'amount'
    calculateLine(row)
  }
}

async function findItemBySerial(row) {
  const sn = (row.serial_number || '').trim()
  if (!sn) return

  const needle = sn.toLowerCase()
  const match = inventoryItems.value.find((item) => {
    const code = (item.code || '').toLowerCase()
    const serials = Array.isArray(item.serials) ? item.serials : []
    return code === needle || serials.some((s) => String(s).toLowerCase() === needle)
  })

  if (match) {
    onItemSelected(match, row)
    $q.notify({
      type: 'positive',
      message: `Found item: ${match.name}`,
      timeout: 1000,
      position: 'top',
    })
    // Auto add next line if this one is filled
    if (props.items.indexOf(row) === props.items.length - 1) {
      addItem()
    }
  } else {
    $q.notify({
      type: 'warning',
      message: 'No item found with this serial/code',
      position: 'top',
    })
  }
}

// Global barcode scanner listener
let barcodeBuffer = ''
let barcodeTimer = null

function handleGlobalBarcodeScan(e) {
  // Ignore if user is already typing in an input/textarea/select
  const activeTag = document.activeElement?.tagName?.toLowerCase()
  if (['input', 'textarea', 'select'].includes(activeTag)) return

  if (e.key === 'Enter') {
    if (barcodeBuffer.length >= 3) {
      handleScannedBarcode(barcodeBuffer)
    }
    barcodeBuffer = ''
  } else if (e.key.length === 1) {
    barcodeBuffer += e.key
    clearTimeout(barcodeTimer)
    barcodeTimer = setTimeout(() => {
      barcodeBuffer = ''
    }, 50)
  }
}

async function handleScannedBarcode(barcode) {
  const needle = barcode.toLowerCase()
  const match = inventoryItems.value.find((item) => {
    const code = (item.code || '').toLowerCase()
    const serials = Array.isArray(item.serials) ? item.serials : []
    return code === needle || serials.some((s) => String(s).toLowerCase() === needle)
  })

  if (match) {
    // Find first empty row or add new
    let targetRow = props.items.find((i) => !i.description && !i.item_code)
    if (!targetRow) {
      addItem()
      await nextTick()
      targetRow = props.items[props.items.length - 1]
    }
    targetRow.serial_number = barcode
    onItemSelected(match, targetRow)
    $q.notify({
      type: 'positive',
      message: `Added item: ${match.name}`,
      timeout: 1000,
      position: 'top',
    })
  } else {
    $q.notify({
      type: 'warning',
      message: `Scanned code "${barcode}" not found in inventory`,
      position: 'top',
    })
  }
}

function addItem() {
  const newItems = [
    ...props.items,
    {
      description: '',
      item_code: '',
      qty: 1,
      discount: 0,
      discount_type: 'amount',
      line_total: 0,
      warranty: '',
      serial_number: '',
    },
  ]
  emit('update:items', newItems)
}

function removeItem(idx) {
  const newItems = [...props.items]
  newItems.splice(idx, 1)
  if (newItems.length === 0) {
    newItems.push({
      description: '',
      item_code: '',
      qty: 1,
      discount: 0,
      discount_type: 'amount',
      line_total: 0,
      warranty: '',
      serial_number: '',
    })
  }
  emit('update:items', newItems)
}

function toggleDiscountType(row) {
  row.discount_type = row.discount_type === 'percent' ? 'amount' : 'percent'
  calculateLine(row)
}

function calculateLine(row) {
  const gross = (row.qty || 0) * (row.unit_price || 0)
  let discountAmount = 0
  if (row.discount_type === 'percent') {
    // Clamp percentage between 0-100
    const pct = Math.min(100, Math.max(0, row.discount || 0))
    discountAmount = Math.round(gross * pct / 100 * 100) / 100
  } else {
    discountAmount = Math.max(0, row.discount || 0)
  }
  // Store the computed discount amount for downstream use
  row.discount_amount = discountAmount
  row.line_total = Math.max(0, Math.round((gross - discountAmount) * 100) / 100)
}

function formatCurrency(val) {
  return 'Rs. ' + Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}
</script>

<style scoped>
.invoice-table :deep(thead tr th) {
  font-weight: 700;
  color: #555;
  background: #fafafa;
}
</style>

<style>
body.body--dark .invoice-table thead tr th {
  color: #ccc !important;
  background: #333 !important;
}
</style>

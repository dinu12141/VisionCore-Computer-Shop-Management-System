<template>
  <q-card
    :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
    class="q-mt-md"
    flat
    bordered
  >
    <q-card-section class="row items-center q-pb-sm">
      <div class="text-subtitle1 text-weight-bold">
        <q-icon name="list_alt" class="q-mr-xs" /> Line Items
        <q-badge color="primary" class="q-ml-sm">{{ modelValue.length }}</q-badge>
      </div>
      <q-space />
      <q-btn
        v-if="!readonly"
        flat
        dense
        color="positive"
        icon="add_circle"
        label="Add Line"
        @click="addLine"
      />
    </q-card-section>

    <q-card-section class="q-pt-none">
      <q-table
        :rows="modelValue"
        :columns="tableColumns"
        row-key="_dummy"
        flat
        :dark="$q.dark.isActive"
        bordered
        dense
        class="bg-transparent"
        :table-header-class="
          $q.dark.isActive ? 'text-grey-5 text-uppercase' : 'text-grey-7 text-uppercase'
        "
        hide-bottom
        :rows-per-page-options="[0]"
      >
        <!-- Item Select -->
        <template #body-cell-item_id="props">
          <q-td :props="props">
            <q-select
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.item_id"
              :options="itemOptions"
              label="Select item"
              emit-value
              map-options
              style="min-width: 200px"
              @update:model-value="onItemSelected(props.rowIndex, $event)"
            />
            <span v-else>{{ getItemName(props.row.item_id) }}</span>
          </q-td>
        </template>

        <!-- Quantity -->
        <template #body-cell-quantity="props">
          <q-td :props="props">
            <q-input
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.quantity"
              type="number"
              :step="0.01"
              min="0"
              style="min-width: 100px"
              @update:model-value="(val) => updateLineItem(props.rowIndex, 'quantity', val)"
            />
            <span v-else>{{ formatNumber(props.row.quantity) }}</span>
          </q-td>
        </template>

        <!-- Unit Cost -->
        <template #body-cell-unit_cost="props">
          <q-td :props="props">
            <q-input
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.unit_cost"
              type="number"
              :step="0.01"
              min="0"
              style="min-width: 110px"
              @update:model-value="(val) => updateLineItem(props.rowIndex, 'unit_cost', val)"
            />
            <span v-else>{{ formatCurrency(props.row.unit_cost) }}</span>
          </q-td>
        </template>

        <!-- Tax Code -->
        <template #body-cell-tax_code="props">
          <q-td :props="props">
            <q-select
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.tax_code"
              :options="['NO_TAX', 'VAT15', 'NBT2']"
              style="min-width: 100px"
              @update:model-value="(val) => onTaxUpdate(props.rowIndex, val)"
            />
            <span v-else>{{ props.row.tax_code || 'None' }}</span>
          </q-td>
        </template>

        <!-- Tax Amount -->
        <template #body-cell-tax_amount="props">
          <q-td :props="props">
            <span class="text-grey-4">{{ formatCurrency(props.row.tax_amount) }}</span>
          </q-td>
        </template>

        <!-- Line Total -->
        <template #body-cell-line_total="props">
          <q-td :props="props">
            <span class="text-weight-bold">{{
              formatCurrency((props.row.quantity || 0) * (props.row.unit_cost || 0))
            }}</span>
          </q-td>
        </template>

        <!-- Batch (optional) -->
        <template #body-cell-batch_no="props">
          <q-td :props="props">
            <q-input
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.batch_no"
              placeholder="Batch"
              style="min-width: 100px"
              @update:model-value="(val) => updateLineItem(props.rowIndex, 'batch_no', val)"
            />
            <span v-else>{{ props.row.batch_no || '-' }}</span>
          </q-td>
        </template>

        <!-- Expiry (optional) -->
        <template #body-cell-expiry_date="props">
          <q-td :props="props">
            <q-input
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.expiry_date"
              type="date"
              style="min-width: 130px"
              @update:model-value="(val) => updateLineItem(props.rowIndex, 'expiry_date', val)"
            />
            <span v-else>{{ props.row.expiry_date || '-' }}</span>
          </q-td>
        </template>

        <!-- System Qty (stock count) -->
        <template v-if="isStockCount" #body-cell-system_qty="props">
          <q-td :props="props">
            <span class="text-grey-4">{{ formatNumber(props.row.system_qty) }}</span>
          </q-td>
        </template>

        <!-- Counted Qty (stock count) -->
        <template v-if="isStockCount" #body-cell-counted_qty="props">
          <q-td :props="props">
            <q-input
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.counted_qty"
              type="number"
              style="min-width: 100px"
              @update:model-value="(val) => onCountedQtyUpdate(props.rowIndex, val)"
            />
            <span v-else>{{ formatNumber(props.row.counted_qty) }}</span>
          </q-td>
        </template>

        <!-- Variance (stock count) -->
        <template v-if="isStockCount" #body-cell-variance_qty="props">
          <q-td :props="props">
            <span
              :class="
                props.row.variance_qty > 0
                  ? 'text-positive'
                  : props.row.variance_qty < 0
                    ? 'text-negative'
                    : 'text-grey'
              "
              class="text-weight-bold"
            >
              {{ props.row.variance_qty > 0 ? '+' : '' }}{{ formatNumber(props.row.variance_qty) }}
            </span>
          </q-td>
        </template>

        <!-- Notes -->
        <template #body-cell-notes="props">
          <q-td :props="props">
            <q-input
              v-if="!readonly"
              :dark="$q.dark.isActive"
              outlined
              dense
              :model-value="props.row.notes"
              placeholder="Notes"
              style="min-width: 120px"
              @update:model-value="(val) => updateLineItem(props.rowIndex, 'notes', val)"
            />
            <span v-else>{{ props.row.notes || '-' }}</span>
          </q-td>
        </template>

        <!-- Delete action -->
        <template #body-cell-actions="props">
          <q-td :props="props">
            <q-btn
              v-if="!readonly"
              flat
              dense
              round
              color="negative"
              icon="delete"
              size="sm"
              @click="removeLine(props.rowIndex)"
            >
              <q-tooltip>Remove line</q-tooltip>
            </q-btn>
          </q-td>
        </template>

        <!-- Footer Totals -->
        <template #bottom-row>
          <q-tr class="text-weight-bold" :class="$q.dark.isActive ? 'bg-grey-10' : 'bg-grey-2'">
            <q-td colspan="1" class="text-right text-subtitle2">TOTALS</q-td>
            <q-td class="text-right text-primary text-subtitle2">{{ formatNumber(totalQty) }}</q-td>
            <q-td></q-td>
            <q-td class="text-right text-positive text-subtitle2">{{
              formatCurrency(totalCost)
            }}</q-td>
            <q-td :colspan="extraCols + 2"></q-td>
          </q-tr>
        </template>
      </q-table>
    </q-card-section>
  </q-card>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  items: { type: Array, default: () => [] },
  docType: { type: String, default: '' },
  readonly: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue'])

const isStockCount = computed(() => props.docType === 'STOCK_COUNT')

const itemOptions = computed(() =>
  props.items.map((i) => ({
    label: `${i.code} — ${i.name} (${i.uom_code})`,
    value: i.id,
  })),
)

// Simplified columns without field functions that rely on volatile local state
const baseColumns = [
  { name: 'item_id', label: 'Item No/Desc', field: 'item_id', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right' },
  { name: 'unit_cost', label: 'Unit Price', field: 'unit_cost', align: 'right' },
  { name: 'tax_code', label: 'Tax Code', field: 'tax_code', align: 'left' },
  { name: 'tax_amount', label: 'Tax Amount', field: 'tax_amount', align: 'right' },
  { name: 'line_total', label: 'Total (Net)', align: 'right' },
  { name: 'batch_no', label: 'Batch', field: 'batch_no', align: 'left' },
  { name: 'expiry_date', label: 'Expiry', field: 'expiry_date', align: 'center' },
]

const stockCountColumns = [
  { name: 'item_id', label: 'Item', field: 'item_id', align: 'left' },
  { name: 'system_qty', label: 'System Qty', field: 'system_qty', align: 'right' },
  { name: 'counted_qty', label: 'Counted Qty', field: 'counted_qty', align: 'right' },
  { name: 'variance_qty', label: 'Variance', field: 'variance_qty', align: 'right' },
  { name: 'unit_cost', label: 'Unit Cost', field: 'unit_cost', align: 'right' },
  { name: 'line_total', label: 'Total', align: 'right' },
]

const noteAndAction = [
  { name: 'notes', label: 'Remarks', field: 'notes', align: 'left' },
  { name: 'actions', label: '', field: 'actions', align: 'center', style: 'width: 50px' },
]

const tableColumns = computed(() => {
  const cols = isStockCount.value ? stockCountColumns : baseColumns
  return [...cols, ...noteAndAction]
})

const extraCols = computed(() => (isStockCount.value ? 2 : 3))

const totalQty = computed(() => props.modelValue.reduce((s, l) => s + (Number(l.quantity) || 0), 0))

const totalCost = computed(() =>
  props.modelValue.reduce((s, l) => s + (Number(l.line_total) || 0), 0),
)

function getItemName(id) {
  const item = props.items.find((i) => i.id === id)
  return item ? `${item.code} — ${item.name}` : id
}

function updateLineItem(idx, field, val) {
  const updated = [...props.modelValue]
  const line = { ...updated[idx], [field]: val }

  // Recalculate line total (Net)
  if (field === 'quantity' || field === 'unit_cost') {
    line.line_total = (Number(line.quantity) || 0) * (Number(line.unit_cost) || 0)
    // Recalculate tax
    if (line.tax_code) onTaxUpdate(idx, line.tax_code, updated)
  }

  updated[idx] = line
  emit('update:modelValue', updated)
}

function onTaxUpdate(idx, taxCode, existingArr = null) {
  const updated = existingArr || [...props.modelValue]
  const line = { ...updated[idx] }
  line.tax_code = taxCode

  const net = (Number(line.quantity) || 0) * (Number(line.unit_cost) || 0)
  let taxRate = 0
  if (taxCode === 'VAT15') taxRate = 0.15
  if (taxCode === 'NBT2') taxRate = 0.02

  line.tax_amount = net * taxRate
  // Line total in SAP is usually the Net amount, but we can store tax_amount separately
  // For simplicity, we'll keep line_total as Net and sum tax separately in the footer
  line.line_total = net

  updated[idx] = line
  if (!existingArr) emit('update:modelValue', updated)
}

function onItemSelected(idx, itemId) {
  const item = props.items.find((i) => i.id === itemId)
  if (item) {
    const updated = [...props.modelValue]
    updated[idx] = {
      ...updated[idx],
      item_id: itemId,
      uom_id: item.inventory_uom_id || item.uom_id,
      unit_cost: item.avg_cost || item.last_purchase_price || 0,
    }
    emit('update:modelValue', updated)
  }
}

function onCountedQtyUpdate(idx, val) {
  const updated = [...props.modelValue]
  const line = { ...updated[idx] }
  line.counted_qty = Number(val) || 0
  line.variance_qty = line.counted_qty - (Number(line.system_qty) || 0)
  line.quantity = Math.abs(line.variance_qty)
  updated[idx] = line
  emit('update:modelValue', updated)
}

function addLine() {
  const updated = [
    ...props.modelValue,
    {
      item_id: '',
      quantity: 0,
      unit_cost: 0,
      batch_no: '',
      expiry_date: '',
      notes: '',
      system_qty: 0,
      counted_qty: 0,
      variance_qty: 0,
    },
  ]
  emit('update:modelValue', updated)
}

function removeLine(idx) {
  const updated = [...props.modelValue]
  updated.splice(idx, 1)
  emit('update:modelValue', updated)
}

function formatNumber(val) {
  return Number(val || 0).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
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
</script>

<style scoped>
.q-table__container {
  background: transparent !important;
}
</style>

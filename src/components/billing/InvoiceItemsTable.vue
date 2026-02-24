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
            placeholder="Search item..."
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
            @update:model-value="calculateLine(props.row)"
          />
        </q-td>
      </template>

      <template v-slot:body-cell-discount="props">
        <q-td :props="props">
          <q-input
            v-model.number="props.row.discount"
            type="number"
            dense
            outlined
            style="width: 90px"
            @update:model-value="calculateLine(props.row)"
          />
        </q-td>
      </template>

      <template v-slot:body-cell-line_total="props">
        <q-td :props="props" align="right" class="text-weight-bold">
          {{ formatCurrency(props.row.line_total) }}
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
import { ref, onMounted } from 'vue'
import { useItemsList } from 'src/services/inventoryService'

const props = defineProps({
  items: { type: Array, required: true },
})

const emit = defineEmits(['update:items'])

const { items: inventoryItems, listItems } = useItemsList()
const itemOptions = ref([])

onMounted(async () => {
  await listItems()
})

const columns = [
  { name: 'description', label: 'Item / Description', align: 'left', field: 'description' },
  { name: 'warranty', label: 'Warranty', align: 'left', field: 'warranty' },
  { name: 'qty', label: 'Quantity', align: 'left', field: 'qty' },
  { name: 'unit_price', label: 'Unit Price', align: 'left', field: 'unit_price' },
  { name: 'discount', label: 'Discount', align: 'left', field: 'discount' },
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
    calculateLine(row)
  }
}

function addItem() {
  const newItems = [
    ...props.items,
    {
      description: '',
      item_code: '',
      qty: 1,
      unit_price: 0,
      cost_price: 0,
      discount: 0,
      line_total: 0,
      warranty: '',
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
      unit_price: 0,
      cost_price: 0,
      discount: 0,
      line_total: 0,
      warranty: '',
    })
  }
  emit('update:items', newItems)
}

function calculateLine(row) {
  row.line_total =
    Math.round(((row.qty || 0) * (row.unit_price || 0) - (row.discount || 0)) * 100) / 100
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

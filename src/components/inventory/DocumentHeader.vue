<template>
  <q-card :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'" flat bordered>
    <q-card-section>
      <div class="row items-center q-mb-md">
        <q-icon :name="docTypeIcon" size="28px" :color="docTypeColor" class="q-mr-sm" />
        <div class="text-h6 text-weight-bolder">{{ title }}</div>
        <q-space />
        <StatusChip v-if="status" :status="status" />
      </div>

      <div class="row q-col-gutter-lg">
        <!-- LEFT COLUMN: Vendor / Warehouse -->
        <div class="col-12 col-md-6">
          <div class="row q-col-gutter-sm">
            <!-- Vendor Selection (SAP Style) -->
            <template v-if="showSupplier">
              <div class="col-4">
                <q-select
                  :dark="$q.dark.isActive"
                  outlined
                  dense
                  v-model="form.supplier_id"
                  :options="supplierOptions"
                  label="Vendor Code"
                  emit-value
                  map-options
                  :readonly="readonly"
                />
              </div>
              <div class="col-8">
                <q-input
                  :dark="$q.dark.isActive"
                  outlined
                  dense
                  :model-value="selectedVendorName"
                  label="Vendor Name"
                  readonly
                />
              </div>
            </template>

            <div class="col-6">
              <q-select
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="form.warehouse_id"
                :options="warehouseOptions"
                :label="isTransfer ? 'From Warehouse' : 'Warehouse'"
                emit-value
                map-options
                :readonly="readonly"
              />
            </div>
            <div v-if="isTransfer" class="col-6">
              <q-select
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="form.target_warehouse_id"
                :options="warehouseOptions.filter((w) => w.value !== form.warehouse_id)"
                label="To Warehouse"
                emit-value
                map-options
                :readonly="readonly"
              />
            </div>
            <div class="col-6">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="form.reference_no"
                label="Ref. No."
                placeholder="External Ref / PO #"
                :readonly="readonly"
              />
            </div>
          </div>
        </div>

        <!-- RIGHT COLUMN: SAP Specific Dates / Status -->
        <div class="col-12 col-md-4 offset-md-2">
          <div class="column q-gutter-y-xs">
            <div class="row items-center no-wrap">
              <div class="text-caption text-grey-5 col-5">Posting Date</div>
              <q-input
                class="col-7"
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="form.posting_date"
                type="date"
                :readonly="readonly"
              />
            </div>
            <div class="row items-center no-wrap">
              <div class="text-caption text-grey-5 col-5">Delivery Date</div>
              <q-input
                class="col-7"
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="form.delivery_date"
                type="date"
                :readonly="readonly"
              />
            </div>
            <div class="row items-center no-wrap">
              <div class="text-caption text-grey-5 col-5">Doc. Date</div>
              <q-input
                class="col-7"
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="form.doc_date"
                type="date"
                :readonly="readonly"
              />
            </div>
            <div class="row items-center no-wrap">
              <div class="text-caption text-grey-5 col-5">Doc. Type</div>
              <q-select
                class="col-7"
                :dark="$q.dark.isActive"
                outlined
                dense
                v-model="form.doc_type"
                :options="docTypeItems"
                emit-value
                map-options
                :readonly="readonly || !showDocType"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Remarks -->
      <div class="row q-mt-md">
        <div class="col-12">
          <q-input
            :dark="$q.dark.isActive"
            outlined
            dense
            v-model="form.remarks"
            label="Remarks"
            type="textarea"
            rows="2"
            :readonly="readonly"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup>
import { computed, reactive, watch } from 'vue'
import StatusChip from 'components/common/StatusChip.vue'

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  title: { type: String, default: 'New Document' },
  status: { type: String, default: '' },
  readonly: { type: Boolean, default: false },
  showDocType: { type: Boolean, default: true },
  warehouses: { type: Array, default: () => [] },
  suppliers: { type: Array, default: () => [] },
})

const emit = defineEmits(['update:modelValue', 'update:docType'])

const form = reactive({
  doc_type: '',
  doc_date: new Date().toISOString().split('T')[0],
  posting_date: new Date().toISOString().split('T')[0],
  delivery_date: new Date().toISOString().split('T')[0],
  warehouse_id: '',
  target_warehouse_id: '',
  supplier_id: '',
  reference_no: '',
  remarks: '',
  ...props.modelValue,
})

watch(
  () => props.modelValue,
  (val) => {
    Object.assign(form, val)
  },
  { deep: true },
)

watch(
  form,
  (val) => {
    emit('update:modelValue', { ...val })
  },
  { deep: true },
)

const docTypeItems = [
  { label: 'Purchase Order (PO)', value: 'PO' },
  { label: 'Goods Receipt (GRN)', value: 'GRN' },
  { label: 'Goods Issue (GIN)', value: 'GIN' },
  { label: 'Stock Transfer', value: 'TRANSFER' },
  { label: 'Adjustment', value: 'ADJUSTMENT' },
  { label: 'Stock Count', value: 'STOCK_COUNT' },
]

const warehouseOptions = computed(() =>
  props.warehouses.map((w) => ({ label: `${w.name} (${w.code})`, value: w.id })),
)

const supplierOptions = computed(() =>
  props.suppliers.map((s) => ({
    label: s.code || s.name,
    value: s.id,
    name: s.name,
  })),
)

const selectedVendorName = computed(() => {
  if (!form.supplier_id) return ''
  const s = props.suppliers.find((i) => i.id === form.supplier_id)
  return s ? s.name : ''
})

const isTransfer = computed(() => form.doc_type === 'TRANSFER')
const showSupplier = computed(() => form.doc_type === 'GRN' || form.doc_type === 'PO')

const docTypeColor = computed(() => {
  const map = {
    PO: 'indigo',
    GRN: 'green',
    GIN: 'red',
    TRANSFER: 'blue',
    ADJUSTMENT: 'orange',
    STOCK_COUNT: 'purple',
    BOM_DEDUCT: 'cyan',
  }
  return map[form.doc_type] || 'grey'
})

const docTypeIcon = computed(() => {
  const map = {
    PO: 'shopping_cart',
    GRN: 'archive',
    GIN: 'unarchive',
    TRANSFER: 'swap_horiz',
    ADJUSTMENT: 'tune',
    STOCK_COUNT: 'fact_check',
    BOM_DEDUCT: 'restaurant',
  }
  return map[form.doc_type] || 'description'
})
</script>

<template>
  <q-dialog
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
    maximized
    transition-show="slide-up"
    transition-hide="slide-down"
  >
    <q-card :class="$q.dark.isActive ? 'bg-grey-10 text-white' : 'bg-white text-black'">
      <q-card-section class="row items-center q-pb-none no-print">
        <div class="text-h6">{{ document.doc_type }} Print Preview</div>
        <q-space />
        <q-btn color="primary" icon="print" label="Print" @click="printDoc" class="q-mr-sm" />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="print-content q-pa-xl">
        <!-- PDF/Print Header -->
        <div class="row justify-between q-mb-xl">
          <div class="col-6">
            <div class="text-h4 text-weight-bolder text-uppercase primary-text">
              {{ document.doc_type }} Document
            </div>
            <div class="text-subtitle1 text-grey-7 q-mt-sm">Order #{{ document.doc_number }}</div>
          </div>
          <div class="col-5 text-right">
            <div class="text-h5 text-weight-bold">Seven Waves Restaurant</div>
            <div class="text-body2">123 Beach Road, Unawatuna</div>
            <div class="text-body2">Galle, Sri Lanka</div>
            <div class="text-body2">Phone: +94 91 123 4567</div>
            <div class="text-body2">Email: info@sevenwaves.com</div>
          </div>
        </div>

        <q-separator :dark="$q.dark.isActive" class="q-my-lg" />

        <div class="row q-col-gutter-xl q-mb-xl">
          <div class="col-6">
            <div class="text-overline text-grey-7">Supplier Information</div>
            <div class="text-h6 text-weight-bold">{{ document.supplier_name || 'N/A' }}</div>
            <div class="text-body1">{{ document.supplier_email || 'N/A' }}</div>
            <div class="text-body1">{{ document.supplier_address || 'N/A' }}</div>
          </div>
          <div class="col-6 text-right">
            <div class="row justify-end q-col-gutter-md">
              <div class="col-auto">
                <div class="text-overline text-grey-7 text-right">Order Date</div>
                <div class="text-subtitle1">{{ formatDate(document.doc_date) }}</div>
              </div>
              <div class="col-auto">
                <div class="text-overline text-grey-7 text-right">Warehouse</div>
                <div class="text-subtitle1">{{ document.warehouse_name || 'Main Warehouse' }}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Line Items Table -->
        <table class="po-table q-mb-xl">
          <thead>
            <tr>
              <th class="text-left">#</th>
              <th class="text-left">Item Description</th>
              <th class="text-right">Quantity</th>
              <th class="text-center">UOM</th>
              <th class="text-right">Unit Cost</th>
              <th class="text-right">Total</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(line, index) in lines" :key="index">
              <td class="text-left">{{ index + 1 }}</td>
              <td class="text-left">
                <div class="text-weight-bold">{{ line.item_name }}</div>
                <div class="text-caption text-grey-7">{{ line.item_code }}</div>
              </td>
              <td class="text-right">{{ line.quantity }}</td>
              <td class="text-center">{{ line.uom_code }}</td>
              <td class="text-right">{{ formatCurrency(line.unit_cost) }}</td>
              <td class="text-right text-weight-bold">
                {{ formatCurrency(line.quantity * line.unit_cost) }}
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="total-row">
              <td colspan="5" class="text-right text-weight-bold text-h6">Grand Total</td>
              <td class="text-right text-weight-bolder text-h6 primary-text">
                {{ formatCurrency(grandTotal) }}
              </td>
            </tr>
          </tfoot>
        </table>

        <!-- Remarks -->
        <div v-if="document.remarks" class="q-mt-xl">
          <div class="text-overline text-grey-7">Special Instructions / Remarks</div>
          <div
            class="text-body1 q-pa-md rounded-borders"
            :class="$q.dark.isActive ? 'bg-grey-9 border-grey-8' : 'bg-grey-1 border-grey-3'"
          >
            {{ document.remarks }}
          </div>
        </div>

        <!-- Footer Signatures -->
        <div class="row justify-between q-mt-xl pt-xl">
          <div class="col-4 text-center">
            <q-separator :color="$q.dark.isActive ? 'white' : 'black'" class="q-mb-sm" />
            <div class="text-caption text-weight-bold">Prepared By</div>
            <div class="text-body2">{{ document.created_by_name || 'System User' }}</div>
          </div>
          <div class="col-4 text-center">
            <q-separator :color="$q.dark.isActive ? 'white' : 'black'" class="q-mb-sm" />
            <div class="text-caption text-weight-bold">Authorized Signature</div>
          </div>
        </div>

        <div class="text-center q-mt-xl text-grey-5 text-caption no-print-visible">
          This is a computer generated document.
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: Boolean,
  document: Object,
  lines: Array,
})

defineEmits(['update:modelValue'])

const grandTotal = computed(() => {
  return (props.lines || []).reduce((acc, line) => acc + line.quantity * line.unit_cost, 0)
})

function formatCurrency(val) {
  return (
    'LKR ' +
    Number(val || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  )
}

function formatDate(val) {
  if (!val) return 'N/A'
  return new Date(val).toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

function printDoc() {
  window.print()
}
</script>

<style scoped>
.print-content {
  max-width: 900px;
  margin: 0 auto;
  font-family: 'Inter', sans-serif;
}

.primary-text {
  color: #1976d2;
}

.po-table {
  width: 100%;
  border-collapse: collapse;
}

.po-table th {
  background-color: v-bind("$q.dark.isActive ? '#2a2a2a' : '#f5f5f5'");
  padding: 12px 8px;
  border-bottom: 2px solid v-bind("$q.dark.isActive ? '#333' : '#ddd'");
  font-weight: 700;
  text-transform: uppercase;
  font-size: 12px;
  color: v-bind("$q.dark.isActive ? '#b0b0b0' : '#616161'");
}

.po-table td {
  padding: 12px 8px;
  border-bottom: 1px solid v-bind("$q.dark.isActive ? '#2a2a2a' : '#eee'");
}

.total-row td {
  border-top: 2px solid v-bind("$q.dark.isActive ? '#333' : '#ddd'");
  border-bottom: none;
  padding-top: 20px;
}

.bg-grey-1 {
  background-color: v-bind("$q.dark.isActive ? '#1d1d1d' : '#fafafa'");
}

.border-grey-3 {
  border: 1px solid v-bind("$q.dark.isActive ? '#30363d' : '#e0e0e0'");
}

.rounded-borders {
  border-radius: 8px;
}

@media print {
  @page { margin: 0; }
  .no-print {
    display: none !important;
  }
  .q-dialog__backdrop {
    display: none !important;
  }
  .q-dialog__inner {
    padding: 0 !important;
  }
  body {
    background: white !important;
  }
  .print-content {
    max-width: 100% !important;
    padding: 0 !important;
  }
}
</style>

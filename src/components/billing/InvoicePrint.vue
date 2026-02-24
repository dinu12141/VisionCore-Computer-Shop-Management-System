<template>
  <q-dialog
    ref="dialogRef"
    persistent
    maximized
    transition-show="slide-up"
    transition-hide="slide-down"
  >
    <q-card class="column no-wrap bg-grey-3">
      <!-- Toolbar -->
      <q-toolbar class="bg-primary text-white sticky-top">
        <q-btn flat round dense icon="close" v-close-popup />
        <q-toolbar-title> Invoice Preview: {{ activeInvoice?.invoice_no }} </q-toolbar-title>
        <q-space />
        <q-btn
          unelevated
          color="white"
          text-color="primary"
          icon="print"
          label="Print Invoice"
          :disable="!activeInvoice"
          @click="handlePrint"
        />
      </q-toolbar>

      <!-- Preview Area -->
      <q-card-section class="col scroll q-pa-lg flex flex-center relative-position">
        <q-inner-loading :showing="loading">
          <q-spinner-gears size="50px" color="primary" />
          <div class="q-mt-md">Loading Invoice...</div>
        </q-inner-loading>
        <div
          v-if="activeInvoice"
          class="invoice-preview-container bg-white shadow-10"
          v-html="renderedHtml"
        ></div>
        <div v-else-if="!loading" class="text-h6 text-grey">Invoice not found</div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useInvoiceStore } from 'src/stores/invoiceStore'
import { renderInvoiceHTML } from 'src/utils/renderInvoiceHTML'
import { printHTML } from 'src/utils/printHelper'

const props = defineProps({
  invoice: { type: Object, default: null },
  template: { type: Object, default: () => ({}) },
  autoPrint: { type: Boolean, default: false },
})

const route = useRoute()
const invoiceStore = useInvoiceStore()
const localInvoice = ref(null)
const loading = ref(false)

const dialogRef = ref(null)

const activeInvoice = computed(() => props.invoice || localInvoice.value)

const renderedHtml = computed(() => {
  if (!activeInvoice.value) return ''
  return renderInvoiceHTML(activeInvoice.value, props.template)
})

onMounted(async () => {
  if (!props.invoice && route.params.id) {
    loading.value = true
    try {
      localInvoice.value = await invoiceStore.getInvoice(route.params.id)
      // Check for autoPrint query param
      if (route.query.autoPrint === 'true') {
        setTimeout(() => {
          handlePrint()
        }, 800)
      }
    } finally {
      loading.value = false
    }
  } else if (props.invoice && props.autoPrint) {
    setTimeout(() => {
      handlePrint()
    }, 800)
  }
})

function handlePrint() {
  // Pass the same rendered HTML to the print helper
  printHTML(renderedHtml.value)
}

// To support programmatic opening
defineExpose({
  show: () => dialogRef.value?.show(),
  hide: () => dialogRef.value?.hide(),
})
</script>

<style scoped>
.invoice-preview-container {
  width: 210mm;
  min-height: 297mm;
  padding: 0;
  margin: 0 auto;
  overflow: hidden;
}

@media (max-width: 800px) {
  .invoice-preview-container {
    width: 100%;
    min-height: auto;
  }
}
</style>

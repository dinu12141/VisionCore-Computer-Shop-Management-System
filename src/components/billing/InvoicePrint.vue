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

        <!-- TAX / NORMAL toggle -->
        <div class="row items-center q-mr-md" style="gap: 8px">
          <q-btn
            :color="!viewAsVat ? 'white' : 'rgba(255,255,255,0.2)'"
            :text-color="!viewAsVat ? 'primary' : 'white'"
            :flat="viewAsVat"
            :unelevated="!viewAsVat"
            dense
            label="INVOICE"
            size="sm"
            @click="viewAsVat = false"
          />
          <q-btn
            :color="viewAsVat ? 'deep-orange' : 'rgba(255,255,255,0.2)'"
            :text-color="'white'"
            :flat="!viewAsVat"
            :unelevated="viewAsVat"
            dense
            label="TAX INVOICE"
            icon="receipt_long"
            size="sm"
            @click="viewAsVat = true"
          />
        </div>

        <q-btn
          unelevated
          color="white"
          text-color="primary"
          icon="print"
          label="Print"
          :disable="!activeInvoice"
          @click="handlePrint"
          class="q-mr-sm"
        />
        <q-btn
          unelevated
          color="deep-orange"
          text-color="white"
          icon="download"
          label="Download PDF"
          :disable="!activeInvoice"
          :loading="downloading"
          @click="handleDownload"
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
import { useQuasar } from 'quasar'
import { useInvoiceStore } from 'src/stores/invoiceStore'
import { renderInvoiceHTML } from 'src/utils/renderInvoiceHTML'
import { printHTML } from 'src/utils/printHelper'
import { downloadInvoicePDF } from 'src/utils/downloadInvoicePDF'

const props = defineProps({
  invoice: { type: Object, default: null },
  template: { type: Object, default: () => ({}) },
  autoPrint: { type: Boolean, default: false },
})

const $q = useQuasar()
const route = useRoute()
const invoiceStore = useInvoiceStore()
const localInvoice = ref(null)
const loading = ref(false)
const downloading = ref(false)
const dialogRef = ref(null)

// This toggle overrides however the invoice was originally created
// true = show as TAX INVOICE, false = show as normal INVOICE
const viewAsVat = ref(false)

const activeInvoice = computed(() => props.invoice || localInvoice.value)

// Build a modified invoice object that overrides is_vat_invoice based on toggle
const invoiceForRender = computed(() => {
  if (!activeInvoice.value) return null
  return {
    ...activeInvoice.value,
    is_vat_invoice: viewAsVat.value,
    // When switching to TAX view, compute VAT fields dynamically if not already set
    ...(viewAsVat.value && !activeInvoice.value.is_vat_invoice
      ? {
          total_before_vat: activeInvoice.value.total,
          vat_amount: Math.round(activeInvoice.value.total * 0.18 * 100) / 100,
          total: Math.round(activeInvoice.value.total * 1.18 * 100) / 100,
        }
      : {}),
  }
})

const renderedHtml = computed(() => {
  if (!invoiceForRender.value) return ''
  return renderInvoiceHTML(invoiceForRender.value, props.template)
})

onMounted(async () => {
  if (!props.invoice && route.params.id) {
    loading.value = true
    try {
      localInvoice.value = await invoiceStore.getInvoice(route.params.id)
      // Default toggle to match how invoice was originally created
      viewAsVat.value = !!localInvoice.value?.is_vat_invoice
      if (route.query.autoPrint === 'true') {
        setTimeout(() => {
          handlePrint()
        }, 800)
      }
    } finally {
      loading.value = false
    }
  } else if (props.invoice) {
    // Default toggle to match how invoice was originally created
    viewAsVat.value = !!props.invoice?.is_vat_invoice
    if (props.autoPrint) {
      setTimeout(() => {
        handlePrint()
      }, 800)
    }
  }
})

function handlePrint() {
  printHTML(renderedHtml.value)
}

async function handleDownload() {
  if (!invoiceForRender.value) return
  downloading.value = true
  try {
    const invoiceNo = invoiceForRender.value.invoice_no || 'Invoice'
    await downloadInvoicePDF(renderedHtml.value, invoiceNo)
    $q.notify({ type: 'positive', icon: 'download', message: `${invoiceNo}.pdf downloaded!` })
  } catch (err) {
    $q.notify({ type: 'negative', message: 'PDF download failed: ' + err.message })
  } finally {
    downloading.value = false
  }
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
  /* Force light appearance regardless of dark mode */
  background: #fff !important;
  color: #1a1a1a !important;
  color-scheme: light !important;
}

@media (max-width: 800px) {
  .invoice-preview-container {
    width: 100%;
    min-height: auto;
  }
}
</style>

<!-- Deep (unscoped) styles to override Quasar dark mode inside v-html content -->
<style>
.invoice-preview-container .page {
  background: #fff !important;
  color: #1a1a1a !important;
}
.invoice-preview-container .page .meta-card {
  background: #fafafa !important;
  border-color: #ddd !important;
}
.invoice-preview-container .page .totals-box {
  background-color: #fcfcfc !important;
  border-color: #000 !important;
}
.invoice-preview-container .page .balance-line {
  background-color: #f0f0f0 !important;
  border-color: #ccc !important;
}
.invoice-preview-container .page .remarks-section {
  background-color: #fffde7 !important;
  border-color: #999 !important;
}
.invoice-preview-container .page table.items {
  border-color: #000 !important;
}
.invoice-preview-container .page table.items th {
  background-color: #ed1c24 !important;
  color: #fff !important;
  border-color: #000 !important;
}
.invoice-preview-container .page table.items td {
  border-color: #000 !important;
  color: #1a1a1a !important;
}
.invoice-preview-container .page .company-info {
  border-left-color: #ed1c24 !important;
}
.invoice-preview-container .page .footer {
  border-top-color: #000 !important;
}
</style>

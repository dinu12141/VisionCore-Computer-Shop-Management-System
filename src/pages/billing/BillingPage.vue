<template>
  <q-page class="q-pa-md" :class="$q.dark.isActive ? 'bg-dark' : 'bg-grey-1'">
    <!-- Page Header -->
    <div class="row items-center q-mb-lg">
      <div class="row items-center no-wrap">
        <q-btn
          flat
          round
          icon="arrow_back"
          color="grey-7"
          @click="$router.back()"
          class="q-mr-sm"
        />
        <div>
          <h1 class="text-h4 text-weight-bolder q-ma-none text-primary">
            {{ isEditMode ? 'Edit Invoice' : form.isVatInvoice ? 'Tax Invoice' : 'Billing' }}
          </h1>
          <div class="text-subtitle2 text-grey-7">
            {{
              isEditMode
                ? `Updating Invoice: ${existingInvoiceNo}`
                : form.isVatInvoice
                  ? 'Create VAT-inclusive tax invoices'
                  : 'Create professional invoices for your clients'
            }}
          </div>
        </div>
      </div>
      <q-space />
      <div class="q-gutter-sm">
        <q-btn flat label="Invoice History" icon="history" color="primary" to="/billing/history" />
      </div>
    </div>

    <div class="row q-col-gutter-lg">
      <!-- MAIN FORM -->
      <div class="col-12 col-md-8">
        <!-- Billing Details Container -->
        <q-card flat class="border-radius-12 border-light overflow-hidden q-mb-md">
          <q-card-section>
            <div class="row justify-between items-center q-mb-md">
              <div class="text-h6 text-weight-bold">Invoice Items</div>
              <div class="row items-center q-gutter-x-sm">
                <q-input
                  v-model="form.invoice_date"
                  type="date"
                  label="Invoice Date"
                  outlined
                  dense
                  stack-label
                  style="width: 150px"
                />
                <q-input
                  v-model="form.customer_po_no"
                  label="Customer PO No"
                  outlined
                  dense
                  stack-label
                  style="width: 180px"
                  placeholder="Optional"
                />
              </div>
            </div>

            <InvoiceItemsTable v-model:items="items" />
          </q-card-section>
        </q-card>

        <!-- Customer Snapshot Preview / Walk-in Form -->
        <q-card flat class="border-radius-12 border-light q-mb-md">
          <q-card-section v-if="selectedCustomerData">
            <div class="row items-center">
              <q-avatar
                color="primary-1"
                text-color="primary"
                icon="person"
                size="md"
                class="q-mr-md"
              />
              <div>
                <div class="text-weight-bold">{{ selectedCustomerData.name }}</div>
                <div class="text-caption text-grey-6">
                  {{ selectedCustomerData.address || 'No address provided' }}
                </div>
              </div>
              <q-space />
              <q-btn
                flat
                dense
                icon="edit"
                color="grey-6"
                @click="openCustomerDialog(selectedCustomerData)"
              />
            </div>
          </q-card-section>

          <q-card-section v-else>
            <div class="text-subtitle2 text-weight-bold q-mb-md text-grey-7">
              WALK-IN CUSTOMER DETAILS
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input v-model="walkIn.name" label="Customer Name" outlined dense />
              </div>
              <div class="col-12 col-sm-3">
                <q-input v-model="walkIn.phone" label="Phone" outlined dense />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model="walkIn.address" label="Address" outlined dense />
              </div>
              <div class="col-12 col-sm-5">
                <q-input v-model="walkIn.tax_number" label="Tax No (VAT/TIN)" outlined dense />
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- SIDEBAR (Customer & Totals) -->
      <div class="col-12 col-md-4">
        <q-card flat class="border-radius-12 border-light sticky-card">
          <q-card-section>
            <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-7">SELECT CUSTOMER</div>
            <q-select
              v-model="selectedCustomerId"
              outlined
              dense
              use-input
              input-debounce="300"
              fill-input
              hide-selected
              label="Search Customers..."
              :options="customerOptions"
              @filter="filterCustomers"
              option-label="name"
              option-value="id"
              emit-value
              map-options
              class="q-mb-md"
            >
              <template v-slot:no-option>
                <q-item clickable @click="openCustomerDialog()">
                  <q-item-section class="text-primary text-weight-bold"
                    >+ Add New Customer</q-item-section
                  >
                </q-item>
              </template>
              <template v-slot:after>
                <q-btn flat round icon="add" color="primary" @click="openCustomerDialog()" />
              </template>
            </q-select>

            <q-separator class="q-my-md" />

            <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-7">PAYMENT SETTINGS</div>
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-select
                  v-model="form.payment_type"
                  :options="['cash', 'card', 'credit', 'other']"
                  label="Type"
                  outlined
                  dense
                  class="text-capitalize"
                />
              </div>
              <div class="col-6">
                <q-select
                  v-model="form.status"
                  :options="['issued', 'draft', 'paid', 'unpaid']"
                  label="Status"
                  outlined
                  dense
                  class="text-capitalize"
                />
              </div>
            </div>

            <q-separator class="q-my-md" />

            <!-- VAT INVOICE TOGGLE -->
            <div class="row items-center q-mb-sm">
              <q-toggle
                v-model="form.isVatInvoice"
                label="VAT Invoice"
                color="deep-orange"
                keep-color
                class="text-weight-bold"
              />
              <q-chip
                v-if="form.isVatInvoice"
                dense
                color="deep-orange"
                text-color="white"
                icon="receipt_long"
                size="sm"
                class="q-ml-sm"
                >TAX INVOICE</q-chip
              >
            </div>

            <q-separator class="q-my-md" />

            <!-- SUMMARY -->
            <div class="q-gutter-y-sm">
              <div class="row justify-between items-center text-subtitle1">
                <span class="text-grey-7">Subtotal</span>
                <span>{{ formatCurrency(totals.subtotal) }}</span>
              </div>
              <div class="row justify-between items-center">
                <span class="text-grey-7">Global Discount</span>
                <q-input
                  v-model.number="form.globalDiscount"
                  type="number"
                  dense
                  outlined
                  align="right"
                  style="width: 100px"
                  @update:model-value="() => {}"
                />
              </div>

              <!-- NON-VAT: Simple Total -->
              <div
                v-if="!form.isVatInvoice"
                class="row justify-between items-center text-h5 text-weight-bolder text-primary q-mt-md"
              >
                <span>Total</span>
                <span>{{ formatCurrency(totals.total) }}</span>
              </div>

              <!-- VAT: Full Breakdown -->
              <template v-if="form.isVatInvoice">
                <q-separator class="q-my-sm" />
                <div class="row justify-between items-center text-subtitle1">
                  <span class="text-grey-7 text-weight-medium">Total (without VAT)</span>
                  <span class="text-weight-bold">{{ formatCurrency(totals.total) }}</span>
                </div>
                <div class="row justify-between items-center text-subtitle1">
                  <span class="text-deep-orange text-weight-medium">
                    <q-icon name="percent" size="xs" class="q-mr-xs" />VAT (18%)
                  </span>
                  <span class="text-deep-orange text-weight-bold">{{
                    formatCurrency(totals.vatAmount)
                  }}</span>
                </div>
                <q-separator class="q-my-sm" />
                <div
                  class="row justify-between items-center text-h5 text-weight-bolder text-primary q-mt-xs"
                >
                  <span>Total (with VAT)</span>
                  <span>{{ formatCurrency(totals.grandTotal) }}</span>
                </div>
              </template>

              <q-separator class="q-my-md" />

              <div class="row justify-between items-center">
                <span class="text-grey-7">Paid Amount</span>
                <q-input
                  v-model.number="form.paidAmount"
                  type="number"
                  dense
                  outlined
                  align="right"
                  style="width: 120px"
                  :bg-color="$q.dark.isActive ? undefined : 'green-1'"
                />
              </div>
              <div class="row q-col-gutter-sm q-mb-md">
                <div class="col-12">
                  <q-toggle
                    v-model="form.isPartPayment"
                    label="Part Payment / Credit"
                    color="primary"
                    keep-color
                  />
                </div>
                <div class="col-12" v-if="form.isPartPayment || totals.balance > 0">
                  <q-input
                    v-model="form.collection_date"
                    type="date"
                    label="Collection Date"
                    outlined
                    dense
                    stack-label
                    :rules="[(val) => !!val || 'Required for credit sales']"
                  />
                </div>
              </div>

              <div
                class="row justify-between items-center text-weight-bold"
                :class="totals.balance > 0 ? 'text-negative' : 'text-positive'"
              >
                <span>Balance Due</span>
                <span>{{ formatCurrency(totals.balance) }}</span>
              </div>
            </div>

            <q-btn
              unelevated
              color="primary"
              :label="isEditMode ? 'Update Invoice' : 'Complete & Issue Invoice'"
              icon="check_circle"
              class="full-width q-mt-xl text-weight-bold q-py-sm"
              style="border-radius: 8px"
              :loading="invoiceStore.loading"
              @click="submitInvoice"
            />
            <q-btn
              flat
              label="Save as Draft"
              class="full-width q-mt-sm text-grey-7"
              @click="saveDraft"
            />
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Modular Customer Dialog -->
    <CustomerDialog
      v-if="showCustomerDialog"
      v-model="showCustomerDialog"
      :customer="editingCustomer"
      :is-edit="!!editingCustomer"
      @saved="onCustomerSaved"
    />

    <!-- In-page Invoice Print Dialog -->
    <InvoicePrint v-if="showPrintDialog" v-model="showPrintDialog" :invoice="invoiceToPrint" />
  </q-page>
</template>

<script setup>
import { ref, computed, reactive, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar, date } from 'quasar'
import { useCustomerStore } from 'src/stores/customerStore'
import { useInvoiceStore } from 'src/stores/invoiceStore'
import InvoiceItemsTable from 'src/components/billing/InvoiceItemsTable.vue'
import CustomerDialog from 'src/components/customers/CustomerDialog.vue'
import InvoicePrint from 'src/components/billing/InvoicePrint.vue'
import { useAuthStore } from 'src/stores/auth'

const $q = useQuasar()
const route = useRoute()
const router = useRouter()
const customerStore = useCustomerStore()
const invoiceStore = useInvoiceStore()
const authStore = useAuthStore()

const selectedCustomerId = ref(null)
const customerOptions = ref([])
const showCustomerDialog = ref(false)
const editingCustomer = ref(null)
const currentDate = date.formatDate(Date.now(), 'YYYY-MM-DD')

const showPrintDialog = ref(false)
const invoiceToPrint = ref(null)
const isEditMode = ref(false)
const editId = ref(null)
const existingInvoiceNo = ref('')

const walkIn = reactive({
  name: '',
  phone: '',
  address: '',
  tax_number: '',
})

const items = ref([
  {
    description: '',
    item_code: '',
    qty: 1,
    unit_price: 0,
    discount: 0,
    line_total: 0,
    warranty: '',
    serial_number: '',
  },
])

const form = reactive({
  payment_type: 'cash',
  status: 'issued',
  globalDiscount: 0,
  paidAmount: 0,
  notes: '',
  isPartPayment: false,
  collection_date: '',
  isVatInvoice: false,
  is_service_invoice: false,
  service_job_id: null,
  invoice_date: currentDate,
  customer_po_no: '',
})

const VAT_RATE = 0.18

const totals = computed(() => {
  const rawSubtotal = items.value.reduce((acc, cur) => acc + (cur.line_total || 0), 0)
  const subtotal = Math.round(rawSubtotal * 100) / 100
  const total = Math.max(0, Math.round((subtotal - (form.globalDiscount || 0)) * 100) / 100)
  // VAT calculations
  const vatAmount = form.isVatInvoice ? Math.round(total * VAT_RATE * 100) / 100 : 0
  const grandTotal = form.isVatInvoice ? Math.round((total + vatAmount) * 100) / 100 : total
  // Balance is always computed against the final payable amount
  const finalPayable = form.isVatInvoice ? grandTotal : total
  const balance = Math.round((finalPayable - (form.paidAmount || 0)) * 100) / 100
  return { subtotal, total, vatAmount, grandTotal, balance }
})

const selectedCustomerData = computed(() =>
  customerStore.customers.find((c) => c.id === selectedCustomerId.value),
)

onMounted(async () => {
  await customerStore.fetchCategories()

  // ── Edit Mode Detection ──────────────────────────────────────────
  if (route.query.editId) {
    if (!authStore.isAdmin) {
      $q.notify({ type: 'negative', message: 'Access Denied: Only Admins can edit invoices' })
      return await router.push('/billing/history')
    }
    isEditMode.value = true
    editId.value = route.query.editId
    try {
      const inv = await invoiceStore.getInvoice(editId.value)
      existingInvoiceNo.value = inv.invoice_no
      selectedCustomerId.value = inv.customer_id

      // Map basic form fields
      form.payment_type = inv.payment_type || 'cash'
      form.status = inv.status || 'issued'
      form.globalDiscount = Number(inv.discount || 0)
      form.paidAmount = Number(inv.paid_amount || 0)
      form.notes = inv.notes || ''
      form.isVatInvoice = !!inv.is_vat_invoice
      form.isPartPayment = Number(inv.balance || 0) > 0
      form.collection_date = inv.collection_date || ''
      form.invoice_date = inv.invoice_date || currentDate
      form.customer_po_no = inv.customer_po_no || ''

      // Map items
      items.value = (inv.items || []).map((i) => ({
        product_id: i.product_id,
        description: i.description,
        item_code: i.item_code,
        qty: i.qty,
        unit_price: i.unit_price,
        discount: i.discount,
        line_total: i.line_total,
        warranty: i.warranty,
        serial_number: i.serial_number,
      }))

      if (inv.customer_snapshot && !inv.customer_id) {
        walkIn.name = inv.customer_snapshot.name || ''
        walkIn.phone = inv.customer_snapshot.phone || ''
        walkIn.address = inv.customer_snapshot.address || ''
        walkIn.tax_number = inv.customer_snapshot.tax_number || ''
      }
    } catch {
      $q.notify({ type: 'negative', message: 'Failed to load invoice for editing' })
    }
    return
  }

  // ── Customer Direct Prefill ──────────────────────────────────────────
  if (route.query.customerId) {
    try {
      await customerStore.fetchCustomers()
      selectedCustomerId.value = route.query.customerId
      $q.notify({
        type: 'info',
        message: 'Customer selected from list',
        icon: 'person',
        timeout: 1000,
      })
    } catch {
      // ignore
    }
  }

  // ── Service Job Prefill ────────────────────────────────────────────
  // When arriving from "Pay → Invoice" on a service job card,
  // read the prefill data and populate the form automatically.
  const prefillRaw = sessionStorage.getItem('billing_prefill')
  if (prefillRaw) {
    try {
      const prefill = JSON.parse(prefillRaw)
      sessionStorage.removeItem('billing_prefill') // consume once

      if (prefill.source === 'service_job') {
        form.is_service_invoice = !!prefill.is_service_invoice
        form.service_job_id = prefill.job_id || null

        // Set notes
        if (prefill.notes) form.notes = prefill.notes

        // Pre-select customer if linked
        if (prefill.customer_id) {
          await customerStore.fetchCustomers()
          selectedCustomerId.value = prefill.customer_id
        } else if (prefill.customer_name) {
          // Walk-in with name filled from job
          walkIn.name = prefill.customer_name || ''
          walkIn.phone = prefill.customer_phone || ''
        }

        // Build line items from combined repairs + parts list
        const lineItems = (prefill.items || []).map((p) => ({
          description: p.description || '',
          item_code: p.item_code || '',
          qty: Number(p.qty || 1),
          unit_price: Number(p.unit_price || 0),
          discount: Number(p.discount || 0),
          line_total: Number(p.line_total || p.unit_price * p.qty || 0),
          warranty: p.warranty || '',
          serial_number: p.serial_number || '',
        }))

        // Only replace default empty row if we have real items
        if (lineItems.length > 0) {
          items.value = lineItems
        }
      }
    } catch {
      // ignore malformed prefill
    }
  }
})

async function filterCustomers(val, update) {
  // If empty input, show all customers (or at least recent ones)
  await customerStore.fetchCustomers(val)
  update(() => {
    customerOptions.value = customerStore.customers
  })
}

function openCustomerDialog(customer = null) {
  editingCustomer.value = customer
  showCustomerDialog.value = true
}

function onCustomerSaved(newCustomer) {
  // 1. Select the new customer
  selectedCustomerId.value = newCustomer.id
  // 2. Add to options so it shows up in the QSelect
  customerOptions.value = [newCustomer]
  // 3. Clear searching so the computed selectedCustomerData works
  customerStore.fetchCustomers()
  showCustomerDialog.value = false
}

async function submitInvoice() {
  const isWalkIn = !selectedCustomerId.value

  if (isWalkIn && !walkIn.name) {
    $q.notify({ type: 'warning', message: 'Please enter a customer name for walk-in' })
    return
  }

  const maxPayable = form.isVatInvoice ? totals.value.grandTotal : totals.value.total
  if (form.paidAmount > maxPayable) {
    $q.notify({ type: 'warning', message: 'Paid amount cannot exceed the total invoice amount' })
    return
  }

  if (totals.value.balance > 0 && !form.collection_date) {
    $q.notify({ type: 'warning', message: 'Please set a collection date for credit/partial sales' })
    return
  }

  if (items.value.some((i) => !i.description)) {
    $q.notify({ type: 'warning', message: 'Please fill all item descriptions' })
    return
  }

  try {
    const snapshot = selectedCustomerData.value
      ? {
          name: selectedCustomerData.value.name,
          address: selectedCustomerData.value.address,
          phone: selectedCustomerData.value.phone,
          code: selectedCustomerData.value.customer_code,
          tax_number: selectedCustomerData.value.tax_number,
        }
      : {
          name: walkIn.name,
          address: walkIn.address,
          phone: walkIn.phone,
          code: 'WALK-IN',
          tax_number: walkIn.tax_number,
        }

    const finalTotal = form.isVatInvoice ? totals.value.grandTotal : totals.value.total

    let finalStatus = form.status
    if (form.status !== 'draft') {
      if (totals.value.balance <= 0) {
        finalStatus = 'paid'
      } else if (form.paidAmount > 0) {
        finalStatus = 'issued' // Partial payment
      } else {
        finalStatus = 'unpaid' // Zero payment
      }
    }

    const payload = {
      customer_id: selectedCustomerId.value || null,
      status: finalStatus,
      payment_type: form.payment_type,
      subtotal: totals.value.subtotal,
      discount: form.globalDiscount,
      tax: totals.value.vatAmount,
      total: finalTotal,
      paid_amount: form.paidAmount,
      balance: totals.value.balance,
      customer_snapshot: snapshot,
      is_vat_invoice: form.isVatInvoice,
      vat_amount: totals.value.vatAmount,
      total_before_vat: totals.value.total,
      collection_date: form.isPartPayment || totals.value.balance > 0 ? form.collection_date : null,
      is_service_invoice: form.is_service_invoice,
      service_job_id: form.service_job_id,
      invoice_date: form.invoice_date || currentDate,
      customer_po_no: form.customer_po_no || null,
    }

    const invoice = isEditMode.value
      ? await invoiceStore.updateInvoice(editId.value, payload, items.value)
      : await invoiceStore.createInvoice(payload, items.value)

    $q.notify({
      type: 'positive',
      message: isEditMode.value ? 'Invoice updated successfully!' : 'Invoice issued successfully!',
    })

    // Open Print Preview Dialog In-page
    invoiceToPrint.value = invoice
    showPrintDialog.value = true

    // Clear form for next invoice
    items.value = [
      {
        description: '',
        item_code: '',
        qty: 1,
        unit_price: 0,
        discount: 0,
        line_total: 0,
        warranty: '',
        serial_number: '',
      },
    ]
    walkIn.name = ''
    walkIn.phone = ''
    walkIn.address = ''
    walkIn.tax_number = ''
    selectedCustomerId.value = null
    form.paidAmount = 0
    form.isPartPayment = false
    form.collection_date = ''
    form.isVatInvoice = false
    form.customer_po_no = ''
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

async function saveDraft() {
  form.status = 'draft'
  await submitInvoice()
}

function formatCurrency(val) {
  return 'LKR ' + Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })
}
</script>

<style scoped>
.border-radius-12 {
  border-radius: 12px;
}
.border-light {
  border: 1px solid rgba(0, 0, 0, 0.05);
}
.sticky-card {
  position: sticky;
  top: 100px;
}
</style>

<style>
body.body--dark .border-light {
  border: 1px solid rgba(255, 255, 255, 0.12);
}
</style>

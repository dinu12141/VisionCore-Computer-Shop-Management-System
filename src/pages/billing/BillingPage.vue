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
          <h1 class="text-h4 text-weight-bolder q-ma-none text-primary">Billing</h1>
          <div class="text-subtitle2 text-grey-7">
            Create professional invoices for your clients
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
              <div class="text-caption text-grey-6 text-uppercase text-weight-bold">
                Date: {{ currentDate }}
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
              <div class="col-12 col-sm-4">
                <q-input v-model="walkIn.phone" label="Phone" outlined dense />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model="walkIn.address" label="Address" outlined dense />
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
                  :options="['issued', 'draft']"
                  label="Status"
                  outlined
                  dense
                  class="text-capitalize"
                />
              </div>
            </div>

            <q-separator class="q-my-lg" />

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
              <div
                class="row justify-between items-center text-h5 text-weight-bolder text-primary q-mt-md"
              >
                <span>Total</span>
                <span>{{ formatCurrency(totals.total) }}</span>
              </div>

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
              label="Complete & Issue Invoice"
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
import { useRoute } from 'vue-router'
import { useQuasar, date } from 'quasar'
import { useCustomerStore } from 'src/stores/customerStore'
import { useInvoiceStore } from 'src/stores/invoiceStore'
import InvoiceItemsTable from 'src/components/billing/InvoiceItemsTable.vue'
import CustomerDialog from 'src/components/customers/CustomerDialog.vue'
import InvoicePrint from 'src/components/billing/InvoicePrint.vue'

const $q = useQuasar()
const route = useRoute()
const customerStore = useCustomerStore()
const invoiceStore = useInvoiceStore()

const selectedCustomerId = ref(null)
const customerOptions = ref([])
const showCustomerDialog = ref(false)
const editingCustomer = ref(null)
const currentDate = date.formatDate(Date.now(), 'YYYY-MM-DD')

const showPrintDialog = ref(false)
const invoiceToPrint = ref(null)

const walkIn = reactive({
  name: '',
  phone: '',
  address: '',
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
})

const totals = computed(() => {
  const rawSubtotal = items.value.reduce((acc, cur) => acc + (cur.line_total || 0), 0)
  const subtotal = Math.round(rawSubtotal * 100) / 100
  const total = Math.max(0, Math.round((subtotal - (form.globalDiscount || 0)) * 100) / 100)
  const balance = Math.round((total - (form.paidAmount || 0)) * 100) / 100
  return { subtotal, total, balance }
})

const selectedCustomerData = computed(() =>
  customerStore.customers.find((c) => c.id === selectedCustomerId.value),
)

onMounted(async () => {
  await customerStore.fetchCategories()
  if (route.query.customerId) {
    selectedCustomerId.value = route.query.customerId
    await customerStore.fetchCustomers()
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

  if (form.paidAmount > totals.value.total) {
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
        }
      : {
          name: walkIn.name,
          address: walkIn.address,
          phone: walkIn.phone,
          code: 'WALK-IN',
        }

    const payload = {
      customer_id: selectedCustomerId.value || null,
      status: form.status,
      payment_type: form.payment_type,
      subtotal: totals.value.subtotal,
      discount: form.globalDiscount,
      total: totals.value.total,
      paid_amount: form.paidAmount,
      balance: totals.value.balance,
      customer_snapshot: snapshot,
      collection_date: form.isPartPayment || totals.value.balance > 0 ? form.collection_date : null,
    }

    const invoice = await invoiceStore.createInvoice(payload, items.value)
    $q.notify({ type: 'positive', message: 'Invoice issued successfully!' })

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
      },
    ]
    walkIn.name = ''
    walkIn.phone = ''
    walkIn.address = ''
    selectedCustomerId.value = null
    form.paidAmount = 0
    form.isPartPayment = false
    form.collection_date = ''
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

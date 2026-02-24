<template>
  <q-page class="q-pa-md bg-grey-1">
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bold q-my-none text-primary">Outstanding Collections</h1>
        <p class="text-grey-7 q-mb-none">Track and manage invoices with remaining balance</p>
      </div>
    </div>

    <!-- Tabs -->
    <q-tabs
      v-model="activeTab"
      dense
      class="text-grey q-mb-md"
      active-color="primary"
      indicator-color="primary"
      align="left"
      narrow-indicator
      @update:model-value="fetchData"
    >
      <q-tab name="pending" icon="pending_actions" label="Outstanding" />
      <q-tab name="settled" icon="history" label="Collection History" />
    </q-tabs>

    <!-- Filters -->
    <q-card class="q-mb-lg no-border shadow-2 border-radius-lg">
      <q-card-section class="q-pa-md">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-3">
            <q-input
              v-model="filters.search"
              placeholder="Search invoice or customer..."
              outlined
              dense
              @update:model-value="debouncedFetch"
            >
              <template v-slot:prepend>
                <q-icon name="search" color="primary" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-3">
            <q-input
              v-model="filters.dateFrom"
              type="date"
              :label="activeTab === 'pending' ? 'Collection From' : 'Settled From'"
              outlined
              dense
              stack-label
              @update:model-value="fetchData"
            />
          </div>
          <div class="col-12 col-sm-3">
            <q-input
              v-model="filters.dateTo"
              type="date"
              :label="activeTab === 'pending' ? 'Collection To' : 'Settled To'"
              outlined
              dense
              stack-label
              @update:model-value="fetchData"
            />
          </div>
          <div class="col-12 col-sm-3 flex items-center" v-if="activeTab === 'pending'">
            <q-toggle
              v-model="filters.overdueOnly"
              label="Overdue Only"
              color="negative"
              @update:model-value="fetchData"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Collections Table -->
    <q-table
      :rows="collections"
      :columns="columns"
      row-key="id"
      flat
      bordered
      :loading="loading"
      :pagination="pagination"
      class="border-radius-lg clickable-rows"
      @row-click="handleRowClick"
    >
      <template v-slot:body-cell-invoice_no="props">
        <q-td :props="props">
          <div class="text-weight-bold text-primary">{{ props.value }}</div>
          <div class="text-caption text-grey-6 text-uppercase">
            {{ props.row.payment_status }}
          </div>
        </q-td>
      </template>

      <template v-slot:body-cell-customer="props">
        <q-td :props="props">
          <div class="text-weight-medium">{{ props.row.customer_snapshot?.name || 'Walk-in' }}</div>
          <div class="text-caption text-grey-6">{{ props.row.customer_snapshot?.phone }}</div>
        </q-td>
      </template>

      <template v-slot:body-cell-collection_date="props">
        <q-td :props="props">
          <div :class="isOverdue(props.value) ? 'text-negative text-weight-bold' : ''">
            {{ props.value || 'Not Set' }}
          </div>
          <div v-if="isOverdue(props.value)" class="text-caption text-negative">OVERDUE</div>
        </q-td>
      </template>

      <template v-slot:body-cell-balance="props">
        <q-td :props="props" align="right">
          <div class="text-weight-bold text-negative">{{ formatCurrency(props.value) }}</div>
          <div class="text-caption text-grey-6">of {{ formatCurrency(props.row.total) }}</div>
        </q-td>
      </template>

      <template v-slot:body-cell-total="props">
        <q-td :props="props" align="right">
          <div class="text-weight-bold text-positive">{{ formatCurrency(props.value) }}</div>
        </q-td>
      </template>

      <template v-slot:body-cell-updated_at="props">
        <q-td :props="props">
          <div class="text-weight-medium">
            {{ new Date(props.value).toLocaleDateString() }}
          </div>
          <div class="text-caption text-grey-6">SETTLED</div>
        </q-td>
      </template>

      <template v-slot:body-cell-actions="props">
        <q-td :props="props" align="center" class="q-gutter-xs">
          <template v-if="activeTab === 'pending'">
            <q-btn
              flat
              round
              dense
              icon="check_circle"
              color="primary"
              @click="quickSettle(props.row)"
            >
              <q-tooltip>Quick Settle (Full Amount)</q-tooltip>
            </q-btn>
            <q-btn
              flat
              round
              dense
              icon="payments"
              color="green"
              @click="openPaymentDialog(props.row)"
            >
              <q-tooltip>Add Part Payment</q-tooltip>
            </q-btn>
          </template>
          <q-btn flat round dense icon="visibility" color="grey-7" @click="viewInvoice(props.row)">
            <q-tooltip>View Invoice Details</q-tooltip>
          </q-btn>
        </q-td>
      </template>

      <template v-slot:no-data>
        <div class="full-width column flex-center q-pa-xl">
          <q-icon
            :name="activeTab === 'pending' ? 'assignment_turned_in' : 'history'"
            size="64px"
            color="grey-4"
          />
          <div class="text-h6 text-grey-5 q-mt-md">
            {{
              activeTab === 'pending'
                ? 'All caught up! No outstanding collections.'
                : 'No settled collections found in this period.'
            }}
          </div>
        </div>
      </template>
    </q-table>

    <!-- Add Payment Dialog -->
    <q-dialog v-model="showPaymentDialog">
      <q-card style="width: 400px; max-width: 90vw" class="border-radius-12">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">Record Payment</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div class="q-mb-md" v-if="selectedInvoice">
            <div class="text-weight-bold text-primary">{{ selectedInvoice.invoice_no }}</div>
            <div class="text-grey-7">
              Balance Due: {{ formatCurrency(selectedInvoice.balance) }}
            </div>
          </div>

          <q-form @submit="submitPayment" class="q-gutter-md">
            <q-input
              v-model.number="paymentForm.amount"
              type="number"
              label="Payment Amount"
              outlined
              dense
              autofocus
              :rules="[
                (val) => !!val || 'Amount is required',
                (val) => val > 0 || 'Amount must be greater than 0',
                (val) => val <= selectedInvoice.balance || 'Cannot exceed balance',
              ]"
            />

            <q-select
              v-model="paymentForm.method"
              :options="['CASH', 'CARD', 'BANK', 'CHEQUE', 'OTHER']"
              label="Payment Method"
              outlined
              dense
            />

            <q-input
              v-model="paymentForm.reference_no"
              label="Reference # / Receipt #"
              outlined
              dense
            />

            <q-input
              v-model="paymentForm.note"
              label="Notes"
              type="textarea"
              outlined
              dense
              rows="2"
            />

            <div class="row justify-end q-mt-md">
              <q-btn label="Cancel" flat color="grey-7" v-close-popup />
              <q-btn label="Save Payment" color="primary" type="submit" :loading="loading" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar, debounce } from 'quasar'
import { useInvoiceStore } from 'src/stores/invoiceStore'

const $q = useQuasar()
const router = useRouter()
const invoiceStore = useInvoiceStore()

const collections = ref([])
const loading = ref(false)
const showPaymentDialog = ref(false)
const selectedInvoice = ref(null)
const activeTab = ref('pending')

const filters = reactive({
  search: '',
  dateFrom: '',
  dateTo: '',
  overdueOnly: false,
})

const paymentForm = reactive({
  amount: 0,
  method: 'CASH',
  reference_no: '',
  note: '',
})

const pagination = ref({
  rowsPerPage: 20,
  sortBy: 'collection_date',
  descending: false,
})

const columns = computed(() => {
  const common = [
    { name: 'invoice_no', label: 'Invoice', align: 'left', field: 'invoice_no', sortable: true },
    { name: 'customer', label: 'Customer', align: 'left', sortable: false },
  ]

  if (activeTab.value === 'pending') {
    return [
      {
        name: 'collection_date',
        label: 'Due Date',
        align: 'left',
        field: 'collection_date',
        sortable: true,
      },
      ...common,
      { name: 'balance', label: 'Outstanding', align: 'right', field: 'balance', sortable: true },
      { name: 'actions', label: 'Actions', align: 'center', sortable: false },
    ]
  } else {
    return [
      ...common,
      { name: 'total', label: 'Settled Amount', align: 'right', field: 'total', sortable: true },
      {
        name: 'updated_at',
        label: 'Collected Date',
        align: 'left',
        field: 'updated_at',
        sortable: true,
      },
      { name: 'actions', label: 'Actions', align: 'center', sortable: false },
    ]
  }
})

async function fetchData() {
  if (activeTab.value === 'pending') {
    await fetchCollections()
  } else {
    await fetchHistory()
  }
}

async function fetchCollections() {
  loading.value = true
  try {
    collections.value = await invoiceStore.fetchOutstandingCollections(filters)
  } catch (err) {
    console.error('[OutstandingCollections] fetch error:', err)
    $q.notify({ type: 'negative', message: 'Failed to fetch collections' })
  } finally {
    loading.value = false
  }
}

async function fetchHistory() {
  loading.value = true
  try {
    collections.value = await invoiceStore.fetchCollectionHistory(filters)
  } catch (err) {
    console.error('[CollectionHistory] fetch error:', err)
    $q.notify({ type: 'negative', message: 'Failed to fetch history' })
  } finally {
    loading.value = false
  }
}

const debouncedFetch = debounce(fetchData, 500)

function openPaymentDialog(invoice) {
  selectedInvoice.value = invoice
  paymentForm.amount = invoice.balance
  paymentForm.method = 'CASH'
  paymentForm.reference_no = ''
  paymentForm.note = ''
  showPaymentDialog.value = true
}

async function quickSettle(invoice) {
  $q.dialog({
    title: 'Confirm Full Collection',
    message: `Are you sure you want to mark ${invoice.invoice_no} as FULLY COLLECTED? (Amount: ${formatCurrency(invoice.balance)})`,
    cancel: true,
    persistent: true,
    prompt: {
      model: '',
      type: 'text',
      label: 'Reference # (Optional)',
    },
  }).onOk(async (refNo) => {
    try {
      loading.value = true
      await invoiceStore.addPayment({
        invoice_id: invoice.id,
        customer_id: invoice.customer_id,
        amount: invoice.balance,
        method: 'CASH',
        reference_no: refNo,
        note: 'Quick Settle (Collection Confirmed)',
      })

      $q.notify({
        type: 'positive',
        message: 'Collection Confirmed Successfully',
        icon: 'check_circle',
        timeout: 5000,
        actions: [
          {
            label: 'View History',
            color: 'white',
            handler: () => router.push('/billing/history'),
          },
        ],
      })
      fetchCollections()
    } catch (err) {
      $q.notify({ type: 'negative', message: err.message })
    } finally {
      loading.value = false
    }
  })
}

async function submitPayment() {
  try {
    if (paymentForm.amount > selectedInvoice.value.balance) {
      $q.notify({ type: 'warning', message: 'Payment cannot exceed current balance' })
      return
    }

    await invoiceStore.addPayment({
      invoice_id: selectedInvoice.value.id,
      customer_id: selectedInvoice.value.customer_id,
      ...paymentForm,
    })

    $q.notify({ type: 'positive', message: 'Payment recorded successfully' })
    showPaymentDialog.value = false
    fetchCollections() // Refresh list
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

function handleRowClick(evt, row) {
  // Only navigate if it wasn't a button click
  if (evt.target.tagName !== 'BUTTON' && !evt.target.closest('button')) {
    viewInvoice(row)
  }
}

function viewInvoice(invoice) {
  router.push(`/billing/history?invoice_no=${invoice.invoice_no}`)
}

function isOverdue(dateStr) {
  if (!dateStr) return false
  const today = new Date().toISOString().split('T')[0]
  return dateStr < today
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

onMounted(() => {
  if (router.currentRoute.value.query.search) {
    filters.search = router.currentRoute.value.query.search
  }
  fetchCollections()
})
</script>

<style scoped>
.border-radius-lg {
  border-radius: 16px;
}
.border-radius-12 {
  border-radius: 12px;
}

.clickable-rows :deep(tbody tr) {
  cursor: pointer;
  transition: background-color 0.2s;
}
</style>

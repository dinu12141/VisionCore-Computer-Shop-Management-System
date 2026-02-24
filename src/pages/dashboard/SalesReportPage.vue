<template>
  <q-page class="q-pa-md">
    <PageHeader
      title="Daily Sales Report"
      subtitle="Track revenue, profits, and transaction history"
    >
      <template #actions>
        <q-input
          v-model="selectedDate"
          mask="date"
          :rules="['date']"
          dense
          outlined
          placeholder="Select Date"
          class="date-picker-input"
          :dark="$q.dark.isActive"
        >
          <template v-slot:append>
            <q-icon name="event" class="cursor-pointer">
              <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                <q-date v-model="selectedDate" @update:model-value="fetchReport">
                  <div class="row items-center justify-end">
                    <q-btn v-close-popup label="Close" color="primary" flat />
                  </div>
                </q-date>
              </q-popup-proxy>
            </q-icon>
          </template>
        </q-input>
        <q-btn
          color="primary"
          icon="refresh"
          label="Refresh"
          class="q-ml-sm"
          @click="fetchReport"
          :loading="loading"
        />
      </template>
    </PageHeader>

    <!-- Summary Cards -->
    <div class="row q-col-gutter-md q-mt-md">
      <div class="col-12 col-sm-4">
        <q-card
          class="stat-card revenue-card shadow-2"
          :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
        >
          <q-card-section class="row items-center no-wrap">
            <q-avatar icon="payments" color="blue-1" text-color="blue-8" size="48px" />
            <div class="q-ml-md">
              <div class="text-subtitle2 text-grey-7">Total Revenue</div>
              <div class="text-h5 text-weight-bolder">
                LKR {{ (summary.revenue || 0).toLocaleString() }}
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-4">
        <q-card
          class="stat-card profit-card shadow-2"
          :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
        >
          <q-card-section class="row items-center no-wrap">
            <q-avatar icon="trending_up" color="green-1" text-color="green-8" size="48px" />
            <div class="q-ml-md">
              <div class="text-subtitle2 text-grey-7">Total Profit</div>
              <div class="text-h5 text-weight-bolder">
                LKR {{ (summary.profit || 0).toLocaleString() }}
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-4">
        <q-card
          class="stat-card items-card shadow-2"
          :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
        >
          <q-card-section class="row items-center no-wrap">
            <q-avatar icon="shopping_bag" color="orange-1" text-color="orange-8" size="48px" />
            <div class="q-ml-md">
              <div class="text-subtitle2 text-grey-7">Items Sold</div>
              <div class="text-h5 text-weight-bolder">{{ summary.itemsSold }}</div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Transactions Table -->
    <q-card
      class="q-mt-md shadow-2"
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
    >
      <q-table
        title="Transactions"
        :rows="invoices"
        :columns="columns"
        row-key="id"
        :loading="loading"
        :dark="$q.dark.isActive"
        flat
        bordered
      >
        <template v-slot:body-cell-total="props">
          <q-td :props="props" class="text-weight-bold">
            LKR {{ (props.value || 0).toLocaleString() }}
          </q-td>
        </template>
        <template v-slot:body-cell-status="props">
          <q-td :props="props">
            <q-badge :color="props.value === 'paid' ? 'green' : 'orange'" class="q-pa-xs">
              {{ props.value.toUpperCase() }}
            </q-badge>
          </q-td>
        </template>
        <template v-slot:body-cell-actions="props">
          <q-td :props="props" class="q-gutter-xs">
            <q-btn
              flat
              dense
              round
              color="primary"
              icon="visibility"
              @click="viewInvoice(props.row)"
            >
              <q-tooltip>View Invoice Details</q-tooltip>
            </q-btn>
            <q-btn flat dense round color="secondary" icon="print" @click="printInvoice(props.row)">
              <q-tooltip>Print Receipt</q-tooltip>
            </q-btn>
            <q-btn flat dense round color="teal" icon="download" @click="printInvoice(props.row)">
              <q-tooltip>Download as PDF</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Unified Invoice Print/Preview Component -->
    <InvoicePrint
      v-if="invoiceDialog"
      v-model="invoiceDialog"
      :invoice="selectedInvoice"
      :auto-print="shouldAutoPrint"
    />
  </q-page>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import { supabase } from 'src/boot/supabase'
import PageHeader from 'src/components/common/PageHeader.vue'
import InvoicePrint from 'src/components/billing/InvoicePrint.vue'

// Date handling (Today default)
const selectedDate = ref(new Date().toISOString().split('T')[0].replace(/-/g, '/'))
const loading = ref(false)
const invoices = ref([])
const summary = reactive({
  revenue: 0,
  profit: 0,
  itemsSold: 0,
})

const invoiceDialog = ref(false)
const selectedInvoice = ref(null)
const shouldAutoPrint = ref(false)

const columns = [
  {
    name: 'invoice_no',
    label: 'Inv #',
    field: 'invoice_no',
    align: 'left',
    sortable: true,
  },
  {
    name: 'created_at',
    label: 'Time',
    field: (row) => new Date(row.created_at).toLocaleTimeString(),
    align: 'left',
    sortable: true,
  },
  {
    name: 'customer',
    label: 'Customer',
    field: (row) => row.customer_snapshot?.name || 'Walk-in',
    align: 'left',
  },
  {
    name: 'total',
    label: 'Grand Total',
    field: 'total',
    align: 'right',
    sortable: true,
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

async function fetchReport() {
  loading.value = true
  const dateStr = selectedDate.value.replace(/\//g, '-')

  try {
    // 1. Fetch Invoices for the date
    const { data: invData, error: invError } = await supabase
      .from('invoices')
      .select('*, invoice_items(*)')
      .gte('created_at', `${dateStr}T00:00:00`)
      .lte('created_at', `${dateStr}T23:59:59`)
      .order('created_at', { ascending: false })

    if (invError) throw invError

    invoices.value = invData || []

    // 2. Calculate summary
    let rev = 0
    let items = 0
    invoices.value.forEach((inv) => {
      rev += Number(inv.total || 0)
      if (inv.invoice_items) {
        inv.invoice_items.forEach((line) => {
          items += Number(line.qty || 0)
        })
      }
    })

    summary.revenue = rev
    summary.itemsSold = items
    summary.profit = rev * 0.25 // Mock profit calculation (25% margin)
    // In a real app, you'd calculate this from actual item costs
  } catch (err) {
    console.error('Failed to fetch sales report:', err)
  } finally {
    loading.value = false
  }
}

function viewInvoice(invoice) {
  shouldAutoPrint.value = false
  selectedInvoice.value = {
    ...invoice,
    items: invoice.invoice_items,
  }
  invoiceDialog.value = true
}

function printInvoice(invoice) {
  shouldAutoPrint.value = true
  selectedInvoice.value = {
    ...invoice,
    items: invoice.invoice_items,
  }
  invoiceDialog.value = true
}

onMounted(fetchReport)
</script>

<style scoped lang="scss">
.stat-card {
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.05);
  transition: transform 0.2s ease;
  &:hover {
    transform: translateY(-3px);
  }
}

.revenue-card {
  border-left: 5px solid #1976d2;
}
.profit-card {
  border-left: 5px solid #2e7d32;
}
.items-card {
  border-left: 5px solid #ef6c00;
}

.date-picker-input {
  width: 170px;
}
</style>

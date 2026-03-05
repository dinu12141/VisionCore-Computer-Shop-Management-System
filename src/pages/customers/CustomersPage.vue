<template>
  <q-page class="q-pa-md bg-grey-1">
    <!-- Header -->
    <div class="row items-center q-mb-lg">
      <div>
        <h1 class="text-h4 text-weight-bolder q-ma-none text-primary">Customers</h1>
        <div class="text-subtitle2 text-grey-7">Manage your customer relationships and billing</div>
      </div>
      <q-space />
      <q-btn
        unelevated
        color="primary"
        icon="add"
        label="Register Customer"
        class="text-weight-bold q-px-md"
        style="border-radius: 8px"
        @click="openDialog()"
      />
    </div>

    <!-- Filters & Search -->
    <q-card flat class="q-mb-md border-radius-12 border-light">
      <q-card-section class="row items-center q-gutter-md">
        <q-input
          v-model="search"
          placeholder="Search by name, phone or code..."
          outlined
          dense
          class="col-grow"
          debounce="300"
        >
          <template v-slot:prepend><q-icon name="search" color="primary" /></template>
        </q-input>

        <div class="row items-center q-gutter-sm">
          <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Category:</span>
          <q-btn-toggle
            v-model="categoryFilter"
            toggle-color="primary"
            flat
            dense
            :options="[{ label: 'All', value: null }, ...categoryOptions]"
            class="category-toggle"
          />
        </div>
      </q-card-section>
    </q-card>

    <!-- Results Table -->
    <q-card flat class="border-radius-12 overflow-hidden border-light">
      <q-table
        :rows="customerStore.customers"
        :columns="columns"
        :loading="customerStore.loading"
        row-key="id"
        flat
        :pagination="{ rowsPerPage: 10 }"
      >
        <template v-slot:body-cell-name="props">
          <q-td :props="props">
            <div class="text-weight-bold text-grey-9">{{ props.row.name }}</div>
            <div class="text-caption text-grey-6">{{ props.row.customer_code }}</div>
          </q-td>
        </template>

        <template v-slot:body-cell-category="props">
          <q-td :props="props">
            <q-badge outline color="primary" :label="getCategoryName(props.row.category_id)" />
          </q-td>
        </template>

        <template v-slot:body-cell-status="props">
          <q-td :props="props" align="center">
            <q-chip
              dense
              :color="props.row.status === 'active' ? 'green-1' : 'grey-2'"
              :text-color="props.row.status === 'active' ? 'green-9' : 'grey-7'"
              :label="props.row.status"
              class="text-weight-bold text-capitalize"
            />
          </q-td>
        </template>

        <template v-slot:body-cell-actions="props">
          <q-td :props="props" align="right" class="q-gutter-xs">
            <q-btn flat dense round icon="edit" color="blue-7" @click="openDialog(props.row)">
              <q-tooltip>Edit Profile</q-tooltip>
            </q-btn>
            <q-btn
              flat
              dense
              round
              icon="receipt_long"
              color="green-7"
              @click="goToBilling(props.row)"
            >
              <q-tooltip>Create Invoice</q-tooltip>
            </q-btn>
            <q-btn
              flat
              dense
              round
              icon="delete"
              color="negative"
              @click="confirmDelete(props.row)"
            >
              <q-tooltip>Delete Customer</q-tooltip>
            </q-btn>
          </q-td>
        </template>

        <!-- Empty State -->
        <template v-slot:no-data>
          <div class="full-width row flex-center q-pa-xl text-grey-6">
            <q-icon name="person_off" size="48px" class="q-mb-sm" />
            <div class="text-h6">No customers found</div>
          </div>
        </template>
      </q-table>
    </q-card>

    <!-- Externalized Dialog Component -->
    <CustomerDialog
      v-if="showDialog"
      v-model="showDialog"
      :customer="selectedCustomer"
      :is-edit="!!selectedCustomer"
      @saved="onSaved"
      @hide="showDialog = false"
    />
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useCustomerStore } from 'src/stores/customerStore'
import CustomerDialog from 'src/components/customers/CustomerDialog.vue'
import { useQuasar } from 'quasar'

const $q = useQuasar()
const router = useRouter()
const customerStore = useCustomerStore()

const search = ref('')
const categoryFilter = ref(null)
const showDialog = ref(false)
const selectedCustomer = ref(null)

const columns = [
  { name: 'name', label: 'Customer Name', field: 'name', align: 'left', sortable: true },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'category', label: 'Category', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: '', align: 'right' },
]

const categoryOptions = computed(() =>
  customerStore.categories.map((c) => ({ label: c.name, value: c.id })),
)

onMounted(async () => {
  await Promise.all([customerStore.fetchCategories(), customerStore.fetchCustomers()])
})

watch([search, categoryFilter], () => {
  customerStore.fetchCustomers(search.value, categoryFilter.value)
})

function getCategoryName(id) {
  return customerStore.categories.find((c) => c.id === id)?.name || 'Default'
}

function openDialog(customer = null) {
  selectedCustomer.value = customer
  showDialog.value = true
}

function onSaved() {
  customerStore.fetchCustomers(search.value, categoryFilter.value)
  showDialog.value = false
}

function goToBilling(customer) {
  router.push({ name: 'billing', query: { customerId: customer.id } })
}

function confirmDelete(customer) {
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete customer "${customer.name}"? This will not affect existing invoices, but the customer record will be removed.`,
    cancel: true,
    persistent: true,
    ok: {
      flat: true,
      color: 'negative',
      label: 'Delete',
    },
  }).onOk(async () => {
    try {
      await customerStore.deleteCustomer(customer.id)
      $q.notify({ type: 'positive', message: 'Customer deleted successfully' })
    } catch (err) {
      $q.notify({ type: 'negative', message: 'Failed to delete: ' + err.message })
    }
  })
}
</script>

<style scoped>
.border-radius-12 {
  border-radius: 12px;
}
.border-light {
  border: 1px solid rgba(0, 0, 0, 0.05);
}
.category-toggle {
  border-radius: 8px;
  overflow: hidden;
}
</style>

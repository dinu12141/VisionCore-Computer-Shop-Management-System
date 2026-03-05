<template>
  <div class="q-pa-md">
    <div class="row items-center q-mb-md">
      <div class="text-h6"><q-icon name="local_shipping" class="q-mr-sm" />Supplier Management</div>
      <q-space />
      <q-btn color="primary" icon="add" label="Add Supplier" @click="openCreate" />
    </div>

    <q-inner-loading :showing="loading" :dark="$q.dark.isActive" />

    <q-table
      v-if="!loading"
      :rows="suppliers"
      :columns="columns"
      row-key="id"
      flat
      :dark="$q.dark.isActive"
      bordered
      :class="$q.dark.isActive ? 'bg-grey-9' : 'bg-white text-grey-9'"
    >
      <template #body-cell-is_active="props">
        <q-td :props="props">
          <q-chip
            dense
            :color="props.row.is_active ? 'positive' : 'negative'"
            text-color="white"
            size="sm"
          >
            {{ props.row.is_active ? 'Active' : 'Inactive' }}
          </q-chip>
        </q-td>
      </template>

      <template #body-cell-actions="props">
        <q-td :props="props">
          <q-btn flat dense round icon="edit" color="primary" @click="openEdit(props.row)">
            <q-tooltip>Edit Supplier</q-tooltip>
          </q-btn>
          <q-btn
            flat
            dense
            round
            :icon="props.row.is_active ? 'block' : 'check_circle'"
            :color="props.row.is_active ? 'negative' : 'positive'"
            @click="toggleActive(props.row)"
          >
            <q-tooltip>{{ props.row.is_active ? 'Deactivate' : 'Activate' }}</q-tooltip>
          </q-btn>
          <q-btn flat dense round icon="delete" color="negative" @click="confirmDelete(props.row)">
            <q-tooltip>Delete Supplier</q-tooltip>
          </q-btn>
        </q-td>
      </template>
    </q-table>

    <!-- Add/Edit Dialog -->
    <q-dialog v-model="showDialog" persistent>
      <q-card
        :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
        style="min-width: 500px"
      >
        <q-card-section class="row items-center">
          <div class="text-h6">{{ editingSupplier ? 'Edit Supplier' : 'Add Supplier' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator :dark="$q.dark.isActive" />

        <q-card-section class="q-gutter-md">
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.code"
                label="Supplier Code"
              />
            </div>
            <div class="col-12 col-sm-8">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.name"
                label="Supplier Name"
                :rules="[(v) => !!v || 'Required']"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.contact_person"
                label="Contact Person"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.phone"
                label="Phone Number"
              />
            </div>
            <div class="col-12">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.email"
                label="Email Address"
                type="email"
              />
            </div>
            <div class="col-12">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.address"
                label="Address"
                type="textarea"
                rows="2"
              />
            </div>
            <div class="col-12">
              <q-input
                :dark="$q.dark.isActive"
                outlined
                v-model="form.tax_id"
                label="Tax ID / VAT No."
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            :label="editingSupplier ? 'Update' : 'Create'"
            icon="save"
            :loading="saving"
            @click="saveSupplier"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useSupplierList } from 'src/services/inventoryService'

const $q = useQuasar()
const {
  suppliers,
  loading,
  listSuppliers,
  createSupplier,
  updateSupplier,
  deleteSupplier,
  generateNextSupplierCode,
} = useSupplierList()

const showDialog = ref(false)
const editingSupplier = ref(null)
const saving = ref(false)

const columns = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'contact_person', label: 'Contact', field: 'contact_person', align: 'left' },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const emptyForm = {
  code: '',
  name: '',
  contact_person: '',
  phone: '',
  email: '',
  address: '',
  tax_id: '',
  is_active: true,
}
const form = reactive({ ...emptyForm })

onMounted(() => listSuppliers())

async function openCreate() {
  editingSupplier.value = null
  Object.assign(form, emptyForm)
  showDialog.value = true
  try {
    const nextCode = await generateNextSupplierCode()
    if (nextCode) form.code = nextCode
  } catch (e) {
    console.error('Auto-gen supplier code error:', e)
  }
}

function openEdit(supplier) {
  editingSupplier.value = supplier
  Object.assign(form, { ...supplier })
  showDialog.value = true
}

async function saveSupplier() {
  if (!form.name) {
    $q.notify({ type: 'warning', message: 'Supplier Name is required.' })
    return
  }
  saving.value = true
  try {
    if (editingSupplier.value) {
      await updateSupplier(editingSupplier.value.id, { ...form })
      $q.notify({ type: 'positive', message: 'Supplier updated!' })
    } else {
      await createSupplier({ ...form })
      $q.notify({ type: 'positive', message: 'Supplier created!' })
    }
    showDialog.value = false
    await listSuppliers()
  } catch (e) {
    $q.notify({ type: 'negative', message: e.message || 'Failed to save supplier.' })
  } finally {
    saving.value = false
  }
}

async function toggleActive(supplier) {
  try {
    await updateSupplier(supplier.id, { is_active: !supplier.is_active })
    $q.notify({
      type: 'info',
      message: `${supplier.name} ${supplier.is_active ? 'deactivated' : 'activated'}.`,
    })
    await listSuppliers()
  } catch (e) {
    $q.notify({ type: 'negative', message: e.message || 'Failed to update status.' })
  }
}

function confirmDelete(supplier) {
  $q.dialog({
    title: 'Delete Supplier',
    message: `Are you sure you want to permanently delete <b>${supplier.name}</b>? This cannot be undone.`,
    html: true,
    cancel: true,
    persistent: true,
    ok: { label: 'Delete', color: 'negative', flat: true },
  }).onOk(async () => {
    try {
      await deleteSupplier(supplier.id)
      $q.notify({
        type: 'positive',
        message: `${supplier.name} deleted successfully.`,
        icon: 'delete',
      })
    } catch (e) {
      const msg = e.message || ''
      const isFkey =
        msg.toLowerCase().includes('foreign key') || msg.toLowerCase().includes('violates')
      $q.notify({
        type: 'negative',
        message: isFkey
          ? `Cannot delete: ${supplier.name} is linked to existing records. Deactivate it instead.`
          : `Failed to delete: ${msg}`,
        timeout: 6000,
      })
    }
  })
}
</script>

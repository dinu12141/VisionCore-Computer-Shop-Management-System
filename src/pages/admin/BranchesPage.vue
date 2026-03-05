<template>
  <q-page class="q-pa-md">
    <PageHeader
      title="Branch Management"
      subtitle="Manage enterprise locations and branches"
      showBack
    />

    <q-card
      flat
      bordered
      class="q-mt-md"
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
    >
      <q-card-section>
        <div class="row q-col-gutter-md items-center">
          <div class="col-12 col-md-4">
            <q-input
              dense
              outlined
              v-model="search"
              placeholder="Search branches..."
              :dark="$q.dark.isActive"
            >
              <template v-slot:append>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-md-8 text-right">
            <q-btn color="primary" icon="add" label="Add Branch" @click="openDialog" />
          </div>
        </div>
      </q-card-section>

      <q-table
        :rows="branches"
        :columns="columns"
        row-key="id"
        :filter="search"
        flat
        class="bg-transparent"
        :dark="$q.dark.isActive"
      >
        <template v-slot:body-cell-status="props">
          <q-td :props="props">
            <q-chip
              :color="props.row.status === 'open' ? 'positive' : 'negative'"
              text-color="white"
              dense
            >
              {{ props.row.status.toUpperCase() }}
            </q-chip>
          </q-td>
        </template>
        <template v-slot:body-cell-actions="props">
          <q-td :props="props" class="q-gutter-sm">
            <q-btn
              flat
              round
              color="primary"
              icon="edit"
              size="sm"
              @click="editBranch(props.row)"
            />
            <q-btn
              flat
              round
              color="negative"
              icon="delete"
              size="sm"
              @click="deleteBranch(props.row)"
            />
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Add/Edit Branch Dialog -->
    <q-dialog v-model="dialogVisible">
      <q-card
        style="min-width: 500px"
        :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      >
        <q-card-section>
          <div class="text-h6">{{ isEditing ? 'Edit Branch' : 'Add New Branch' }}</div>
        </q-card-section>

        <q-card-section class="q-pt-none">
          <q-form @submit="saveBranch" class="q-gutter-md">
            <q-input
              v-model="form.name"
              label="Branch Name"
              outlined
              dense
              :dark="$q.dark.isActive"
              :rules="[(val) => !!val || 'Name is required']"
            />
            <q-input
              v-model="form.address"
              label="Address"
              type="textarea"
              outlined
              dense
              :dark="$q.dark.isActive"
              :rules="[(val) => !!val || 'Address is required']"
            />
            <q-input
              v-model="form.phone"
              label="Phone Number"
              outlined
              dense
              :dark="$q.dark.isActive"
            />
            <q-input
              v-model="form.manager"
              label="Branch Manager"
              outlined
              dense
              :dark="$q.dark.isActive"
            />

            <q-toggle v-model="form.is_main" label="Main Branch" :dark="$q.dark.isActive" />
            <q-select
              v-model="form.status"
              label="Status"
              :options="['open', 'closed', 'renovation']"
              outlined
              dense
              :dark="$q.dark.isActive"
            />

            <div class="row justify-end q-mt-lg">
              <q-btn label="Cancel" color="grey" flat v-close-popup />
              <q-btn
                :label="isEditing ? 'Update' : 'Save'"
                type="submit"
                color="primary"
                class="q-ml-sm"
              />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, reactive } from 'vue'
import PageHeader from 'components/common/PageHeader.vue'
import { useQuasar } from 'quasar'

const $q = useQuasar()
const search = ref('')
const dialogVisible = ref(false)
const isEditing = ref(false)

const columns = [
  { name: 'name', label: 'Branch Name', align: 'left', field: 'name', sortable: true },
  { name: 'address', label: 'Address', align: 'left', field: 'address' },
  { name: 'phone', label: 'Phone', align: 'left', field: 'phone' },
  { name: 'manager', label: 'Manager', align: 'left', field: 'manager' },
  { name: 'status', label: 'Status', align: 'center', field: 'status', sortable: true },
  { name: 'actions', label: 'Actions', align: 'center', field: 'actions' },
]

const branches = ref([
  {
    id: 1,
    name: 'Main Branch',
    address: '123 Main St, Cityville',
    phone: '+1 234 567 890',
    manager: 'John Doe',
    status: 'open',
    is_main: true,
  },
  {
    id: 2,
    name: 'Downtown Outlet',
    address: '456 Business Ave, Metro',
    phone: '+1 987 654 321',
    manager: 'Alice Smith',
    status: 'open',
    is_main: false,
  },
])

const form = reactive({
  id: null,
  name: '',
  address: '',
  phone: '',
  manager: '',
  status: 'open',
  is_main: false,
})

const openDialog = () => {
  isEditing.value = false
  Object.assign(form, {
    id: null,
    name: '',
    address: '',
    phone: '',
    manager: '',
    status: 'open',
    is_main: false,
  })
  dialogVisible.value = true
}

const editBranch = (branch) => {
  isEditing.value = true
  Object.assign(form, branch)
  dialogVisible.value = true
}

const saveBranch = () => {
  if (isEditing.value) {
    const index = branches.value.findIndex((b) => b.id === form.id)
    if (index !== -1) branches.value[index] = { ...form }
    $q.notify({ type: 'positive', message: 'Branch updated successfully' })
  } else {
    branches.value.push({ ...form, id: Date.now() })
    $q.notify({ type: 'positive', message: 'Branch created successfully' })
  }
  dialogVisible.value = false
}

const deleteBranch = (branch) => {
  $q.dialog({
    title: 'Confirm',
    message: `Are you sure you want to delete ${branch.name}?`,
    cancel: true,
    persistent: true,
    dark: $q.dark.isActive,
  }).onOk(() => {
    branches.value = branches.value.filter((b) => b.id !== branch.id)
    $q.notify({ type: 'info', message: 'Branch deleted' })
  })
}
</script>

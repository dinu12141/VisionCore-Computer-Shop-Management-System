<template>
  <q-page class="q-pa-md">
    <PageHeader title="User Management" subtitle="Manage system users and their access" />

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
              placeholder="Search users..."
              :dark="$q.dark.isActive"
            >
              <template v-slot:append><q-icon name="search" /></template>
            </q-input>
          </div>
          <div class="col-12 col-md-8 text-right">
            <q-btn
              color="primary"
              icon="add"
              label="Add User"
              @click="openCreate"
              :loading="pageLoading"
            />
          </div>
        </div>
      </q-card-section>

      <q-table
        :rows="filteredUsers"
        :columns="columns"
        row-key="id"
        flat
        class="bg-transparent"
        :dark="$q.dark.isActive"
        :loading="pageLoading"
      >
        <template v-slot:body-cell-roles="props">
          <q-td :props="props">
            <q-badge
              v-for="role in props.row.roles"
              :key="role"
              :color="roleColor(role)"
              class="q-mr-xs"
              style="text-transform: capitalize"
              >{{ role }}</q-badge
            >
            <span v-if="!props.row.roles?.length" class="text-grey-5 text-caption">No roles</span>
          </q-td>
        </template>

        <template v-slot:body-cell-status="props">
          <q-td :props="props">
            <q-chip
              :color="props.row.is_active ? 'positive' : 'negative'"
              text-color="white"
              dense
              size="sm"
              >{{ props.row.is_active ? 'Active' : 'Inactive' }}</q-chip
            >
          </q-td>
        </template>

        <template v-slot:body-cell-actions="props">
          <q-td :props="props" class="q-gutter-sm">
            <q-btn flat round color="primary" icon="edit" size="sm" @click="openEdit(props.row)">
              <q-tooltip>Edit User</q-tooltip>
            </q-btn>
            <q-btn
              flat
              round
              color="negative"
              icon="delete"
              size="sm"
              @click="deleteUser(props.row)"
              :disable="props.row.email === 'admin@visioncore.erp'"
            >
              <q-tooltip>Delete User</q-tooltip>
            </q-btn>
          </q-td>
        </template>

        <template v-slot:no-data>
          <div class="full-width text-center q-pa-xl text-grey-5">
            <q-icon name="group_off" size="48px" class="q-mb-md" /><br />
            No users found
          </div>
        </template>
      </q-table>
    </q-card>

    <!-- Add / Edit Dialog -->
    <q-dialog v-model="dialogVisible" persistent>
      <q-card
        style="min-width: 480px; max-width: 95vw"
        :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      >
        <q-card-section class="row items-center">
          <div class="text-h6">{{ isEditing ? 'Edit User' : 'Add New User' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator :dark="$q.dark.isActive" />

        <q-card-section class="q-pt-md">
          <q-form @submit.prevent="saveUser" class="q-gutter-md">
            <q-input
              v-model="form.full_name"
              label="Full Name *"
              outlined
              dense
              :dark="$q.dark.isActive"
              :rules="[(v) => !!v || 'Name is required']"
            />
            <q-input
              v-model="form.email"
              label="Email Address *"
              type="email"
              outlined
              dense
              :dark="$q.dark.isActive"
              :readonly="isEditing"
              :rules="[(v) => !!v || 'Email is required']"
            />
            <q-input
              v-model="form.password"
              :label="isEditing ? 'New Password (leave blank to keep existing)' : 'Password *'"
              type="password"
              outlined
              dense
              :dark="$q.dark.isActive"
              :rules="isEditing ? [] : [(v) => (!!v && v.length >= 6) || 'Minimum 6 characters']"
            />

            <q-select
              v-model="form.roles"
              label="Roles *"
              :options="availableRoles"
              multiple
              use-chips
              outlined
              dense
              :dark="$q.dark.isActive"
              :rules="[(v) => (v && v.length > 0) || 'At least one role required']"
            />

            <q-select
              v-model="form.branch_id"
              label="Branch"
              :options="branchOptions"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              outlined
              dense
              :dark="$q.dark.isActive"
            />

            <q-toggle
              v-model="form.is_active"
              label="Active User"
              :dark="$q.dark.isActive"
              color="positive"
            />

            <q-separator :dark="$q.dark.isActive" />

            <div class="row justify-end q-gutter-sm q-mt-sm">
              <q-btn label="Cancel" color="grey" flat v-close-popup />
              <q-btn
                :label="isEditing ? 'Update User' : 'Create User'"
                type="submit"
                color="primary"
                :loading="saving"
                icon="save"
              />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import PageHeader from 'components/common/PageHeader.vue'
import { supabase } from 'src/boot/supabase'

const $q = useQuasar()
const search = ref('')
const dialogVisible = ref(false)
const isEditing = ref(false)
const pageLoading = ref(false)
const saving = ref(false)
const users = ref([])
const branches = ref([])

const availableRoles = ref([])

async function loadRoles() {
  const { data } = await supabase.from('roles').select('name').order('name')
  availableRoles.value = (data || []).map((r) => r.name)
}

const branchOptions = computed(() => branches.value)

const columns = [
  { name: 'full_name', label: 'Name', align: 'left', field: 'full_name', sortable: true },
  { name: 'email', label: 'Email', align: 'left', field: 'email', sortable: true },
  { name: 'roles', label: 'Roles', align: 'left', field: 'roles' },
  { name: 'branch_name', label: 'Branch', align: 'left', field: 'branch_name', sortable: true },
  { name: 'status', label: 'Status', align: 'center', field: 'is_active', sortable: true },
  { name: 'actions', label: 'Actions', align: 'center', field: 'actions' },
]

const filteredUsers = computed(() => {
  if (!search.value) return users.value
  const q = search.value.toLowerCase()
  return users.value.filter(
    (u) =>
      u.full_name?.toLowerCase().includes(q) ||
      u.email?.toLowerCase().includes(q) ||
      u.roles?.some((r) => r.toLowerCase().includes(q)),
  )
})

const form = reactive({
  id: null,
  full_name: '',
  email: '',
  password: '',
  roles: [],
  branch_id: null,
  is_active: true,
})

function roleColor(role) {
  const map = {
    admin: 'red-8',
    manager: 'blue-8',
    inventory: 'green-8',
    finance: 'purple-8',
    hr: 'teal-8',
    cashier: 'orange-8',
    waiter: 'cyan-8',
    kitchen: 'brown-8',
  }
  return map[role] || 'grey-7'
}

async function callAdminFn(body) {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/admin-manage-users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
      apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
    },
    body: JSON.stringify(body),
  })
  const json = await res.json()
  if (!res.ok || json.error) throw new Error(json.error || 'Server error')
  return json
}

async function loadUsers() {
  pageLoading.value = true
  try {
    const data = await callAdminFn({ action: 'list' })
    users.value = data.users || []
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to load users: ' + err.message })
  } finally {
    pageLoading.value = false
  }
}

async function loadBranches() {
  const { data } = await supabase.from('branches').select('id, name').eq('is_active', true)
  branches.value = data || []
}

function openCreate() {
  isEditing.value = false
  Object.assign(form, {
    id: null,
    full_name: '',
    email: '',
    password: '',
    roles: [],
    branch_id: branchOptions.value[0]?.id || null,
    is_active: true,
  })
  dialogVisible.value = true
}

function openEdit(user) {
  isEditing.value = true
  Object.assign(form, {
    id: user.id,
    full_name: user.full_name,
    email: user.email,
    password: '',
    roles: [...(user.roles || [])],
    branch_id: user.branch_id || null,
    is_active: user.is_active,
  })
  dialogVisible.value = true
}

async function saveUser() {
  saving.value = true
  try {
    if (isEditing.value) {
      await callAdminFn({
        action: 'update',
        user_id: form.id,
        full_name: form.full_name,
        password: form.password || undefined,
        roles: form.roles,
        branch_id: form.branch_id,
        is_active: form.is_active,
      })
      $q.notify({ type: 'positive', message: 'User updated successfully' })
    } else {
      await callAdminFn({
        action: 'create',
        full_name: form.full_name,
        email: form.email,
        password: form.password,
        roles: form.roles,
        branch_id: form.branch_id,
      })
      $q.notify({ type: 'positive', message: `User created: ${form.email}` })
    }
    dialogVisible.value = false
    await loadUsers()
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  } finally {
    saving.value = false
  }
}

function deleteUser(user) {
  $q.dialog({
    title: 'Delete User',
    message: `Are you sure you want to delete <b>${user.full_name}</b>? This cannot be undone.`,
    html: true,
    cancel: true,
    persistent: true,
    dark: $q.dark.isActive,
    ok: { label: 'Delete', color: 'negative' },
  }).onOk(async () => {
    try {
      await callAdminFn({ action: 'delete', user_id: user.id })
      $q.notify({ type: 'positive', message: 'User deleted' })
      await loadUsers()
    } catch (err) {
      $q.notify({ type: 'negative', message: err.message })
    }
  })
}

onMounted(async () => {
  await Promise.all([loadUsers(), loadBranches(), loadRoles()])
})
</script>

<template>
  <q-page class="q-pa-lg">
    <div class="row items-center q-mb-lg">
      <div class="col">
        <h1 class="text-h4 text-weight-bolder q-ma-none text-gradient">
          {{ isEdit ? 'Edit Service Job' : 'Create Service Job' }}
        </h1>
        <div class="text-subtitle2 text-grey-6">
          {{ isEdit ? 'Update details for ' + form.job_no : 'Register a new device repair ticket' }}
        </div>
      </div>
      <div class="col-auto">
        <q-btn flat icon="arrow_back" label="Back" @click="$router.back()" />
      </div>
    </div>

    <q-card flat bordered class="glass-card">
      <q-stepper
        v-model="step"
        ref="stepperRef"
        color="primary"
        animated
        flat
        vertical
        :dark="$q.dark.isActive"
      >
        <!-- Step 1: Customer -->
        <q-step :name="1" title="Customer" icon="person" :done="step > 1">
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-select
                v-model="form.customer_id"
                label="Select Customer *"
                :options="filteredCustomers"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                outlined
                dense
                use-input
                clearable
                :dark="$q.dark.isActive"
                @filter="filterCustomers"
              >
                <template v-slot:option="scope">
                  <q-item v-bind="scope.itemProps">
                    <q-item-section>
                      <q-item-label>{{ scope.opt.name }}</q-item-label>
                      <q-item-label caption
                        >{{ scope.opt.phone || '' }} | {{ scope.opt.customer_code }}</q-item-label
                      >
                    </q-item-section>
                  </q-item>
                </template>
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
            </div>
            <div class="col-12 text-caption text-grey-5 q-mt-sm">
              <q-icon name="info" size="14px" class="q-mr-xs" />
              Select an existing customer or leave blank for walk-in
            </div>
          </div>
          <q-stepper-navigation>
            <q-btn color="primary" label="Next" icon-right="chevron_right" @click="step = 2" />
          </q-stepper-navigation>
        </q-step>

        <!-- Step 2: Device Details -->
        <q-step :name="2" title="Device Details" icon="devices" :done="step > 2">
          <div class="row q-col-gutter-md">
            <div class="col-12 col-md-4">
              <q-select
                v-model="form.device_type"
                label="Device Type *"
                :options="deviceTypeOptions"
                option-value="name"
                option-label="name"
                emit-value
                map-options
                outlined
                dense
                :dark="$q.dark.isActive"
                :rules="[(v) => !!v || 'Required']"
              >
                <template v-slot:option="scope">
                  <q-item v-bind="scope.itemProps">
                    <q-item-section avatar>
                      <q-avatar
                        :icon="scope.opt.icon || 'devices'"
                        size="28px"
                        color="primary"
                        text-color="white"
                      />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label>{{ scope.opt.name }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </template>
                <template v-slot:after>
                  <q-btn
                    flat
                    round
                    icon="add"
                    color="primary"
                    @click="openAddDeviceTypeDialog"
                    dense
                  >
                    <q-tooltip>Add New Device Type</q-tooltip>
                  </q-btn>
                </template>
                <template v-slot:no-option>
                  <q-item clickable @click="openAddDeviceTypeDialog">
                    <q-item-section class="text-primary text-weight-bold"
                      >+ Add New Device Type</q-item-section
                    >
                  </q-item>
                </template>
              </q-select>
            </div>
            <div class="col-12 col-md-4">
              <q-input
                v-model="form.brand"
                label="Brand"
                outlined
                dense
                :dark="$q.dark.isActive"
                placeholder="e.g. HP, Dell, Lenovo"
              />
            </div>
            <div class="col-12 col-md-4">
              <q-input
                v-model="form.model"
                label="Model"
                outlined
                dense
                :dark="$q.dark.isActive"
                placeholder="e.g. Pavilion 15"
              />
            </div>
            <div class="col-12 col-md-6">
              <q-input
                v-model="form.serial_no"
                label="Serial Number"
                outlined
                dense
                :dark="$q.dark.isActive"
                placeholder="Device serial / tag"
              />
            </div>
            <div class="col-12">
              <div class="text-subtitle2 text-weight-bold q-mb-sm">Accessories Received</div>
              <div class="row q-gutter-sm">
                <q-checkbox
                  v-for="acc in accessoryOptions"
                  :key="acc"
                  v-model="form.accessories"
                  :val="acc"
                  :label="acc"
                  dense
                  :dark="$q.dark.isActive"
                  color="primary"
                />
              </div>
            </div>
          </div>
          <q-stepper-navigation>
            <q-btn color="primary" label="Next" icon-right="chevron_right" @click="step = 3" />
            <q-btn flat label="Back" @click="step = 1" class="q-ml-sm" />
          </q-stepper-navigation>
        </q-step>

        <!-- Step 3: Issue & Assignment -->
        <q-step :name="3" title="Issue & Assignment" icon="report_problem" :done="step > 3">
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-input
                v-model="form.issue_reported"
                label="Issue Reported by Customer *"
                type="textarea"
                rows="3"
                outlined
                :dark="$q.dark.isActive"
                :rules="[(v) => !!v || 'Describe the issue']"
                placeholder="Customer's description of the problem..."
              />
            </div>
            <div class="col-12 col-md-6">
              <q-select
                v-model="form.priority"
                label="Priority"
                :options="priorityOptions"
                emit-value
                map-options
                outlined
                dense
                :dark="$q.dark.isActive"
              />
            </div>
            <div class="col-12 col-md-6">
              <q-select
                v-model="form.technician_id"
                label="Assign Technician"
                :options="technicianOptions"
                option-value="id"
                option-label="label"
                emit-value
                map-options
                clearable
                outlined
                dense
                :dark="$q.dark.isActive"
              />
            </div>
          </div>
          <q-stepper-navigation>
            <q-btn color="primary" label="Next" icon-right="chevron_right" @click="step = 4" />
            <q-btn flat label="Back" @click="step = 2" class="q-ml-sm" />
          </q-stepper-navigation>
        </q-step>

        <!-- Step 4: Dates & Notes -->
        <q-step :name="4" title="Schedule & Notes" icon="calendar_today">
          <div class="row q-col-gutter-md">
            <div class="col-12 col-md-6">
              <q-input
                v-model="form.estimated_fix_date"
                label="Estimated Fix Date"
                type="date"
                outlined
                dense
                :dark="$q.dark.isActive"
              />
            </div>
            <div class="col-12 col-md-6">
              <q-input
                v-model="form.warranty_days"
                label="Warranty (days)"
                type="number"
                outlined
                dense
                :dark="$q.dark.isActive"
                :rules="[(v) => v >= 0 || 'Must be >= 0']"
              />
            </div>
            <div class="col-12">
              <q-input
                v-model="form.inspection_notes"
                label="Initial Inspection Notes"
                type="textarea"
                rows="3"
                outlined
                :dark="$q.dark.isActive"
                placeholder="Any initial observations or notes..."
              />
            </div>
          </div>
          <q-stepper-navigation class="q-mt-md">
            <q-btn
              color="primary"
              icon="save"
              :label="isEdit ? 'Update Service Job' : 'Create Service Job'"
              @click="submitJob"
              :loading="store.loading"
              size="lg"
            />
            <q-btn flat label="Back" @click="step = 3" class="q-ml-sm" />
          </q-stepper-navigation>
        </q-step>
      </q-stepper>
    </q-card>

    <CustomerDialog
      v-if="showCustomerDialog"
      v-model="showCustomerDialog"
      @saved="onCustomerSaved"
    />

    <!-- Add Device Type Dialog -->
    <q-dialog v-model="showAddDeviceTypeDialog" persistent>
      <q-card style="min-width: 340px" :dark="$q.dark.isActive">
        <q-card-section class="row items-center">
          <div class="text-h6">Add Device Type</div>
          <q-space /><q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-gutter-md">
          <q-input
            v-model="newDeviceTypeName"
            label="Device Type Name *"
            outlined
            dense
            autofocus
            :dark="$q.dark.isActive"
            placeholder="e.g. CCTV Camera, Gaming Console"
            @keyup.enter="saveNewDeviceType"
          />
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            label="Add"
            icon="add"
            @click="saveNewDeviceType"
            :loading="savingDeviceType"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, reactive, onMounted, onUnmounted, watch, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useServiceStore } from 'src/stores/serviceStore'
import { useAuthStore } from 'src/stores/auth'
import { supabase } from 'src/boot/supabase'
import CustomerDialog from 'src/components/customers/CustomerDialog.vue'

const props = defineProps({
  id: { type: String, default: null },
})

const $q = useQuasar()
const router = useRouter()
const store = useServiceStore()
const authStore = useAuthStore()

const isEdit = computed(() => !!props.id)

const step = ref(1)
const stepperRef = ref(null)
const customers = ref([])
const filteredCustomers = ref([])
const technicianOptions = ref([])
const showCustomerDialog = ref(false)

const form = reactive({
  job_no: '',
  customer_id: null,
  device_type: null,   // will be set from service_device_types after load
  brand: '',
  model: '',
  serial_no: '',
  accessories: [],
  issue_reported: '',
  priority: 'normal',
  technician_id: null,
  estimated_fix_date: '',
  warranty_days: 30,
  inspection_notes: '',
})

const deviceTypeOptions = ref([])
const showAddDeviceTypeDialog = ref(false)
const newDeviceTypeName = ref('')
const savingDeviceType = ref(false)
let realtimeChannel = null

const priorityOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Normal', value: 'normal' },
  { label: 'High', value: 'high' },
  { label: 'Urgent', value: 'urgent' },
]

const accessoryOptions = [
  'Charger/Adapter',
  'Battery',
  'Bag/Case',
  'Mouse',
  'Keyboard',
  'USB Cable',
  'HDMI Cable',
  'Power Cord',
  'Stylus',
  'Other',
]

function filterCustomers(val, update) {
  update(() => {
    const q = (val || '').toLowerCase()
    filteredCustomers.value = q
      ? customers.value.filter(
          (c) =>
            c.name.toLowerCase().includes(q) ||
            (c.phone || '').includes(q) ||
            (c.customer_code || '').includes(q),
        )
      : customers.value
  })
}

async function loadDeviceTypes() {
  const companyId = authStore.currentBranch?.company_id
  if (!companyId) return
  const { data, error } = await supabase
    .from('service_device_types')
    .select('id, name, icon, sort_order')
    .eq('company_id', companyId)
    .eq('is_active', true)
    .order('sort_order', { ascending: true })
  if (error) {
    console.error('[CreateJob] Failed to load device types:', error)
    return
  }
  deviceTypeOptions.value = data || []
  // Auto-select first option if nothing is selected yet (new job only)
  if (!form.device_type && deviceTypeOptions.value.length > 0) {
    form.device_type = deviceTypeOptions.value[0].name
  }
}

function setupRealtimeDeviceTypes() {
  const companyId = authStore.currentBranch?.company_id
  if (!companyId) return
  if (realtimeChannel) supabase.removeChannel(realtimeChannel)
  realtimeChannel = supabase
    .channel('service_device_types_' + companyId)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'service_device_types',
        filter: `company_id=eq.${companyId}`,
      },
      () => {
        loadDeviceTypes()
      },
    )
    .subscribe()
}

function openAddDeviceTypeDialog() {
  newDeviceTypeName.value = ''
  showAddDeviceTypeDialog.value = true
}

async function saveNewDeviceType() {
  const name = newDeviceTypeName.value.trim()
  if (!name) {
    $q.notify({ type: 'warning', message: 'Device type name is required' })
    return
  }
  const companyId = authStore.currentBranch?.company_id
  if (!companyId) return
  savingDeviceType.value = true
  try {
    const { data, error } = await supabase
      .from('service_device_types')
      .insert({ company_id: companyId, name, icon: 'devices' })
      .select()
      .single()
    if (error) throw error
    // Append and select it
    deviceTypeOptions.value.push(data)
    form.device_type = data.name
    showAddDeviceTypeDialog.value = false
    $q.notify({ type: 'positive', message: `Device type "${name}" added` })
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  } finally {
    savingDeviceType.value = false
  }
}

async function loadCustomers() {
  const companyId = authStore.currentBranch?.company_id
  if (!companyId) return
  const { data, error } = await supabase
    .from('customers')
    .select('id, name, phone, customer_code')
    .eq('company_id', companyId)
    .eq('status', 'active')
    .order('name')
    .limit(500)
  if (error) {
    console.error('[CreateJob] Failed to load customers:', error)
  }
  customers.value = data || []
  filteredCustomers.value = data || []
}

async function loadTechnicians() {
  // Get staff listing for technician dropdown
  try {
    const {
      data: { session },
    } = await supabase.auth.getSession()
    const res = await fetch(
      `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/admin-manage-users`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
          apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
        },
        body: JSON.stringify({ action: 'list' }),
      },
    )
    const json = await res.json()
    const users = json.users || []
    technicianOptions.value = users.map((u) => ({
      id: u.id,
      label: u.full_name || u.email,
    }))
  } catch {
    technicianOptions.value = []
  }
}

async function submitJob() {
  // Validate device type
  if (!form.device_type) {
    $q.notify({ type: 'warning', message: 'Please select a device type' })
    step.value = 2
    return
  }

  // Validate issue description
  if (!form.issue_reported) {
    $q.notify({ type: 'warning', message: 'Please describe the issue reported by customer' })
    step.value = 3
    return
  }

  try {
    const commonData = {
      customer_id: form.customer_id,
      device_type: form.device_type,
      brand: form.brand,
      model: form.model,
      serial_no: form.serial_no,
      accessories_received: form.accessories,
      priority: form.priority,
      estimated_fix_date: form.estimated_fix_date || null,
      warranty_days: form.warranty_days || 0,
      inspection_notes: form.inspection_notes,
    }

    let job
    if (isEdit.value) {
      job = await store.updateJob(props.id, {
        ...commonData,
        issue_reported_by_customer: form.issue_reported,
        assigned_technician_id: form.technician_id,
      })
      $q.notify({
        type: 'positive',
        icon: 'check_circle',
        message: `Service Job Updated: ${job.job_no}`,
      })
    } else {
      job = await store.createJob({
        ...commonData,
        issue_reported: form.issue_reported,
        technician_id: form.technician_id,
      })
      $q.notify({
        type: 'positive',
        icon: 'check_circle',
        message: `Service Job Created: ${job.job_no}`,
        caption: 'You can now add diagnosis & parts',
      })
    }

    router.push(`/services/jobs/${job.id}`)
  } catch (err) {
    const action = isEdit.value ? 'update' : 'create'
    $q.notify({ type: 'negative', message: `Failed to ${action} job: ` + err.message })
  }
}

function openCustomerDialog() {
  showCustomerDialog.value = true
}

function onCustomerSaved(newCustomer) {
  // Update local customer arrays with new customer
  customers.value.push(newCustomer)
  filteredCustomers.value = [...customers.value]

  // Select it
  form.customer_id = newCustomer.id
  showCustomerDialog.value = false
}

onMounted(async () => {
  if (authStore.currentBranch?.company_id) {
    await Promise.all([loadCustomers(), loadTechnicians(), loadDeviceTypes()])
    setupRealtimeDeviceTypes()

    if (isEdit.value) {
      $q.loading.show({ message: 'Fetching job details...' })
      try {
        const { data, error } = await supabase
          .from('service_jobs')
          .select('*')
          .eq('id', props.id)
          .single()
        if (error) throw error

        if (data) {
          form.job_no = data.job_no
          form.customer_id = data.customer_id
          form.device_type = data.device_type
          form.brand = data.brand || ''
          form.model = data.model || ''
          form.serial_no = data.serial_no || ''
          form.accessories = data.accessories_received || []
          form.issue_reported = data.issue_reported_by_customer || ''
          form.priority = data.priority
          form.technician_id = data.assigned_technician_id
          form.estimated_fix_date = data.estimated_fix_date || ''
          form.warranty_days = data.warranty_days || 0
          form.inspection_notes = data.inspection_notes || ''
        }
      } catch (err) {
        $q.notify({ type: 'negative', message: 'Failed to load job: ' + err.message })
        router.push('/services/jobs')
      } finally {
        $q.loading.hide()
      }
    }
  }
})

watch(
  () => authStore.currentBranch?.company_id,
  async (companyId) => {
    if (companyId) {
      await Promise.all([loadCustomers(), loadTechnicians(), loadDeviceTypes()])
      setupRealtimeDeviceTypes()
    }
  },
)

onUnmounted(() => {
  if (realtimeChannel) supabase.removeChannel(realtimeChannel)
})
</script>

<style scoped lang="scss">
.text-gradient {
  background: linear-gradient(135deg, var(--q-primary), #a855f7);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.glass-card {
  background: v-bind("$q.dark.isActive ? 'rgba(30,30,40,0.45)' : 'rgba(255,255,255,0.6)'");
  backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'");
  border-radius: 20px;
  box-shadow: 0 4px 20px 0 rgba(0, 0, 0, 0.02);
  padding: 8px;
}
</style>

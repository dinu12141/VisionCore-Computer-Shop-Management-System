<template>
  <q-dialog ref="dialogRef" persistent backdrop-filter="blur(4px)">
    <q-card style="width: 500px; max-width: 90vw; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">
          {{ isEdit ? 'Edit Customer' : 'Register New Customer' }}
        </div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-separator class="q-my-sm" />

      <q-card-section class="q-pa-md">
        <q-form @submit="onSubmit" class="q-gutter-md">
          <div class="row q-col-gutter-sm">
            <div class="col-12">
              <q-select
                v-model="form.category_id"
                :options="filteredCategoryOptions"
                label="Customer Category *"
                outlined
                dense
                emit-value
                map-options
                fill-input
                hide-selected
                use-input
                input-debounce="0"
                @filter="filterCategories"
                @new-value="handleNewCategory"
                hint="Type to search or add new category"
                :rules="[(val) => !!val || 'Category is required']"
              >
                <template v-slot:no-option>
                  <q-item>
                    <q-item-section class="text-grey">
                      No results. Type and press Enter to add.
                    </q-item-section>
                  </q-item>
                </template>
              </q-select>
            </div>

            <div class="col-12">
              <q-input
                v-model="form.name"
                label="Full Name / Business Name *"
                outlined
                dense
                :rules="[(val) => !!val || 'Name is required']"
              />
            </div>

            <div class="col-6">
              <q-input
                v-model="form.phone"
                label="Phone Number"
                outlined
                dense
                mask="###-#######"
                unmasked-value
              />
            </div>

            <div class="col-6">
              <q-input v-model="form.nic_brn" label="NIC / BRN" outlined dense />
            </div>

            <div class="col-12">
              <q-input v-model="form.tax_number" label="Tax Number (VAT/TIN)" outlined dense />
            </div>

            <div class="col-12">
              <q-input v-model="form.email" label="Email Address" outlined dense type="email" />
            </div>

            <div class="col-12">
              <q-input
                v-model="form.address"
                label="Address"
                outlined
                dense
                type="textarea"
                rows="2"
              />
            </div>

            <div class="col-12">
              <q-select
                v-model="form.status"
                :options="['active', 'inactive']"
                label="Status"
                outlined
                dense
                class="text-capitalize"
              />
            </div>
          </div>

          <div class="row reverse q-mt-lg">
            <q-btn
              label="Save Customer"
              type="submit"
              color="primary"
              :loading="loading"
              class="q-px-lg text-weight-bold"
              unelevated
            />
            <q-btn label="Cancel" flat v-close-popup class="q-mr-sm" />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useCustomerStore } from 'src/stores/customerStore'
import { useQuasar } from 'quasar'

const props = defineProps({
  customer: { type: Object, default: null },
  isEdit: { type: Boolean, default: false },
})

const emit = defineEmits(['saved'])

const $q = useQuasar()
const customerStore = useCustomerStore()
const loading = ref(false)
const dialogRef = ref(null)

const form = reactive({
  id: props.customer?.id || null,
  category_id: props.customer?.category_id || null,
  name: props.customer?.name || '',
  phone: props.customer?.phone || '',
  email: props.customer?.email || '',
  address: props.customer?.address || '',
  nic_brn: props.customer?.nic_brn || '',
  tax_number: props.customer?.tax_number || '',
  status: props.customer?.status || 'active',
})

const filterText = ref('')

const filteredCategoryOptions = computed(() => {
  const options = customerStore.categories.map((c) => ({ label: c.name, value: c.id }))
  if (!filterText.value) return options
  const needle = filterText.value.toLowerCase()
  return options.filter((v) => v.label.toLowerCase().includes(needle))
})

onMounted(async () => {
  if (customerStore.categories.length === 0) {
    await customerStore.fetchCategories()
  }
})

function filterCategories(val, update) {
  update(() => {
    filterText.value = val
  })
}

async function handleNewCategory(val, done) {
  if (!val) return

  try {
    loading.value = true
    const newCat = await customerStore.createCategory(val)
    $q.notify({ type: 'positive', message: `Category "${val}" added` })
    done(newCat.id, 'toggle')
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message || 'Failed to add category' })
  } finally {
    loading.value = false
  }
}

async function onSubmit() {
  loading.value = true
  try {
    let savedData
    if (props.isEdit) {
      savedData = await customerStore.updateCustomer(form.id, { ...form })
      $q.notify({ type: 'positive', message: 'Customer updated' })
    } else {
      // Duplicate Check
      const existing = await customerStore.checkDuplicate(form.name, form.phone)
      if (existing) {
        const confirm = await new Promise((resolve) => {
          $q.dialog({
            title: 'Duplicate Found',
            message: `A customer named "${form.name}" with phone "${form.phone}" already exists. Do you want to use the existing one or create a new entry?`,
            persistent: true,
            ok: { label: 'Use Existing', color: 'primary', flat: true },
            cancel: { label: 'Create Anyway', color: 'negative', flat: true },
          })
            .onOk(() => resolve('use'))
            .onCancel(() => resolve('create'))
            .onDismiss(() => resolve('cancel'))
        })

        if (confirm === 'cancel') return
        if (confirm === 'use') {
          emit('saved', existing)
          dialogRef.value.hide()
          return
        }
      }

      savedData = await customerStore.createCustomer({ ...form })
      $q.notify({ type: 'positive', message: 'Customer registered' })
    }
    emit('saved', savedData)
    dialogRef.value.hide()
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message || 'Operation failed' })
  } finally {
    loading.value = false
  }
}

// Support for opening the dialog programmatically if needed
defineExpose({
  show: () => dialogRef.value.show(),
  hide: () => dialogRef.value.hide(),
})
</script>

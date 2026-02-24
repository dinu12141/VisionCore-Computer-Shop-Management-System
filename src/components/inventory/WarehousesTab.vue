<template>
  <div class="q-pa-md">
    <div class="row items-center q-mb-md">
      <div class="text-h6"><q-icon name="warehouse" class="q-mr-sm" />Warehouse Management</div>
      <q-space />
      <q-btn color="primary" icon="add" label="Add Warehouse" @click="openCreate" />
    </div>

    <q-inner-loading :showing="loading" :dark="$q.dark.isActive" />

    <div v-if="!loading" class="row q-col-gutter-md">
      <div v-for="wh in warehouses" :key="wh.id" class="col-12 col-sm-6 col-md-4">
        <q-card
          class="warehouse-card"
          :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
          flat
          bordered
        >
          <q-card-section>
            <div class="row items-center q-mb-sm">
              <q-avatar
                size="40px"
                :color="getWhColor(wh.warehouse_type)"
                text-color="white"
                :icon="getWhIcon(wh.warehouse_type)"
              />
              <div class="q-ml-sm">
                <div class="text-subtitle1 text-weight-bold">{{ wh.name }}</div>
                <div class="text-caption text-grey-5">{{ wh.code }}</div>
              </div>
              <q-space />
              <q-btn-dropdown flat dense round icon="more_vert" color="grey-5">
                <q-list :dark="$q.dark.isActive">
                  <q-item clickable v-close-popup @click="openEdit(wh)">
                    <q-item-section avatar><q-icon name="edit" /></q-item-section>
                    <q-item-section>Edit</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="toggleActive(wh)">
                    <q-item-section avatar>
                      <q-icon :name="wh.is_active ? 'block' : 'check_circle'" />
                    </q-item-section>
                    <q-item-section>{{ wh.is_active ? 'Deactivate' : 'Activate' }}</q-item-section>
                  </q-item>
                </q-list>
              </q-btn-dropdown>
            </div>

            <q-separator :dark="$q.dark.isActive" class="q-my-sm" />

            <div class="row q-gutter-sm text-caption">
              <q-chip
                dense
                size="sm"
                :color="getWhColor(wh.warehouse_type)"
                text-color="white"
                :icon="getWhIcon(wh.warehouse_type)"
              >
                {{ (wh.warehouse_type || '').replace('_', ' ') }}
              </q-chip>
              <q-chip
                v-if="wh.is_default"
                dense
                size="sm"
                color="primary"
                text-color="white"
                icon="star"
              >
                Default
              </q-chip>
              <q-chip
                v-if="wh.allow_negative_stock"
                dense
                size="sm"
                color="amber"
                text-color="black"
                icon="remove_circle"
              >
                Allows Negative
              </q-chip>
              <q-chip
                v-if="!wh.is_active"
                dense
                size="sm"
                color="red"
                text-color="white"
                icon="block"
              >
                Inactive
              </q-chip>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Add/Edit Dialog -->
    <q-dialog v-model="showDialog" persistent>
      <q-card
        :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
        style="min-width: 450px"
      >
        <q-card-section class="row items-center">
          <div class="text-h6">{{ editingWh ? 'Edit Warehouse' : 'Add Warehouse' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        <q-separator :dark="$q.dark.isActive" />
        <q-card-section class="q-gutter-md">
          <q-input
            :dark="$q.dark.isActive"
            outlined
            v-model="form.code"
            label="Warehouse Code"
            :rules="[(v) => !!v || 'Required']"
          />
          <q-input
            :dark="$q.dark.isActive"
            outlined
            v-model="form.name"
            label="Warehouse Name"
            :rules="[(v) => !!v || 'Required']"
          />
          <q-select
            :dark="$q.dark.isActive"
            outlined
            v-model="form.warehouse_type"
            :options="typeOptions"
            label="Type"
            emit-value
            map-options
          />
          <q-toggle
            :dark="$q.dark.isActive"
            v-model="form.is_default"
            label="Default Warehouse"
            color="primary"
          />
          <q-toggle
            :dark="$q.dark.isActive"
            v-model="form.allow_negative_stock"
            label="Allow Negative Stock"
            color="orange"
          />
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            :label="editingWh ? 'Update' : 'Create'"
            icon="save"
            :loading="saving"
            @click="saveWarehouse"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useWarehouseList } from 'src/services/inventoryService'

const $q = useQuasar()
const { warehouses, loading, listWarehouses, createWarehouse, updateWarehouse } = useWarehouseList()

const showDialog = ref(false)
const editingWh = ref(null)
const saving = ref(false)

const emptyForm = {
  code: '',
  name: '',
  warehouse_type: 'kitchen',
  is_default: false,
  allow_negative_stock: false,
}
const form = reactive({ ...emptyForm })

const typeOptions = [
  { label: 'Main Store', value: 'main_store' },
  { label: 'Kitchen', value: 'kitchen' },
  { label: 'Bar', value: 'bar' },
  { label: 'Freezer', value: 'freezer' },
  { label: 'Dry Store', value: 'dry_store' },
  { label: 'Other', value: 'other' },
]

onMounted(() => listWarehouses())

function getWhIcon(type) {
  const map = {
    main_store: 'warehouse',
    kitchen: 'soup_kitchen',
    bar: 'local_bar',
    freezer: 'ac_unit',
    dry_store: 'inventory_2',
  }
  return map[type] || 'store'
}

function getWhColor(type) {
  const map = {
    main_store: 'teal',
    kitchen: 'orange',
    bar: 'purple',
    freezer: 'cyan',
    dry_store: 'brown',
  }
  return map[type] || 'grey'
}

function openCreate() {
  editingWh.value = null
  Object.assign(form, emptyForm)
  showDialog.value = true
}

function openEdit(wh) {
  editingWh.value = wh
  Object.assign(form, {
    code: wh.code,
    name: wh.name,
    warehouse_type: wh.warehouse_type,
    is_default: wh.is_default,
    allow_negative_stock: wh.allow_negative_stock,
  })
  showDialog.value = true
}

async function saveWarehouse() {
  if (!form.code || !form.name) {
    $q.notify({ type: 'warning', message: 'Code and Name are required.' })
    return
  }
  saving.value = true
  try {
    if (editingWh.value) {
      await updateWarehouse(editingWh.value.id, { ...form })
      $q.notify({ type: 'positive', message: 'Warehouse updated!' })
    } else {
      await createWarehouse({ ...form, is_active: true })
      $q.notify({ type: 'positive', message: 'Warehouse created!' })
    }
    showDialog.value = false
    await listWarehouses()
  } catch (e) {
    $q.notify({ type: 'negative', message: e.message || 'Failed to save warehouse.' })
  } finally {
    saving.value = false
  }
}

async function toggleActive(wh) {
  try {
    await updateWarehouse(wh.id, { is_active: !wh.is_active })
    $q.notify({
      type: 'info',
      message: `${wh.name} ${wh.is_active ? 'deactivated' : 'activated'}.`,
    })
    await listWarehouses()
  } catch (e) {
    $q.notify({ type: 'negative', message: e.message || 'Failed to update warehouse.' })
  }
}
</script>

<style scoped>
.warehouse-card {
  transition:
    transform 0.2s,
    box-shadow 0.2s;
}
.warehouse-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}
</style>

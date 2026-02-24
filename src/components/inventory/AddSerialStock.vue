<template>
  <q-card
    :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
    style="min-width: 600px"
  >
    <q-card-section class="row items-center">
      <div class="text-h6">Add New Stock (Serial Numbers)</div>
      <q-space />
      <q-btn icon="close" flat round dense v-close-popup />
    </q-card-section>

    <q-separator :dark="$q.dark.isActive" />

    <q-card-section class="q-gutter-md">
      <!-- Product Selection -->
      <q-select
        :dark="$q.dark.isActive"
        outlined
        v-model="selectedProduct"
        :options="productOptions"
        label="Select Product"
        hint="Search by name or brand"
        use-input
        fill-input
        hide-selected
        @filter="filterProducts"
        :loading="loadingProducts"
      >
        <template v-slot:no-option>
          <q-item>
            <q-item-section class="text-grey"> No results found </q-item-section>
          </q-item>
        </template>
      </q-select>

      <!-- Input Mode Toggle -->
      <div class="row items-center q-gutter-sm q-mt-md">
        <div class="text-caption" :class="$q.dark.isActive ? 'text-grey-4' : 'text-grey-7'">
          Input Mode:
        </div>
        <q-btn-toggle
          v-model="inputMode"
          flat
          dense
          toggle-color="primary"
          :options="[
            { label: 'Single Entry', value: 'single' },
            { label: 'Bulk Add (Paste)', value: 'bulk' },
          ]"
        />
      </div>

      <!-- Single Entry Field -->
      <div v-if="inputMode === 'single'" class="q-mt-sm">
        <q-input
          :dark="$q.dark.isActive"
          outlined
          v-model="serialInput"
          label="Enter Serial Number"
          placeholder="Type and press Enter"
          @keyup.enter="addSerial"
        >
          <template v-slot:append>
            <q-btn round dense flat icon="add" @click="addSerial" />
          </template>
        </q-input>
      </div>

      <!-- Bulk Entry Field -->
      <div v-else class="q-mt-sm">
        <q-input
          :dark="$q.dark.isActive"
          outlined
          type="textarea"
          v-model="bulkInput"
          label="Paste Serial Numbers"
          placeholder="Paste one per line or separated by commas"
          rows="4"
        />
        <div class="row justify-between items-center q-mt-sm">
          <div class="text-caption text-grey">Serials will be added to the list below.</div>
          <q-btn
            outline
            dense
            color="primary"
            label="Process & Add All"
            icon="checklist"
            @click="processBulkInput"
          />
        </div>
      </div>

      <!-- Added Serials Display -->
      <div class="q-mt-lg">
        <div class="row justify-between items-center q-mb-sm">
          <div class="text-subtitle1 text-weight-bold">Serials to Save ({{ serials.length }})</div>
          <q-btn
            v-if="serials.length > 0"
            flat
            dense
            label="Clear All"
            color="red-4"
            icon="delete_sweep"
            @click="serials = []"
          />
        </div>

        <div
          v-if="serials.length > 0"
          class="serials-container q-pa-sm rounded-borders"
          :class="$q.dark.isActive ? 'bg-grey-10' : 'bg-grey-2'"
        >
          <q-chip
            v-for="(sn, index) in serials"
            :key="index"
            removable
            @remove="removeSerial(index)"
            color="primary"
            text-color="white"
            class="q-ma-xs"
            dense
          >
            {{ sn }}
          </q-chip>
        </div>
        <div v-else class="text-center q-pa-xl text-grey-6 border-dashed rounded-borders">
          <q-icon name="qr_code_scanner" size="md" class="q-mb-sm block-center" />
          <div>No serial numbers added yet.</div>
        </div>
      </div>
    </q-card-section>

    <q-separator :dark="$q.dark.isActive" />

    <q-card-actions align="right" class="q-pa-md">
      <q-btn flat label="Cancel" v-close-popup />
      <q-btn
        color="primary"
        label="Save to Inventory"
        icon="save"
        :loading="saving"
        :disable="!selectedProduct || serials.length === 0"
        @click="saveItems"
      />
    </q-card-actions>
  </q-card>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'

const $q = useQuasar()
const authStore = useAuthStore()

// State
const selectedProduct = ref(null)
const inputMode = ref('single')
const serialInput = ref('')
const bulkInput = ref('')
const serials = ref([])
const saving = ref(false)
const loadingProducts = ref(false)
const rawProducts = ref([])
const productOptions = ref([])

// Logic
async function fetchProducts() {
  loadingProducts.value = true
  try {
    const { data, error } = await supabase
      .from('items')
      .select('id, name, code')
      .eq('is_active', true)
      .order('name')

    if (error) throw error
    rawProducts.value = data || []
    productOptions.value = rawProducts.value.map((p) => ({
      label: `${p.name} (${p.code})`,
      value: p.id,
    }))
  } catch {
    $q.notify({ type: 'negative', message: 'Failed to fetch products' })
  } finally {
    loadingProducts.value = false
  }
}

function filterProducts(val, update) {
  if (val === '') {
    update(() => {
      productOptions.value = rawProducts.value.map((p) => ({
        label: `${p.name} (${p.code})`,
        value: p.id,
      }))
    })
    return
  }

  update(() => {
    const needle = val.toLowerCase()
    productOptions.value = rawProducts.value
      .filter(
        (v) =>
          v.name.toLowerCase().indexOf(needle) > -1 || v.code.toLowerCase().indexOf(needle) > -1,
      )
      .map((p) => ({
        label: `${p.name} (${p.code})`,
        value: p.id,
      }))
  })
}

function addSerial() {
  const sn = serialInput.value.trim()
  if (!sn) return

  if (serials.value.includes(sn)) {
    $q.notify({ type: 'warning', message: 'Serial number already in list' })
  } else {
    serials.value.unshift(sn)
    serialInput.value = ''
  }
}

function processBulkInput() {
  if (!bulkInput.value.trim()) return

  // Split by newline, comma, or tab
  const lines = bulkInput.value.split(/[\n,\t]+/)
  const newSerials = []
  let duplicates = 0

  lines.forEach((line) => {
    const clean = line.trim()
    if (clean) {
      if (!serials.value.includes(clean) && !newSerials.includes(clean)) {
        newSerials.push(clean)
      } else {
        duplicates++
      }
    }
  })

  serials.value = [...newSerials, ...serials.value]
  bulkInput.value = ''

  $q.notify({
    type: 'positive',
    message:
      `Added ${newSerials.length} serial numbers` +
      (duplicates ? `. Skipped ${duplicates} duplicates.` : ''),
    position: 'top',
  })
}

function removeSerial(index) {
  serials.value.splice(index, 1)
}

async function saveItems() {
  if (!selectedProduct.value || serials.value.length === 0) return

  saving.value = true
  try {
    const companyId = authStore.currentBranch?.company_id

    // In a real scenario, we'd insert into a 'item_serials' table.
    // For now, I'll mock the insertion or assume the table exists as per our schema design.
    // Each SN will be linked to the product ID.

    const payload = serials.value.map((sn) => ({
      product_id: selectedProduct.value.value,
      serial_number: sn,
      status: 'available',
      company_id: companyId,
    }))

    const { error } = await supabase.from('item_serials').insert(payload)

    if (error) throw error

    $q.notify({
      type: 'positive',
      message: `Successfully saved ${serials.value.length} units to inventory`,
    })

    // Clear form and close (or keep open if user wants to add more)
    serials.value = []
    selectedProduct.value = null
  } catch (err) {
    console.error(err)
    $q.notify({
      type: 'negative',
      message: err.message || 'Error saving stock. Make sure item_serials table exists.',
    })
  } finally {
    saving.value = false
  }
}

onMounted(fetchProducts)
</script>

<style scoped>
.serials-container {
  max-height: 300px;
  overflow-y: auto;
}
.border-dashed {
  border: 2px dashed v-bind("$q.dark.isActive ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'");
}
.rounded-borders {
  border-radius: 8px;
}
.block-center {
  display: block;
  margin: 0 auto;
}
</style>

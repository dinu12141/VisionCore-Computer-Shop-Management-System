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
        @keyup.enter="handleProductScanEnter"
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
          ref="serialInputRef"
          :dark="$q.dark.isActive"
          outlined
          v-model="serialInput"
          label="Enter Serial Number / Barcode"
          placeholder="Scan or type and press Enter"
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
import { createDocument, postDocument } from 'src/services/inventoryService'

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

const serialInputRef = ref(null)
const searchString = ref('')

// Logic
async function fetchProducts() {
  loadingProducts.value = true
  try {
    const companyId =
      authStore.currentBranch?.company_id ||
      authStore.user?.user_metadata?.company_id ||
      authStore.profile?.company_id
    if (!companyId) {
      $q.notify({ type: 'warning', message: 'No company context. Please select a branch.' })
      return
    }
    const { data, error } = await supabase
      .from('items')
      .select('id, name, code')
      .eq('company_id', companyId)
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
  searchString.value = val
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

function handleProductScanEnter() {
  const val = searchString.value?.trim()
  if (!val) return

  const match = rawProducts.value.find(
    (p) =>
      p.code?.toLowerCase() === val.toLowerCase() || p.name?.toLowerCase() === val.toLowerCase(),
  )

  if (match) {
    selectedProduct.value = {
      label: `${match.name} (${match.code})`,
      value: match.id,
    }
    inputMode.value = 'single'
    setTimeout(() => {
      serialInputRef.value?.focus()
    }, 150)
  }
}

function addSerial() {
  const sn = serialInput.value.trim()
  if (!sn) return

  if (serials.value.includes(sn)) {
    $q.notify({ type: 'warning', message: 'Serial number already in list' })
  } else {
    serials.value.unshift(sn)
    serialInput.value = ''

    // Maintain focus for continuous scanning
    setTimeout(() => {
      serialInputRef.value?.focus()
    }, 50)
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
    const companyId =
      authStore.currentBranch?.company_id ||
      authStore.user?.user_metadata?.company_id ||
      authStore.profile?.company_id

    if (!companyId) throw new Error('Company ID not found. Please select a branch.')

    const productId = selectedProduct.value.value

    // ── 1. Fetch current item serials + UOM + avg_cost ─────────────────────
    const { data: item, error: fetchErr } = await supabase
      .from('items')
      .select('serials, inventory_uom_id, avg_cost')
      .eq('id', productId)
      .single()

    if (fetchErr) throw fetchErr
    if (!item.inventory_uom_id) throw new Error('Item has no UOM configured. Cannot create stock adjustment.')

    const existingSerials = Array.isArray(item.serials) ? item.serials : []

    // ── 2. Merge serials — skip duplicates ─────────────────────────────────
    const newUnique = serials.value.filter((sn) => !existingSerials.includes(sn))
    if (newUnique.length === 0) {
      $q.notify({ type: 'warning', message: 'All serial numbers already exist in inventory.' })
      return
    }

    const mergedSerials = [...existingSerials, ...newUnique]

    // ── 3. Update items.serials JSONB directly ─────────────────────────────
    // (updateItem() whitelist intentionally excludes serials to prevent
    //  accidental overwrite during normal item edits — update directly here)
    const { error: updateErr } = await supabase
      .from('items')
      .update({ serials: mergedSerials })
      .eq('id', productId)

    if (updateErr) throw updateErr

    // ── 4. Get default active warehouse ────────────────────────────────────
    const { data: wh, error: whErr } = await supabase
      .from('warehouses')
      .select('id')
      .eq('company_id', companyId)
      .eq('is_active', true)
      .order('is_default', { ascending: false })
      .limit(1)
      .single()

    if (whErr || !wh) throw new Error('No active warehouse found. Cannot create stock adjustment.')

    // ── 5. Create ADJUSTMENT doc + post it (updates stock_on_hand) ─────────
    const doc = await createDocument(
      {
        doc_type: 'ADJUSTMENT',
        doc_date: new Date().toISOString().split('T')[0],
        warehouse_id: wh.id,
        remarks: `Bulk serial stock addition: ${newUnique.length} unit(s) added`,
      },
      [
        {
          item_id: productId,
          uom_id: item.inventory_uom_id,
          quantity: newUnique.length,
          unit_cost: item.avg_cost || 0,
          notes: `Serial numbers: ${newUnique.slice(0, 5).join(', ')}${newUnique.length > 5 ? ` +${newUnique.length - 5} more` : ''}`,
        },
      ],
    )

    await postDocument(doc.id)

    $q.notify({
      type: 'positive',
      message: `Successfully added ${newUnique.length} serial number(s) to inventory`,
    })

    serials.value = []
    selectedProduct.value = null
  } catch (err) {
    console.error('[AddSerialStock] saveItems error:', err)
    $q.notify({
      type: 'negative',
      message: err.message || 'Error saving stock to inventory.',
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

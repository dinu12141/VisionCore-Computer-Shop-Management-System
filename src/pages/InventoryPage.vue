<template>
  <q-page class="q-pa-md">
    <PageHeader
      title="Inventory Management"
      subtitle="Stock control, documents, and warehouse operations"
    >
      <template #actions>
        <q-btn
          outline
          color="secondary"
          icon="qr_code"
          label="Bulk Add SN"
          class="q-mr-sm"
          @click="showSerialDialog = true"
        />
        <q-btn
          outline
          color="primary"
          icon="add"
          label="New Document"
          @click="openCreateDocument"
        />
      </template>
    </PageHeader>

    <!-- Main tabs card -->
    <q-card class="q-mt-md" :class="$q.dark.isActive ? 'bg-grey-9' : 'bg-white'" flat bordered>
      <q-tabs
        v-model="tab"
        dense
        :class="$q.dark.isActive ? 'text-grey-4' : 'text-grey-7'"
        active-color="primary"
        indicator-color="primary"
        align="left"
        narrow-indicator
      >
        <q-tab v-for="t in tabs" :key="t.name" :name="t.name" :label="t.label" :icon="t.icon" />
      </q-tabs>

      <q-separator :dark="$q.dark.isActive" />

      <q-tab-panels v-model="tab" animated class="bg-transparent">
        <!-- Dashboard -->
        <q-tab-panel name="dashboard" class="q-pa-none">
          <DashboardTab />
        </q-tab-panel>

        <!-- Items Master -->
        <q-tab-panel name="items" class="q-pa-none">
          <ItemsTab />
        </q-tab-panel>

        <!-- Stock Levels -->
        <q-tab-panel name="stock" class="q-pa-none">
          <StockLevelsTab />
        </q-tab-panel>

        <!-- Warehouses -->
        <q-tab-panel name="warehouses" class="q-pa-none">
          <WarehousesTab />
        </q-tab-panel>

        <!-- Suppliers -->
        <q-tab-panel name="suppliers" class="q-pa-none">
          <SuppliersTab />
        </q-tab-panel>

        <!-- Documents List -->
        <q-tab-panel name="documents" class="q-pa-none">
          <DocumentsTab
            @create-document="openCreateDocument"
            @view-document="viewDocument"
            @edit-document="editDocument"
          />
        </q-tab-panel>

        <!-- Create / Edit Document -->
        <q-tab-panel name="doc-create" class="q-pa-none">
          <DocumentCreateTab
            :document="editingDocument"
            @back="tab = 'documents'"
            @saved="onDocumentSaved"
          />
        </q-tab-panel>

        <!-- Stock Ledger -->
        <q-tab-panel name="ledger" class="q-pa-none">
          <StockLedgerTab />
        </q-tab-panel>
      </q-tab-panels>
    </q-card>
    <!-- Bulk Serial Add Dialog -->
    <q-dialog v-model="showSerialDialog">
      <AddSerialStock @saved="showSerialDialog = false" />
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from 'components/common/PageHeader.vue'
import DashboardTab from 'components/inventory/DashboardTab.vue'
import ItemsTab from 'components/inventory/ItemsTab.vue'
import WarehousesTab from 'components/inventory/WarehousesTab.vue'
import DocumentsTab from 'components/inventory/DocumentsTab.vue'
import DocumentCreateTab from 'components/inventory/DocumentCreateTab.vue'
import StockLevelsTab from 'components/inventory/StockLevelsTab.vue'
import StockLedgerTab from 'components/inventory/StockLedgerTab.vue'
import SuppliersTab from 'components/inventory/SuppliersTab.vue'
import AddSerialStock from 'components/inventory/AddSerialStock.vue'

const route = useRoute()
const tab = ref('dashboard')
const showSerialDialog = ref(false)
const editingDocument = ref(null)

const tabs = [
  { name: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
  { name: 'items', label: 'Items', icon: 'category' },
  { name: 'stock', label: 'Stock Levels', icon: 'inventory_2' },
  { name: 'warehouses', label: 'Warehouses', icon: 'warehouse' },
  { name: 'suppliers', label: 'Suppliers', icon: 'local_shipping' },
  { name: 'documents', label: 'Documents', icon: 'description' },
  { name: 'ledger', label: 'Stock Ledger', icon: 'menu_book' },
]

// Sync tab with query param
watch(
  () => route.query.tab,
  (newTab) => {
    if (newTab && tabs.some((t) => t.name === newTab)) {
      tab.value = newTab
    }
  },
)

onMounted(() => {
  const queryTab = route.query.tab
  if (queryTab && tabs.some((t) => t.name === queryTab)) {
    tab.value = queryTab
  }
})

function openCreateDocument() {
  editingDocument.value = null
  tab.value = 'doc-create'
}

function viewDocument(doc) {
  editingDocument.value = { ...doc, lines: [] }
  tab.value = 'doc-create'
}

function editDocument(doc) {
  editingDocument.value = { ...doc, lines: [] }
  tab.value = 'doc-create'
}

function onDocumentSaved() {
  tab.value = 'documents'
}
</script>

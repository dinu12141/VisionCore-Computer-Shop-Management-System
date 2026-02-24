<template>
  <q-page class="q-pa-lg search-page">
    <div class="max-width-container mx-auto">
      <!-- Header -->
      <div class="row items-center q-mb-lg">
        <div class="col">
          <h1 class="text-h4 text-weight-bolder q-ma-none">Search Results</h1>
          <div class="text-subtitle2 text-grey-6 q-mt-xs">
            Showing results for
            <span class="text-weight-bold text-primary">"{{ route.query.q }}"</span>
            <span v-if="searchStore.searchTime" class="text-grey-4 q-ml-sm">
              · {{ searchStore.searchTime }}ms
            </span>
          </div>
        </div>
        <div class="col-auto">
          <q-btn flat color="primary" icon="arrow_back" label="Back" @click="router.back()" />
        </div>
      </div>

      <!-- Tabs + Results -->
      <q-card flat bordered class="border-radius-16 overflow-hidden shadow-1">
        <q-tabs
          v-model="tab"
          dense
          class="search-tabs"
          active-color="primary"
          indicator-color="primary"
          align="left"
          narrow-indicator
        >
          <q-tab name="all">
            <div class="row items-center no-wrap q-gutter-xs">
              <q-icon name="apps" />
              <span>All</span>
              <q-badge
                v-if="results.length"
                :label="results.length"
                color="grey-4"
                text-color="grey-8"
              />
            </div>
          </q-tab>
          <q-tab v-for="etype in entityTypes" :key="etype" :name="etype">
            <div class="row items-center no-wrap q-gutter-xs">
              <q-icon :name="getConfig(etype).icon" />
              <span>{{ getConfig(etype).label }}</span>
              <q-badge
                v-if="filteredByType(etype).length"
                :label="filteredByType(etype).length"
                color="grey-4"
                text-color="grey-8"
              />
            </div>
          </q-tab>
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="tab" animated class="bg-transparent">
          <q-tab-panel name="all" class="q-pa-none">
            <ResultsTable :rows="results" :loading="loading" />
          </q-tab-panel>
          <q-tab-panel v-for="etype in entityTypes" :key="etype" :name="etype" class="q-pa-none">
            <ResultsTable :rows="filteredByType(etype)" :loading="loading" />
          </q-tab-panel>
        </q-tab-panels>
      </q-card>
    </div>
  </q-page>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useGlobalSearchStore, ENTITY_CONFIG } from 'src/stores/globalSearch'
import { storeToRefs } from 'pinia'
import ResultsTable from 'src/components/common/ResultsTable.vue'

const route = useRoute()
const router = useRouter()
const searchStore = useGlobalSearchStore()
const { loading, results } = storeToRefs(searchStore)

const tab = ref('all')
const entityTypes = ['customer', 'invoice', 'item', 'supplier', 'payment']

function getConfig(type) {
  return ENTITY_CONFIG[type] || ENTITY_CONFIG.item
}

function filteredByType(type) {
  return results.value.filter((r) => r.entity_type === type)
}

async function fetchResults() {
  const q = route.query.q
  if (q) {
    await searchStore.performSearch(q, 50)
  }
}

watch(() => route.query.q, fetchResults)
onMounted(fetchResults)
</script>

<style scoped>
.search-page {
  background: var(--v-bg);
}
.border-radius-16 {
  border-radius: 16px;
}
.max-width-container {
  max-width: 1200px;
}
.mx-auto {
  margin-left: auto;
  margin-right: auto;
}
.search-tabs :deep(.q-tab--active) {
  background: rgba(var(--q-primary-rgb), 0.04);
}
</style>

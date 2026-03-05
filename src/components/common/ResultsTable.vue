<template>
  <q-table
    :rows="rows"
    :columns="columns"
    row-key="entity_id"
    flat
    bordered
    :loading="loading"
    :pagination="{ rowsPerPage: 15 }"
    class="results-table"
    :rows-per-page-options="[10, 15, 25, 50]"
  >
    <!-- Type Column -->
    <template v-slot:body-cell-type="props">
      <q-td :props="props">
        <q-chip
          dense
          :color="getConfig(props.row.entity_type).color"
          text-color="white"
          class="text-weight-bold text-uppercase type-chip"
        >
          <q-icon :name="getConfig(props.row.entity_type).icon" size="14px" class="q-mr-xs" />
          {{ props.row.entity_type }}
        </q-chip>
      </q-td>
    </template>

    <!-- Title Column -->
    <template v-slot:body-cell-title="props">
      <q-td :props="props">
        <div class="text-weight-bold text-subtitle1">{{ props.value }}</div>
        <div class="text-caption text-grey-6">{{ props.row.subtitle }}</div>
      </q-td>
    </template>

    <!-- Score Column -->
    <template v-slot:body-cell-score="props">
      <q-td :props="props">
        <q-badge
          :color="props.value === 1 ? 'green-6' : props.value === 2 ? 'amber-6' : 'grey-5'"
          :label="props.value === 1 ? 'Exact' : props.value === 2 ? 'Prefix' : 'Contains'"
          outline
          class="text-uppercase"
          style="font-size: 9px; font-weight: 700"
        />
      </q-td>
    </template>

    <!-- Actions Column -->
    <template v-slot:body-cell-actions="props">
      <q-td :props="props" align="center">
        <q-btn
          v-if="props.row.entity_type === 'customer'"
          flat
          round
          dense
          icon="receipt_long"
          color="green-7"
          size="sm"
          class="q-mr-xs"
          @click="router.push({ name: 'billing', query: { customerId: props.row.entity_id } })"
        >
          <q-tooltip>Create Invoice</q-tooltip>
        </q-btn>
        <q-btn
          flat
          round
          dense
          icon="launch"
          color="primary"
          size="sm"
          @click="navigate(props.row)"
          v-ripple
        >
          <q-tooltip>Open</q-tooltip>
        </q-btn>
      </q-td>
    </template>

    <!-- No Data -->
    <template v-slot:no-data>
      <div class="full-width column flex-center q-pa-xl text-grey-4">
        <q-icon name="search_off" size="64px" />
        <div class="text-h6 q-mt-md">No matching results</div>
        <div class="text-caption q-mt-xs">Try a different search term</div>
      </div>
    </template>
  </q-table>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { ENTITY_CONFIG } from 'src/stores/globalSearch'

const router = useRouter()

defineProps({
  rows: { type: Array, required: true },
  loading: { type: Boolean, default: false },
})

function getConfig(type) {
  return ENTITY_CONFIG[type] || ENTITY_CONFIG.item
}

const columns = [
  {
    name: 'type',
    label: 'Type',
    align: 'left',
    field: 'entity_type',
    sortable: true,
    style: 'width: 140px',
  },
  {
    name: 'title',
    label: 'Result',
    align: 'left',
    field: 'title',
    sortable: true,
  },
  {
    name: 'score',
    label: 'Match',
    align: 'center',
    field: 'score',
    sortable: true,
    style: 'width: 100px',
  },
  {
    name: 'actions',
    label: '',
    align: 'center',
    style: 'width: 60px',
  },
]

function navigate(res) {
  const config = ENTITY_CONFIG[res.entity_type]
  if (config) {
    router.push(config.route(res.entity_id))
  } else {
    console.warn('Unknown entity type:', res.entity_type)
  }
}
</script>

<style scoped>
.results-table {
  border-radius: 0 0 16px 16px;
}
.type-chip {
  min-width: 100px;
  justify-content: center;
  font-size: 10px;
  letter-spacing: 0.5px;
}
</style>

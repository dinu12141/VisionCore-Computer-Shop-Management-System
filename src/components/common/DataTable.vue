<template>
  <div class="v-data-table-wrap">
    <!-- Table Header -->
    <div
      v-if="title || $slots['top-right']"
      class="v-table-header row items-center q-px-lg q-py-md"
    >
      <div v-if="title" class="v-table-title">{{ title }}</div>
      <q-space />
      <div class="row q-gutter-sm">
        <slot name="top-right"></slot>
      </div>
    </div>

    <q-table
      :rows="rows"
      :columns="columns"
      :filter="filter"
      row-key="id"
      :dark="$q.dark.isActive"
      flat
      :loading="loading"
      class="v-table"
      :table-header-class="'v-table-head'"
    >
      <!-- Pass through slots -->
      <template v-for="(_, name) in $slots" v-slot:[name]="slotData">
        <slot v-if="name !== 'top-right'" :name="name" v-bind="slotData" />
      </template>

      <template v-slot:loading>
        <q-inner-loading showing color="primary" />
      </template>

      <template v-slot:no-data>
        <slot name="no-data">
          <div class="full-width column flex-center text-grey-5 q-pa-xl">
            <q-icon size="48px" name="search_off" class="q-mb-md" style="opacity: 0.3" />
            <div class="text-subtitle2 text-weight-medium" style="opacity: 0.5">
              No data available
            </div>
          </div>
        </slot>
      </template>
    </q-table>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, default: '' },
  rows: { type: Array, required: true },
  columns: { type: Array, required: true },
  filter: { type: String, default: '' },
  loading: { type: Boolean, default: false },
})
</script>

<style scoped lang="scss">
.v-data-table-wrap {
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid var(--v-border);
  background: var(--v-surface);
  box-shadow: var(--v-shadow-sm);
  transition: box-shadow 0.2s ease;

  &:hover {
    box-shadow: var(--v-shadow-md);
  }
}

.v-table-header {
  border-bottom: 1px solid var(--v-border);
  background: v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.02)' : 'rgba(15,23,42,0.018)'");
}

.v-table-title {
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: v-bind("$q.dark.isActive ? '#F1F5F9' : '#0F172A'");
}

.v-table {
  background: transparent !important;

  :deep(.q-table__card) {
    box-shadow: none;
    background: transparent;
  }
  :deep(.q-table__container) {
    background: transparent;
  }

  :deep(thead tr th) {
    background: v-bind(
      "$q.dark.isActive ? 'rgba(255,255,255,0.03)' : 'rgba(15,23,42,0.025)'"
    ) !important;
    font-size: 10.5px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    color: v-bind("$q.dark.isActive ? '#64748B' : '#94A3B8'") !important;
    padding: 13px 16px;
    border-bottom: 1px solid var(--v-border);
    white-space: nowrap;
  }

  :deep(tbody tr) {
    transition: background 0.12s ease;

    td {
      font-size: 13.5px;
      padding: 13px 16px;
      border-bottom: 1px solid var(--v-border);
      color: v-bind("$q.dark.isActive ? '#CBD5E1' : '#334155'");
    }

    &:hover td {
      background: v-bind(
        "$q.dark.isActive ? 'rgba(79,70,229,0.06)' : 'rgba(79,70,229,0.04)'"
      ) !important;
    }

    &:last-child td {
      border-bottom: none;
    }
    &:nth-child(even) td {
      background: v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.018)' : 'rgba(15,23,42,0.012)'");
    }
  }

  :deep(.q-table__bottom) {
    border-top: 1px solid var(--v-border);
    font-size: 13px;
    padding: 8px 16px;
    color: var(--v-text-2);
    background: v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.02)' : 'rgba(15,23,42,0.018)'");
  }

  :deep(.q-table__sort-icon) {
    color: var(--v-primary);
  }
}
</style>

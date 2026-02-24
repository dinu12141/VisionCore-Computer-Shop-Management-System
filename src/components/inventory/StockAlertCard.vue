<template>
  <q-card
    class="stock-alert-card"
    :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
    flat
    bordered
  >
    <q-card-section class="q-pb-sm">
      <div class="row items-center no-wrap">
        <q-icon :name="alertIcon" :color="alertColor" size="32px" class="q-mr-sm" />
        <div>
          <div class="text-subtitle1 text-weight-bold">{{ item.item_name }}</div>
          <div class="text-caption text-grey-5">
            {{ item.item_code }} · {{ item.category_name || 'Uncategorized' }}
          </div>
        </div>
        <q-space />
        <q-badge
          :color="alertColor + '-9'"
          :text-color="alertColor + '-1'"
          class="text-weight-bold text-uppercase"
        >
          {{ item.stock_status === 'out_of_stock' ? 'OUT OF STOCK' : 'LOW STOCK' }}
        </q-badge>
      </div>
    </q-card-section>

    <q-card-section class="q-pt-none">
      <div class="row items-center q-gutter-md">
        <!-- Progress bar -->
        <div class="col">
          <div class="row justify-between text-caption text-grey-5 q-mb-xs">
            <span>{{ item.qty_on_hand }} {{ item.uom_code }}</span>
            <span>Reorder: {{ item.reorder_level }} {{ item.uom_code }}</span>
          </div>
          <q-linear-progress
            :value="progressValue"
            :color="alertColor"
            :track-color="$q.dark.isActive ? 'grey-8' : 'grey-3'"
            rounded
            size="10px"
            class="q-mb-xs"
          />
          <div class="row justify-between text-caption text-grey-6">
            <span>Min: {{ item.min_stock }}</span>
            <span v-if="item.max_stock">Max: {{ item.max_stock }}</span>
          </div>
        </div>

        <!-- Warehouse tag -->
        <div class="col-auto">
          <q-chip dense outline :color="whColor" :icon="whIcon" size="sm">
            {{ item.warehouse_name }}
          </q-chip>
        </div>
      </div>
    </q-card-section>

    <q-card-actions class="q-pt-none" v-if="showActions">
      <q-btn
        flat
        dense
        color="primary"
        icon="add_shopping_cart"
        label="Create GRN"
        size="sm"
        @click="$emit('reorder', item)"
      />
      <q-btn
        flat
        dense
        color="blue"
        icon="swap_horiz"
        label="Transfer"
        size="sm"
        @click="$emit('transfer', item)"
      />
    </q-card-actions>
  </q-card>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  item: { type: Object, required: true },
  showActions: { type: Boolean, default: true },
})

defineEmits(['reorder', 'transfer'])

const alertColor = computed(() => (props.item.stock_status === 'out_of_stock' ? 'red' : 'orange'))

const alertIcon = computed(() => (props.item.stock_status === 'out_of_stock' ? 'error' : 'warning'))

const progressValue = computed(() => {
  const max = props.item.max_stock || props.item.reorder_level * 3 || 100
  return Math.min(Math.max((props.item.qty_on_hand || 0) / max, 0), 1)
})

const whColor = computed(() => {
  const map = { main_store: 'teal', kitchen: 'orange', bar: 'purple' }
  return map[props.item.warehouse_type] || 'grey'
})

const whIcon = computed(() => {
  const map = { main_store: 'warehouse', kitchen: 'soup_kitchen', bar: 'local_bar' }
  return map[props.item.warehouse_type] || 'store'
})
</script>

<style scoped>
.stock-alert-card {
  transition:
    transform 0.2s,
    box-shadow 0.2s;
}
.stock-alert-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}
</style>

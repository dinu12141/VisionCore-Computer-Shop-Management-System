<template>
  <div class="q-pa-md">
    <!-- Stats Row -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-3">
        <StatCard
          title="Total Products"
          :value="stats.totalItems"
          icon="inventory_2"
          gradient="primary"
        />
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <StatCard
          title="Total Stock Value"
          :value="stats.totalStockValue"
          prefix="LKR"
          icon="account_balance_wallet"
          gradient="success"
        />
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <StatCard
          title="Low Stock Items"
          :value="stats.lowStockCount"
          icon="warning"
          gradient="warning"
        />
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <StatCard 
          title="Today's GRN" 
          :value="stats.todayGRN" 
          icon="archive" 
          gradient="info" 
        />
      </div>
    </div>

    <!-- Warehouse Stock Summary -->
    <q-card
      class="q-mb-md"
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      flat
      bordered
    >
      <q-card-section>
        <div class="text-h6 q-mb-md">
          <q-icon name="warehouse" class="q-mr-sm" />Warehouse Stock Summary
        </div>
        <q-inner-loading :showing="stockLoading" :dark="$q.dark.isActive" />
        <div v-if="!stockLoading" class="row q-col-gutter-md">
          <div
            v-for="wh in warehouseSummary"
            :key="wh.warehouse_id"
            class="col-12 col-sm-6 col-md-4"
          >
            <q-card
              :class="$q.dark.isActive ? 'bg-grey-10 text-white' : 'bg-grey-1 text-grey-9'"
              flat
              bordered
            >
              <q-card-section>
                <div class="row items-center q-mb-sm">
                  <q-icon
                    :name="getWhIcon(wh.warehouse_type)"
                    :color="getWhColor(wh.warehouse_type)"
                    size="24px"
                    class="q-mr-sm"
                  />
                  <div class="text-subtitle1 text-weight-bold">{{ wh.warehouse_name }}</div>
                  <q-space />
                  <q-badge :color="getWhColor(wh.warehouse_type)">{{ wh.warehouse_type }}</q-badge>
                </div>
                <div class="row q-col-gutter-sm text-center">
                  <div class="col-4">
                    <div class="text-h5 text-weight-bold text-primary">{{ wh.item_count }}</div>
                    <div class="text-caption text-grey-5">Items</div>
                  </div>
                  <div class="col-4">
                    <div class="text-h5 text-weight-bold text-green">
                      {{ formatCurrencyShort(wh.total_value) }}
                    </div>
                    <div class="text-caption text-grey-5">Value</div>
                  </div>
                  <div class="col-4">
                    <div
                      class="text-h5 text-weight-bold"
                      :class="wh.low_stock > 0 ? 'text-orange' : 'text-grey-5'"
                    >
                      {{ wh.low_stock }}
                    </div>
                    <div class="text-caption text-grey-5">Low Stock</div>
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Low Stock Alerts -->
    <q-card
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      flat
      bordered
      v-if="lowStockAlerts.length > 0"
    >
      <q-card-section>
        <div class="text-h6 q-mb-md text-orange">
          <q-icon name="notification_important" class="q-mr-sm" />Low Stock Alerts
        </div>
        <div class="row q-col-gutter-md">
          <div
            v-for="item in lowStockAlerts.slice(0, 6)"
            :key="(item.item_id || '') + (item.warehouse_id || '')"
            class="col-12 col-sm-6 col-md-4"
          >
            <StockAlertCard :item="item" :show-actions="false" />
          </div>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup>
import { computed, onMounted, watch } from 'vue'
import StatCard from 'components/common/StatCard.vue'
import StockAlertCard from 'components/inventory/StockAlertCard.vue'
import { useAuthStore } from 'src/stores/auth'
import { useStockDashboard } from 'src/services/inventoryService'
const authStore = useAuthStore()

const {
  stockOnHand,
  lowStockAlerts,
  stats,
  loading: stockLoading,
  fetchStockOnHand,
} = useStockDashboard()

const warehouseSummary = computed(() => {
  const grouped = {}
  for (const row of stockOnHand.value) {
    const whId = row.warehouse_id
    if (!grouped[whId]) {
      grouped[whId] = {
        warehouse_id: whId,
        warehouse_name: row.warehouse_name,
        warehouse_type: row.warehouse_type,
        item_count: 0,
        total_value: 0,
        low_stock: 0,
      }
    }
    grouped[whId].item_count++
    grouped[whId].total_value += row.total_value || 0
    if (row.stock_status === 'low_stock' || row.stock_status === 'out_of_stock') {
      grouped[whId].low_stock++
    }
  }
  return Object.values(grouped)
})

// Robust loading: wait for company_id to be ready
watch(
  () => authStore.currentBranch?.company_id,
  (newCid) => {
    if (newCid) refreshAll()
  },
  { immediate: true },
)

onMounted(() => {
  if (authStore.currentBranch?.company_id) refreshAll()
})

async function refreshAll() {
  await fetchStockOnHand()
}

// warehouseSummary is now a computed property

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

// formatCurrency removed as we now use prefix="LKR" and let component handle it

function formatCurrencyShort(val) {
  if (val >= 1000000) return 'LKR ' + (val / 1000000).toFixed(1) + 'M'
  if (val >= 1000) return 'LKR ' + (val / 1000).toFixed(1) + 'K'
  return 'LKR ' + Number(val || 0).toFixed(0)
}
</script>

<template>
  <q-page class="q-pa-md">
    <PageHeader title="Finance Dashboard" subtitle="Financial overview and reports">
      <template #actions>
        <q-btn-dropdown outline color="primary" label="Reports" icon="assessment">
          <q-list>
            <q-item clickable v-close-popup to="/reports/sales">
              <q-item-section>Daily Sales Report</q-item-section>
            </q-item>
            <q-item clickable v-close-popup>
              <q-item-section>Expense Report</q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
        <q-btn color="primary" icon="add" label="Record Expense" class="q-ml-sm" />
      </template>
    </PageHeader>

    <q-tabs
      v-model="tab"
      dense
      :class="$q.dark.isActive ? 'text-grey-4' : 'text-grey-7'"
      class="q-mb-md"
      active-color="primary"
      indicator-color="primary"
      align="left"
      narrow-indicator
    >
      <q-tab name="dashboard" label="Dashboard" />
      <q-tab name="profit" label="Item Wise Profits" />
      <q-tab name="invoices" label="Invoices" />
      <q-tab name="payments" label="Payments" />
      <q-tab name="refunds" label="Refunds" />
    </q-tabs>

    <q-tab-panels v-model="tab" animated class="bg-transparent">
      <q-tab-panel name="dashboard" class="q-pa-none">
        <DashboardTab />
      </q-tab-panel>

      <q-tab-panel name="profit" class="q-pa-none">
        <ProfitTab />
      </q-tab-panel>

      <q-tab-panel name="invoices" class="q-pa-none">
        <InvoicesTab />
      </q-tab-panel>

      <q-tab-panel name="payments" class="q-pa-none">
        <PaymentsTab />
      </q-tab-panel>

      <q-tab-panel name="refunds" class="q-pa-none">
        <RefundsTab />
      </q-tab-panel>
    </q-tab-panels>
  </q-page>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from 'components/common/PageHeader.vue'
import DashboardTab from 'components/finance/DashboardTab.vue'
import ProfitTab from 'components/finance/ProfitTab.vue'
import InvoicesTab from 'components/finance/InvoicesTab.vue'
import PaymentsTab from 'components/finance/PaymentsTab.vue'
import RefundsTab from 'components/finance/RefundsTab.vue'

const route = useRoute()
const tab = ref('dashboard')

const tabs = ['dashboard', 'profit', 'invoices', 'payments', 'refunds']

watch(
  () => route.query.tab,
  (newTab) => {
    if (newTab && tabs.includes(newTab)) {
      tab.value = newTab
    }
  },
)

onMounted(() => {
  const queryTab = route.query.tab
  if (queryTab && tabs.includes(queryTab)) {
    tab.value = queryTab
  }
})
</script>

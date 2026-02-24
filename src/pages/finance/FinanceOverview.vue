<template>
  <q-page class="q-pa-md">
    <PageHeader title="Finance Overview" subtitle="High-level financial performance and health">
      <template #actions>
        <q-btn
          outline
          color="primary"
          label="Reports"
          icon="assessment"
          :to="{ path: '/reports/sales' }"
        />
      </template>
    </PageHeader>

    <q-tabs
      v-model="tab"
      dense
      class="text-grey-7 q-mb-md"
      active-color="primary"
      indicator-color="primary"
      align="left"
      narrow-indicator
    >
      <q-tab name="dashboard" label="Dashboard" />
      <q-tab name="invoices" label="Invoice Registry" />
      <q-tab name="payments" label="Recent Payments" />
    </q-tabs>

    <q-tab-panels v-model="tab" animated class="bg-transparent">
      <q-tab-panel name="dashboard" class="q-pa-none">
        <DashboardTab />
      </q-tab-panel>

      <q-tab-panel name="invoices" class="q-pa-none">
        <InvoicesTab />
      </q-tab-panel>

      <q-tab-panel name="payments" class="q-pa-none">
        <PaymentsTab />
      </q-tab-panel>
    </q-tab-panels>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import PageHeader from 'components/common/PageHeader.vue'
import DashboardTab from 'components/finance/DashboardTab.vue'
import InvoicesTab from 'components/finance/InvoicesTab.vue'
import PaymentsTab from 'components/finance/PaymentsTab.vue'

const tab = ref('dashboard')
</script>

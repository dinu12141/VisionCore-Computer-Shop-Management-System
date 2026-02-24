<template>
  <q-card flat bordered class="glass-container fit overflow-hidden">
    <q-tabs
      v-model="tab"
      dense
      class="text-grey"
      active-color="primary"
      indicator-color="primary"
      align="justify"
      narrow-indicator
    >
      <q-tab name="invoices" label="Invoices" />
      <q-tab name="payments" label="Payments" />
      <q-tab name="customers" label="Customers" />
    </q-tabs>

    <q-separator />

    <q-tab-panels v-model="tab" animated class="bg-transparent">
      <q-tab-panel name="invoices" class="q-pa-none">
        <q-list separator>
          <q-item
            v-for="inv in invoices"
            :key="inv.id"
            clickable
            v-ripple
            :to="`/billing/history?invoice_no=${inv.invoice_no}`"
          >
            <q-item-section avatar>
              <q-avatar color="primary-soft" text-color="primary" icon="description" size="40px" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ inv.invoice_no }}</q-item-label>
              <q-item-label caption>{{ inv.customer_name }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-weight-bold"
                >LKR {{ inv.total.toLocaleString() }}</q-item-label
              >
              <q-item-label caption>{{ timeAgo(inv.created_at) }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </q-tab-panel>

      <q-tab-panel name="payments" class="q-pa-none">
        <q-list separator>
          <q-item v-for="pay in payments" :key="pay.id" clickable v-ripple>
            <q-item-section avatar>
              <q-avatar color="positive-soft" text-color="positive" icon="payments" size="40px" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ pay.method }} Payment</q-item-label>
              <q-item-label caption>{{ pay.invoice_no }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-weight-bold text-positive"
                >+LKR {{ pay.amount.toLocaleString() }}</q-item-label
              >
              <q-item-label caption>{{ timeAgo(pay.created_at) }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </q-tab-panel>

      <q-tab-panel name="customers" class="q-pa-none">
        <q-list separator>
          <q-item
            v-for="cus in customers"
            :key="cus.id"
            clickable
            v-ripple
            :to="`/customers/${cus.id}`"
          >
            <q-item-section avatar>
              <q-avatar color="secondary-soft" text-color="secondary" icon="person" size="40px" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ cus.name }}</q-item-label>
              <q-item-label caption>{{ cus.phone || 'No phone' }}</q-item-label>
            </q-item-section>
            <q-item-section side side-top>
              <q-item-label caption>{{ timeAgo(cus.created_at) }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </q-tab-panel>
    </q-tab-panels>
  </q-card>
</template>

<script setup>
import { ref } from 'vue'
import { date } from 'quasar'

defineProps({
  invoices: { type: Array, default: () => [] },
  payments: { type: Array, default: () => [] },
  customers: { type: Array, default: () => [] },
})

const tab = ref('invoices')

function timeAgo(d) {
  if (!d) return ''
  const diff = Math.floor((new Date() - new Date(d)) / 1000)
  if (diff < 60) return 'just now'
  if (diff < 3600) return Math.floor(diff / 60) + 'm ago'
  if (diff < 86400) return Math.floor(diff / 3600) + 'h ago'
  return date.formatDate(d, 'MMM DD')
}
</script>

<style scoped lang="scss">
.primary-soft {
  background: rgba(var(--q-primary-rgb), 0.1);
}
.positive-soft {
  background: rgba(var(--q-positive-rgb), 0.1);
}
.secondary-soft {
  background: rgba(var(--q-secondary-rgb), 0.1);
}
</style>

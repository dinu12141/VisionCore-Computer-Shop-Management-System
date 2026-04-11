<template>
  <q-btn flat round dense icon="notifications" class="q-mr-sm">
    <q-badge v-if="unreadCount > 0" color="red" floating>{{ unreadCount }}</q-badge>
    <q-menu
      fit
      anchor="bottom left"
      self="top right"
      class="notification-panel"
      style="width: 370px"
    >
      <!-- Header -->
      <div
        class="q-pa-md flex items-center justify-between"
        :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-grey-2'"
      >
        <div class="text-subtitle1 text-weight-bold">Notifications</div>
        <q-btn
          flat
          dense
          round
          icon="done_all"
          @click="markAllRead"
          v-if="unreadCount > 0"
          :color="$q.dark.isActive ? 'white' : 'primary'"
        >
          <q-tooltip>Mark all as read</q-tooltip>
        </q-btn>
      </div>

      <q-list separator class="scroll" style="max-height: 420px">
        <q-item
          v-for="n in notifications"
          :key="n.id"
          clickable
          v-ripple
          :class="[
            !n.read ? ($q.dark.isActive ? 'bg-blue-10' : 'bg-blue-1') : '',
            n.urgency === 'critical' ? 'border-left-critical' : '',
            n.urgency === 'high' ? 'border-left-high' : '',
          ]"
          @click="markRead(n.id)"
        >
          <q-item-section avatar>
            <q-icon
              :name="getIcon(n.type, n.urgency)"
              :color="getColor(n.type, n.urgency)"
              size="22px"
            />
          </q-item-section>

          <q-item-section>
            <q-item-label class="text-weight-bold" style="font-size: 13px">
              {{ n.title }}
            </q-item-label>
            <q-item-label caption lines="3" style="font-size: 11.5px; line-height: 1.4">
              {{ n.message }}
            </q-item-label>
            <q-item-label caption class="text-grey-6" style="font-size: 10.5px">
              {{ formatTime(n.timestamp) }}
            </q-item-label>
          </q-item-section>

          <q-item-section side top>
            <q-badge
              v-if="!n.read"
              :color="
                n.urgency === 'critical' ? 'negative' : n.urgency === 'high' ? 'warning' : 'blue'
              "
              rounded
              style="width: 8px; height: 8px"
            />
          </q-item-section>
        </q-item>

        <div v-if="notifications.length === 0" class="q-pa-lg text-center text-grey">
          <q-icon name="notifications_off" size="40px" class="q-mb-sm" />
          <div class="text-caption">No notifications</div>
        </div>
      </q-list>
    </q-menu>
  </q-btn>
</template>

<script setup>
import { computed } from 'vue'
import { useQuasar } from 'quasar'
import { useNotificationStore } from 'src/stores/notifications'

const $q = useQuasar()
const store = useNotificationStore()

const notifications = computed(() => store.notifications)
const unreadCount = computed(() => store.unreadCount)

function markRead(id) {
  store.markRead(id)
}
function markAllRead() {
  store.markAllRead()
}

function getIcon(type, urgency) {
  if (type === 'payment') {
    return urgency === 'critical' ? 'alarm' : urgency === 'high' ? 'schedule' : 'payments'
  }
  if (type === 'inventory') return 'inventory_2'
  
  const map = { order: 'restaurant_menu', kitchen: 'kitchen', system: 'info' }
  return map[type] || 'notifications'
}

function getColor(type, urgency) {
  if (type === 'payment') {
    return urgency === 'critical' ? 'negative' : urgency === 'high' ? 'warning' : 'orange'
  }
  if (type === 'inventory') {
    return urgency === 'critical' ? 'negative' : 'warning'
  }

  const map = { order: 'primary', kitchen: 'orange', system: 'grey' }
  return map[type] || 'blue'
}

function formatTime(date) {
  if (!date) return ''
  const d = new Date(date)
  const now = new Date()
  const diffMs = now - d
  const diffMins = Math.floor(diffMs / 60000)
  if (diffMins < 1) return 'Just now'
  if (diffMins < 60) return `${diffMins}m ago`
  if (diffMins < 1440) return `${Math.floor(diffMins / 60)}h ago`
  return d.toLocaleDateString()
}
</script>

<style scoped>
.notification-panel {
  border-radius: 12px;
  overflow: hidden;
}
.border-left-critical {
  border-left: 3px solid var(--q-negative) !important;
}
.border-left-high {
  border-left: 3px solid var(--q-warning) !important;
}
</style>

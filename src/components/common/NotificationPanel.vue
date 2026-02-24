<template>
  <q-btn flat round dense icon="notifications" class="q-mr-sm">
    <q-badge v-if="unreadCount > 0" color="red" floating>{{ unreadCount }}</q-badge>
    <q-menu
      fit
      anchor="bottom left"
      self="top right"
      class="notification-panel"
      style="width: 350px"
    >
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

      <q-list separator class="scroll" style="max-height: 400px">
        <q-item
          v-for="notification in notifications"
          :key="notification.id"
          clickable
          v-ripple
          :class="notification.read ? '' : $q.dark.isActive ? 'bg-blue-10 text-white' : 'bg-blue-1'"
          @click="markRead(notification.id)"
        >
          <q-item-section avatar>
            <q-icon :name="getIcon(notification.type)" :color="getColor(notification.type)" />
          </q-item-section>

          <q-item-section>
            <q-item-label>{{ notification.title }}</q-item-label>
            <q-item-label caption lines="2">{{ notification.message }}</q-item-label>
            <q-item-label caption class="text-grey-7">{{
              formatTime(notification.timestamp)
            }}</q-item-label>
          </q-item-section>

          <q-item-section side top>
            <q-badge
              v-if="!notification.read"
              color="blue"
              rounded
              class="q-mr-xs"
              style="width: 8px; height: 8px"
            />
          </q-item-section>
        </q-item>

        <div v-if="notifications.length === 0" class="q-pa-md text-center text-grey">
          <q-icon name="notifications_off" size="md" class="q-mb-sm" />
          <div>No notifications</div>
        </div>
      </q-list>
    </q-menu>
  </q-btn>
</template>

<script setup>
import { computed } from 'vue'
import { useNotificationStore } from 'src/stores/notifications'

const store = useNotificationStore()

const notifications = computed(() => store.notifications)
const unreadCount = computed(() => store.unreadCount)

function markRead(id) {
  store.markRead(id)
}

function markAllRead() {
  store.markAllRead()
}

function getIcon(type) {
  switch (type) {
    case 'order':
      return 'restaurant_menu'
    case 'kitchen':
      return 'kitchen'
    case 'payment':
      return 'payments'
    case 'system':
      return 'settings'
    default:
      return 'info'
  }
}

function getColor(type) {
  switch (type) {
    case 'order':
      return 'primary'
    case 'kitchen':
      return 'orange'
    case 'payment':
      return 'green'
    case 'system':
      return 'grey'
    default:
      return 'blue'
  }
}

function formatTime(date) {
  if (!date) return ''
  const d = new Date(date)
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
</script>

<style scoped>
.notification-panel {
  border-radius: 8px;
}
</style>

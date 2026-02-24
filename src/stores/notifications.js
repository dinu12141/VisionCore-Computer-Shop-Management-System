import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'

export const useNotificationStore = defineStore('notifications', () => {
  const notifications = ref([])
  const toasts = ref([])

  const unreadCount = computed(() => notifications.value.filter((n) => !n.read).length)

  function addNotification(notification) {
    // Check for duplicates (e.g. same invoice reminder)
    if (notification.invoice_id) {
      const exists = notifications.value.some(
        (n) => n.invoice_id === notification.invoice_id && n.type === notification.type,
      )
      if (exists) return
    }

    notifications.value.unshift({
      id: Date.now(),
      timestamp: new Date(),
      read: false,
      ...notification,
    })
  }

  async function checkUpcomingCollections(companyId) {
    if (!companyId) return
    try {
      const { data, error } = await supabase.rpc('get_upcoming_reminders', {
        p_company_id: companyId,
        p_days: 2,
      })
      if (error) throw error

      if (data && data.length > 0) {
        data.forEach((item) => {
          addNotification({
            type: 'system',
            title: 'Collection Reminder',
            message: `Invoice ${item.invoice_no} (${item.customer_name}) is due on ${item.collection_date}. Balance: LKR ${Number(item.balance).toLocaleString()}`,
            invoice_id: item.id,
          })
        })
      }
    } catch (err) {
      console.error('[NotificationStore] checkUpcomingCollections error:', err)
    }
  }

  function markRead(id) {
    const notification = notifications.value.find((n) => n.id === id)
    if (notification) {
      notification.read = true
    }
  }

  function markAllRead() {
    notifications.value.forEach((n) => (n.read = true))
  }

  function addToast(message, type = 'info', timeout = 3000) {
    const id = Date.now() + Math.random()
    toasts.value.push({ id, message, type })
    if (timeout) {
      setTimeout(() => removeToast(id), timeout)
    }
  }

  function removeToast(id) {
    const index = toasts.value.findIndex((t) => t.id === id)
    if (index !== -1) {
      toasts.value.splice(index, 1)
    }
  }

  return {
    notifications,
    toasts,
    unreadCount,
    addNotification,
    checkUpcomingCollections,
    markRead,
    markAllRead,
    addToast,
    removeToast,
  }
})

import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useQuasar } from 'quasar'

export const useNotificationStore = defineStore('notifications', () => {
  const notifications = ref([])
  const toasts = ref([])
  let _pollTimer = null

  const unreadCount = computed(() => notifications.value.filter((n) => !n.read).length)

  // ── Add a notification (dedup by invoice_id + type) ─────────────────────
  function addNotification(notification) {
    if (notification.invoice_id) {
      const exists = notifications.value.some(
        (n) => n.invoice_id === notification.invoice_id && n.type === notification.type,
      )
      if (exists) return
    }
    notifications.value.unshift({
      id: Date.now() + Math.random(),
      timestamp: new Date(),
      read: false,
      ...notification,
    })
  }

  // ── Check Supabase for invoices due within p_days ────────────────────────
  async function checkUpcomingCollections(companyId) {
    if (!companyId) return
    try {
      const { data, error } = await supabase.rpc('get_upcoming_reminders', {
        p_company_id: companyId,
        p_days: 3, // alert 3 days in advance
      })
      if (error) throw error

      if (!data || data.length === 0) return

      const $q = useQuasar()

      data.forEach((item) => {
        const daysLeft = Number(item.days_remaining ?? 0)
        const balance = Number(item.balance || 0)

        // Human-friendly due label
        const dueLabel =
          daysLeft === 0
            ? '🔴 DUE TODAY'
            : daysLeft === 1
              ? '🟠 Due Tomorrow'
              : `🟡 Due in ${daysLeft} days`

        const title = `${dueLabel} — ${item.invoice_no}`
        const message = `${item.customer_name}${item.customer_phone ? ' (' + item.customer_phone + ')' : ''} | Balance: LKR ${balance.toLocaleString()} | Collect by: ${item.collection_date}`

        // Add to notification panel (deduped)
        addNotification({
          type: 'payment',
          title,
          message,
          invoice_id: item.id,
          urgency: daysLeft === 0 ? 'critical' : daysLeft === 1 ? 'high' : 'medium',
        })

        // Show a visible toast popup for today & tomorrow only
        if (daysLeft <= 1) {
          $q.notify({
            type: daysLeft === 0 ? 'negative' : 'warning',
            icon: 'payments',
            message: title,
            caption: `${item.customer_name} — LKR ${balance.toLocaleString()}`,
            position: 'top-right',
            timeout: daysLeft === 0 ? 0 : 8000, // today = persistent until closed
            actions:
              daysLeft === 0
                ? [{ label: 'Dismiss', color: 'white', handler: () => {} }]
                : undefined,
            progress: daysLeft === 1,
          })
        }
      })
    } catch (err) {
      console.error('[NotificationStore] checkUpcomingCollections error:', err)
    }
  }

  // ── Start polling (runs on login, refreshes every 30 min) ────────────────
  function startPolling(companyId) {
    if (!companyId) return
    // Run immediately
    checkUpcomingCollections(companyId)
    // Then every 30 minutes
    if (_pollTimer) clearInterval(_pollTimer)
    _pollTimer = setInterval(
      () => {
        checkUpcomingCollections(companyId)
      },
      30 * 60 * 1000,
    )
  }

  function stopPolling() {
    if (_pollTimer) {
      clearInterval(_pollTimer)
      _pollTimer = null
    }
  }

  // ── Mark read ─────────────────────────────────────────────────────────────
  function markRead(id) {
    const n = notifications.value.find((n) => n.id === id)
    if (n) n.read = true
  }

  function markAllRead() {
    notifications.value.forEach((n) => (n.read = true))
  }

  // ── Toast helpers ─────────────────────────────────────────────────────────
  function addToast(message, type = 'info', timeout = 3000) {
    const id = Date.now() + Math.random()
    toasts.value.push({ id, message, type })
    if (timeout) setTimeout(() => removeToast(id), timeout)
  }

  function removeToast(id) {
    const index = toasts.value.findIndex((t) => t.id === id)
    if (index !== -1) toasts.value.splice(index, 1)
  }

  return {
    notifications,
    toasts,
    unreadCount,
    addNotification,
    checkUpcomingCollections,
    startPolling,
    stopPolling,
    markRead,
    markAllRead,
    addToast,
    removeToast,
  }
})

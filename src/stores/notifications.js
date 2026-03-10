import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useQuasar } from 'quasar'

export const useNotificationStore = defineStore('notifications', () => {
  const notifications = ref([])
  const toasts = ref([])
  let _pollTimer = null

  const unreadCount = computed(() => notifications.value.filter((n) => !n.read).length)

  // ── Add a notification (dedup by invoice_id + type + urgency) ───────────────
  function addNotification(notification) {
    if (notification.invoice_id) {
      const exists = notifications.value.some(
        (n) =>
          n.invoice_id === notification.invoice_id &&
          n.type === notification.type &&
          n.urgency === notification.urgency,
      )
      if (exists) return false
    }
    notifications.value.unshift({
      id: Date.now() + Math.random(),
      timestamp: new Date(),
      read: false,
      ...notification,
    })
    return true
  }

  // ── Check Supabase for invoices due within 3 days ────────────────────────
  async function checkUpcomingCollections(companyId) {
    if (!companyId) return
    try {
      const today = new Date()
      const formatLocal = (d) => {
        const y = d.getFullYear()
        const m = String(d.getMonth() + 1).padStart(2, '0')
        const day = String(d.getDate()).padStart(2, '0')
        return `${y}-${m}-${day}`
      }

      const todayStr = formatLocal(today)
      const futureDate = new Date()
      futureDate.setDate(today.getDate() + 3)
      const futureDateStr = formatLocal(futureDate)

      const { data, error } = await supabase
        .from('invoices')
        .select(`id, invoice_no, customer_snapshot, balance, collection_date`)
        .eq('company_id', companyId)
        .gt('balance', 0)
        .not('collection_date', 'is', null)
        .lte('collection_date', futureDateStr)

      if (error) throw error

      if (!data || data.length === 0) return

      const $q = useQuasar()

      const parseLocalDate = (dateStr) => {
        if (!dateStr) return new Date(0)
        const [y, m, d] = dateStr.split('-')
        return new Date(y, m - 1, d)
      }

      const t2 = parseLocalDate(todayStr)

      data.forEach((item) => {
        // Calculate days left using robust local midnight comparison
        const collDate = parseLocalDate(item.collection_date)
        const timeDiff = collDate.getTime() - t2.getTime()
        const daysLeft = Math.round(timeDiff / (1000 * 3600 * 24))

        if (daysLeft > 3) return // Ignore if > 3 days (just in case)

        const balance = Number(item.balance || 0)
        const custName = item.customer_snapshot?.name || 'Walk-in'
        const custPhone = item.customer_snapshot?.phone || ''

        // Human-friendly due label
        let dueLabel = ''
        if (daysLeft < 0) {
          dueLabel = '🔴 OVERDUE'
        } else if (daysLeft === 0) {
          dueLabel = '🔴 DUE TODAY'
        } else if (daysLeft === 1) {
          dueLabel = '🟠 Due Tomorrow'
        } else {
          dueLabel = `🟡 Due in ${daysLeft} days`
        }

        const title = `${dueLabel} — ${item.invoice_no}`
        const message = `${custName}${custPhone ? ' (' + custPhone + ')' : ''} | Balance: LKR ${balance.toLocaleString()} | Collect by: ${item.collection_date}`

        // Add to notification panel (deduped)
        const isNew = addNotification({
          type: 'payment',
          title,
          message,
          invoice_id: item.id,
          urgency: daysLeft <= 0 ? 'critical' : daysLeft === 1 ? 'high' : 'medium',
        })

        // Show a visible toast popup for overdue, today & tomorrow only IF it's a new notification
        if (isNew && daysLeft <= 1) {
          $q.notify({
            type: daysLeft <= 0 ? 'negative' : 'warning',
            icon: 'payments',
            message: title,
            caption: `${custName} — LKR ${balance.toLocaleString()}`,
            position: 'top-right',
            timeout: daysLeft <= 0 ? 0 : 8000, // overdue/today = persistent until closed
            actions: Object.keys($q).length
              ? [{ label: 'Dismiss', color: 'white', handler: () => {} }]
              : undefined,
            progress: daysLeft === 1,
            color: daysLeft <= 0 ? 'negative' : 'orange-9',
            textColor: 'white',
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

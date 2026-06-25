import { defineStore } from 'pinia'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from './auth'
import { date } from 'quasar'

export const useDashboardStore = defineStore('dashboard', {
  state: () => ({
    dateRange: {
      from: date.formatDate(date.startOfDate(new Date(), 'month'), 'YYYY-MM-DD'),
      to: date.formatDate(new Date(), 'YYYY-MM-DD'),
    },
    groupBy: 'day',
    kpis: null,
    trends: [],
    collections: [],
    topItems: [],
    topCustomers: [],
    paymentMethods: [],
    loading: false,
    lastUpdated: null,
  }),

  actions: {
    setDateRange(range) {
      this.dateRange = range
      this.refresh()
    },

    setGroupBy(val) {
      this.groupBy = val
      this.fetchTrends()
    },

    async refresh() {
      this.loading = true
      try {
        const auth = useAuthStore()
        // If not initialized, poll briefly for auth background fetch to complete
        if (!auth.currentBranch?.company_id) {
          for (let i = 0; i < 20; i++) {
            await new Promise((resolve) => setTimeout(resolve, 100))
            if (auth.currentBranch?.company_id) break
          }
          if (!auth.currentBranch?.company_id) {
            console.warn('[Dashboard] No company_id after waiting — skipping refresh')
            return
          }
        }

        await Promise.all([
          this.fetchKpis(),
          this.fetchTrends(),
          this.fetchCollections(),
          this.fetchTopItems(),
          this.fetchTopCustomers(),
          this.fetchPaymentMethods(),
        ])
        this.lastUpdated = new Date()
      } catch (err) {
        console.error('Dashboard refresh failed:', err)
        if (err && typeof err === 'object') {
          console.error('Error Details:', JSON.stringify(err, null, 2))
        }
      } finally {
        this.loading = false
      }
    },

    async fetchKpis() {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return

      const { data, error } = await supabase.rpc('dashboard_kpis', {
        p_company_id: companyId,
        p_from_date: this.dateRange.from,
        p_to_date: this.dateRange.to,
      })

      if (error) throw error
      this.kpis = data
    },

    async fetchTrends() {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return

      const { data, error } = await supabase.rpc('dashboard_trends', {
        p_company_id: companyId,
        p_from_date: this.dateRange.from,
        p_to_date: this.dateRange.to,
        p_group_by: this.groupBy,
      })

      if (error) throw error
      this.trends = data
    },

    async fetchCollections() {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return

      const { data, error } = await supabase.rpc('dashboard_collections_due', {
        p_company_id: companyId,
        p_limit: 10,
      })

      if (error) throw error
      this.collections = data
    },

    async fetchTopItems(metric = 'profit') {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return

      const { data, error } = await supabase.rpc('dashboard_top_items', {
        p_company_id: companyId,
        p_from_date: this.dateRange.from,
        p_to_date: this.dateRange.to,
        p_metric: metric,
        p_limit: 5,
      })

      if (error) throw error
      this.topItems = data
    },

    async fetchTopCustomers(metric = 'revenue') {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return

      const { data, error } = await supabase.rpc('dashboard_top_customers', {
        p_company_id: companyId,
        p_from_date: this.dateRange.from,
        p_to_date: this.dateRange.to,
        p_metric: metric,
        p_limit: 5,
      })

      if (error) throw error
      this.topCustomers = data
    },

    async fetchPaymentMethods() {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return

      const { data, error } = await supabase.rpc('dashboard_payment_methods', {
        p_company_id: companyId,
        p_from_date: this.dateRange.from,
        p_to_date: this.dateRange.to,
      })

      if (error) throw error
      this.paymentMethods = data
    },

    /**
     * Fetch the recent-activity feed shown on the main dashboard:
     * last 10 invoices, last 10 payments, last 10 new customers.
     */
    async fetchRecentActivity() {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return { invoices: [], payments: [], customers: [] }

      const [invoices, payments, customers] = await Promise.all([
        supabase
          .from('invoices')
          .select('id, invoice_no, customer_name:customer_snapshot->>name, total, created_at')
          .eq('company_id', companyId)
          .order('created_at', { ascending: false })
          .limit(10),
        supabase
          .from('invoice_payments')
          .select('id, amount, method, paid_at, invoices(invoice_no)')
          .eq('company_id', companyId)
          .order('paid_at', { ascending: false })
          .limit(10),
        supabase
          .from('customers')
          .select('id, name, phone, created_at')
          .eq('company_id', companyId)
          .order('created_at', { ascending: false })
          .limit(10),
      ])

      return {
        invoices: invoices.data || [],
        payments: (payments.data || []).map((p) => ({
          ...p,
          invoice_no: p.invoices?.invoice_no,
          created_at: p.paid_at,
        })),
        customers: customers.data || [],
      }
    },

    /**
     * Fetch all invoices (with line items) for a single calendar date.
     * Used by SalesReportPage to produce a daily sales summary.
     */
    async fetchDailySalesReport(dateStr) {
      const auth = useAuthStore()
      const companyId = auth.currentBranch?.company_id
      if (!companyId) return []

      const { data, error } = await supabase
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('company_id', companyId)
        .gte('created_at', `${dateStr}T00:00:00`)
        .lte('created_at', `${dateStr}T23:59:59`)
        .order('created_at', { ascending: false })

      if (error) throw error
      return data || []
    },
  },
})

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
        // If not initialized, wait a bit for auth background fetch
        if (!auth.currentBranch?.company_id) {
          await new Promise((resolve) => setTimeout(resolve, 800))
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
  },
})

import { defineStore } from 'pinia'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from './auth'

export const useFinanceStore = defineStore('finance', {
  state: () => ({
    overview: {
      totalRevenue: 0,
      totalCogs: 0,
      totalProfit: 0,
      marginPct: 0,
      totalReceived: 0,
      outstandingBalance: 0,
    },
    periodSummary: [],
    loading: false,
    error: null,
  }),

  actions: {
    async fetchOverview(fromDate, toDate) {
      this.loading = true
      try {
        const auth = useAuthStore()
        const companyId = auth.currentBranch?.company_id

        if (!companyId) {
          console.warn('Company ID not found in current branch, retrying after potential sync...')
          // Silently return if no companyId yet - it will likely be called again after auth initializes
          return
        }

        const { data, error } = await supabase.rpc('get_finance_overview', {
          p_company_id: companyId,
          p_from_date: fromDate,
          p_to_date: toDate,
        })

        if (error) throw error

        if (data && data.length > 0) {
          this.overview = {
            totalRevenue: data[0].total_revenue,
            totalCogs: data[0].total_cogs,
            totalProfit: data[0].total_profit,
            marginPct: data[0].avg_margin_pct,
            totalReceived: data[0].total_received,
            outstandingBalance: data[0].outstanding_balance,
          }
        }
      } catch (err) {
        console.error('Error fetching finance overview:', err)
        this.error = err.message
      } finally {
        this.loading = false
      }
    },

    async fetchPeriodSummary(fromDate, toDate, groupBy = 'day') {
      this.loading = true
      try {
        const auth = useAuthStore()
        const companyId = auth.currentBranch?.company_id

        if (!companyId) return

        const { data, error } = await supabase.rpc('report_sales_summary', {
          p_company_id: companyId,
          p_from_date: fromDate,
          p_to_date: toDate,
          p_group_by: groupBy,
        })

        if (error) throw error
        this.periodSummary = data || []
      } catch (err) {
        console.error('Error fetching period summary:', err)
        this.error = err.message
      } finally {
        this.loading = false
      }
    },

    setupRealtime(fromDate, toDate, groupBy = 'day') {
      const channel = supabase
        .channel('finance-realtime')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'invoices' }, () => {
          this.fetchOverview(fromDate, toDate)
          this.fetchPeriodSummary(fromDate, toDate, groupBy)
        })
        .on('postgres_changes', { event: '*', schema: 'public', table: 'invoice_payments' }, () => {
          this.fetchOverview(fromDate, toDate)
        })
        .subscribe()

      return () => {
        supabase.removeChannel(channel)
      }
    },
  },
})

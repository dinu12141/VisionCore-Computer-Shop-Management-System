import { defineStore } from 'pinia'
import { supabase } from 'src/boot/supabase'
import { exportFile } from 'quasar'
import { useAuthStore } from './auth'

export const useReportStore = defineStore('reports', {
  state: () => ({
    itemSales: [],
    customerSales: [],
    invoiceList: [],
    paymentSummary: [],
    loading: false,
    error: null,
  }),

  actions: {
    async fetchItemSales(fromDate, toDate, limit = 50) {
      this.loading = true
      try {
        const auth = useAuthStore()
        const companyId = auth.currentBranch?.company_id

        if (!companyId) return

        const { data, error } = await supabase.rpc('get_item_wise_profit_report', {
          p_company_id: companyId,
          p_from_date: fromDate,
          p_to_date: toDate,
          p_limit: limit,
        })

        if (error) throw error
        this.itemSales = data || []
      } catch (err) {
        this.error = err.message
      } finally {
        this.loading = false
      }
    },

    async fetchCustomerSales(fromDate, toDate, limit = 50) {
      this.loading = true
      try {
        const auth = useAuthStore()
        const companyId = auth.currentBranch?.company_id

        if (!companyId) return

        const { data, error } = await supabase.rpc('report_sales_by_customer', {
          p_company_id: companyId,
          p_from_date: fromDate,
          p_to_date: toDate,
          p_limit: limit,
        })

        if (error) throw error
        this.customerSales = data || []
      } catch (err) {
        this.error = err.message
      } finally {
        this.loading = false
      }
    },

    async fetchInvoiceList(fromDate, toDate, status = null, paymentStatus = null) {
      this.loading = true
      try {
        const auth = useAuthStore()
        const companyId = auth.currentBranch?.company_id

        if (!companyId) return

        const { data, error } = await supabase.rpc('report_invoice_list', {
          p_company_id: companyId,
          p_from_date: fromDate,
          p_to_date: toDate,
          p_status: status,
          p_payment_status: paymentStatus,
        })

        if (error) throw error
        this.invoiceList = data || []
      } catch (err) {
        this.error = err.message
      } finally {
        this.loading = false
      }
    },

    async fetchPaymentSummary(fromDate, toDate) {
      this.loading = true
      try {
        const auth = useAuthStore()
        const companyId = auth.currentBranch?.company_id

        if (!companyId) return

        const { data, error } = await supabase.rpc('report_payment_summary', {
          p_company_id: companyId,
          p_from_date: fromDate,
          p_to_date: toDate,
        })

        if (error) throw error
        this.paymentSummary = data || []
      } catch (err) {
        this.error = err.message
      } finally {
        this.loading = false
      }
    },

    exportToCSV(data, columns, fileName) {
      if (!data || data.length === 0) return false

      const header = columns.map((col) => col.label).join(',')
      const rows = data.map((row) =>
        columns
          .map((col) => {
            const val = typeof col.field === 'function' ? col.field(row) : row[col.field]
            return `"${val !== undefined && val !== null ? val : ''}"`
          })
          .join(','),
      )

      const content = [header, ...rows].join('\r\n')

      const status = exportFile(
        `${fileName}_${new Date().toISOString().split('T')[0]}.csv`,
        content,
        'text/csv',
      )

      return status
    },

    setupRealtime(type, fromDate, toDate, filters = {}) {
      const channel = supabase
        .channel(`report-${type}-realtime`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'invoices' }, () => {
          if (type === 'item') this.fetchItemSales(fromDate, toDate)
          if (type === 'customer') this.fetchCustomerSales(fromDate, toDate)
          if (type === 'invoice')
            this.fetchInvoiceList(fromDate, toDate, filters.status, filters.paymentStatus)
        })
        .on('postgres_changes', { event: '*', schema: 'public', table: 'invoice_payments' }, () => {
          if (type === 'payment') this.fetchPaymentSummary(fromDate, toDate)
          if (type === 'customer') this.fetchCustomerSales(fromDate, toDate)
          if (type === 'invoice')
            this.fetchInvoiceList(fromDate, toDate, filters.status, filters.paymentStatus)
        })
        .subscribe()

      return () => {
        supabase.removeChannel(channel)
      }
    },
  },
})

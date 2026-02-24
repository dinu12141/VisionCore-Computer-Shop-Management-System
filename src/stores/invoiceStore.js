import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from './auth'

export const useInvoiceStore = defineStore('invoices', () => {
  const authStore = useAuthStore()
  const loading = ref(false)

  const getCompanyId = () => authStore.currentBranch?.company_id

  async function createInvoice(invoiceData, items) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) throw new Error('Company ID missing')

      // Explicitly build the invoice payload
      const invoicePayload = {
        company_id: companyId,
        customer_id: invoiceData.customer_id || null,
        status: invoiceData.status || 'issued',
        payment_type: invoiceData.payment_type || 'cash',
        subtotal: Number(invoiceData.subtotal || 0),
        discount: Number(invoiceData.discount || 0),
        tax: Number(invoiceData.tax || 0),
        total: Number(invoiceData.total || 0),
        paid_amount: Number(invoiceData.paid_amount || 0),
        // Calculate balance and round to avoid floating point issues (e.g., 0.000000000001)
        balance: Math.max(
          0,
          Math.round(
            (Number(invoiceData.total || 0) - Number(invoiceData.paid_amount || 0)) * 100,
          ) / 100,
        ),
        customer_snapshot: invoiceData.customer_snapshot || {},
        notes: invoiceData.notes || null,
        created_by: authStore.user?.id,
        collection_date: invoiceData.collection_date || null,
      }

      // The DB trigger handles invoice_no generation
      const { data: invoice, error: invError } = await supabase
        .from('invoices')
        .insert(invoicePayload)
        .select()
        .single()

      if (invError) throw invError

      // Create items
      const preparedItems = items.map((item) => ({
        invoice_id: invoice.id,
        product_id: item.product_id || null,
        description: item.description,
        item_code: item.item_code || null,
        qty: Number(item.qty || 0),
        unit_price: Number(item.unit_price || 0),
        discount: Number(item.discount || 0),
        line_total: Number(item.line_total || 0),
        warranty: item.warranty || null,
        // Snapshots for financial history accuracy
        selling_unit_price_snapshot: Number(item.unit_price || item.selling_price || 0),
        cost_unit_price_snapshot: Number(item.cost_price || 0),
      }))

      const { error: itemsError } = await supabase.from('invoice_items').insert(preparedItems)

      if (itemsError) throw itemsError

      // Record initial payment if any
      if (invoiceData.paid_amount > 0) {
        const { error: payError } = await supabase.from('invoice_payments').insert({
          company_id: companyId,
          invoice_id: invoice.id,
          customer_id: invoiceData.customer_id || null,
          amount: Number(invoiceData.paid_amount),
          method: invoiceData.payment_type?.toUpperCase() || 'CASH',
          created_by: authStore.user?.id,
        })
        if (payError) throw payError
      }

      // Re-fetch the full invoice with items and updated totals (from triggers)
      return await getInvoice(invoice.id)
    } finally {
      loading.value = false
    }
  }

  async function addPayment(paymentData) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) throw new Error('Company ID missing')

      const { data, error } = await supabase
        .from('invoice_payments')
        .insert({
          company_id: companyId,
          invoice_id: paymentData.invoice_id,
          customer_id: paymentData.customer_id || null,
          amount: Number(paymentData.amount),
          method: paymentData.method || 'CASH',
          reference_no: paymentData.reference_no || null,
          note: paymentData.note || null,
          created_by: authStore.user?.id,
        })
        .select()
        .single()

      if (error) throw error
      return data
    } finally {
      loading.value = false
    }
  }

  async function fetchInvoices(filters = {}) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) return []

      let query = supabase
        .from('invoices')
        .select('*')
        .eq('company_id', companyId)
        .order('created_at', { ascending: false })

      if (filters.invoice_no) {
        query = query.ilike('invoice_no', `%${filters.invoice_no}%`)
      }

      if (filters.search) {
        query = query.or(
          `customer_snapshot->>name.ilike.%${filters.search}%,customer_snapshot->>phone.ilike.%${filters.search}%`,
        )
      }

      if (filters.dateFrom) {
        query = query.gte('invoice_date', filters.dateFrom)
      }
      if (filters.dateTo) {
        query = query.lte('invoice_date', filters.dateTo)
      }

      const { data, error } = await query.limit(100)
      if (error) throw error
      return data
    } catch (err) {
      console.error('[invoiceStore] fetchInvoices error:', err)
      return []
    } finally {
      loading.value = false
    }
  }

  async function getInvoice(id) {
    const { data: invoice, error: invError } = await supabase
      .from('invoices')
      .select(
        '*, items:invoice_items(id, invoice_id, product_id, description, item_code, qty, unit_price, discount, line_total, warranty, cost_unit_price_snapshot, selling_unit_price_snapshot)',
      )
      .eq('id', id)
      .single()

    if (invError) throw invError

    // Also fetch payments
    const { data: payments, error: payError } = await supabase
      .from('invoice_payments')
      .select('*')
      .eq('invoice_id', id)
      .order('paid_at', { ascending: false })

    if (payError) throw payError

    return { ...invoice, payments: payments || [] }
  }

  async function fetchOutstandingCollections(filters = {}) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) return []

      const { data, error } = await supabase.rpc('search_outstanding_invoices', {
        p_company_id: companyId,
        p_q: filters.search || null,
        p_from_date: filters.dateFrom || null,
        p_to_date: filters.dateTo || null,
        p_customer_id: filters.customer_id || null,
        p_overdue_only: !!filters.overdueOnly,
      })

      if (error) throw error
      return data
    } finally {
      loading.value = false
    }
  }

  async function fetchCollectionHistory(filters = {}) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) return []

      const { data, error } = await supabase.rpc('search_collection_history', {
        p_company_id: companyId,
        p_q: filters.search || null,
        p_from_date: filters.dateFrom || null,
        p_to_date: filters.dateTo || null,
        p_customer_id: filters.customer_id || null,
      })

      if (error) throw error
      return data
    } finally {
      loading.value = false
    }
  }

  return {
    loading,
    createInvoice,
    getInvoice,
    fetchInvoices,
    addPayment,
    fetchOutstandingCollections,
    fetchCollectionHistory,
  }
})

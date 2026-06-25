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

      const year = new Date().getFullYear().toString()
      const total = Number(invoiceData.total || 0)
      const paidAmount = Number(invoiceData.paid_amount || 0)
      const balance = Math.max(0, Math.round((total - paidAmount) * 100) / 100)
      const paymentStatus = paidAmount <= 0 ? 'unpaid' : balance <= 0 ? 'paid' : 'partial'

      // ── STEP 1: Get invoice number (atomic counter — race-condition safe) ──
      const { data: counter, error: counterErr } = await supabase.rpc('get_next_counter_value', {
        p_company_id: companyId,
        p_type: 'invoice',
      })
      if (counterErr) throw counterErr
      const invoiceNo = `INV-${year}-${String(counter).padStart(6, '0')}`

      // ── STEP 2: Insert invoice ────────────────────────────────────
      const { data: invoice, error: invError } = await supabase
        .from('invoices')
        .insert({
          company_id: companyId,
          customer_id: invoiceData.customer_id || null,
          status: invoiceData.status || 'issued',
          payment_type: invoiceData.payment_type || 'cash',
          payment_status: paymentStatus,
          subtotal: Number(invoiceData.subtotal || 0),
          discount: Number(invoiceData.discount || 0),
          tax: Number(invoiceData.tax || 0),
          total,
          paid_amount: paidAmount,
          balance,
          customer_snapshot: invoiceData.customer_snapshot || {},
          notes: invoiceData.notes || null,
          created_by: authStore.user?.id,
          invoice_no: invoiceNo,
          collection_date: invoiceData.collection_date || null,
          invoice_date: invoiceData.invoice_date || null,
          ...(invoiceData.is_vat_invoice
            ? {
                is_vat_invoice: true,
                vat_amount: Number(invoiceData.vat_amount || 0),
                total_before_vat: Number(invoiceData.total_before_vat || 0),
              }
            : {}),
          is_service_invoice: !!invoiceData.is_service_invoice,
          service_job_id: invoiceData.service_job_id || null,
          customer_po_no: invoiceData.customer_po_no || null,
        })
        .select('id, invoice_no')
        .single()

      if (invError) throw invError
      const invoiceId = invoice.id

      // ── STEP 3: Insert items + payment IN PARALLEL ────────────────
      const preparedItems = items
        .filter((i) => i.description)
        .map((item) => {
          const base = {
            invoice_id: invoiceId,
            product_id: item.product_id || null,
            description: item.description,
            item_code: item.item_code || null,
            qty: Number(item.qty || 0),
            unit_price: Number(item.unit_price || 0),
            discount: Number(item.discount || 0),
            line_total: Number(item.line_total || 0),
            warranty: item.warranty || null,
            serial_number: item.serial_number || null,
            selling_unit_price_snapshot: Number(item.unit_price || item.selling_price || 0),
            cost_unit_price_snapshot: Number(item.cost_price || 0),
          }
          // Only include new columns if they have meaningful values
          // (They will be ignored by Supabase if the columns don't exist yet,
          //  but we try-catch below to handle that case)
          base.discount_type = item.discount_type || 'amount'
          base.discount_amount = Number(item.discount_amount || item.discount || 0)
          return base
        })

      const parallelOps = []

      // Items insert
      if (preparedItems.length > 0) {
        parallelOps.push(
          supabase.from('invoice_items').insert(preparedItems).then(({ error }) => {
            if (error) {
              // If columns don't exist yet, retry without them
              if (error.message?.includes('discount_type') || error.message?.includes('discount_amount')) {
                const fallbackItems = preparedItems.map((item) => {
                  const rest = { ...item }
                  delete rest.discount_type
                  delete rest.discount_amount
                  return rest
                })
                return supabase.from('invoice_items').insert(fallbackItems).then(({ error: e2 }) => {
                  if (e2) throw e2
                })
              }
              throw error
            }
          }),
        )
      }

      // Payment insert
      if (paidAmount > 0) {
        parallelOps.push(
          supabase
            .from('invoice_payments')
            .insert({
              company_id: companyId,
              invoice_id: invoiceId,
              customer_id: invoiceData.customer_id || null,
              amount: paidAmount,
              method: invoiceData.payment_type?.toUpperCase() || 'CASH',
              created_by: authStore.user?.id,
            })
            .then(({ error }) => {
              if (error) console.warn('[invoiceStore] Payment insert warning:', error)
            }),
        )
      }

      // Run items + payment together
      await Promise.all(parallelOps)

      // ── STEP 4: Force-update totals (single fast update) ──────────
      await supabase
        .from('invoices')
        .update({
          subtotal: Number(invoiceData.subtotal || 0),
          discount: Number(invoiceData.discount || 0),
          tax: Number(invoiceData.tax || 0),
          total,
          paid_amount: paidAmount,
          balance,
          payment_status: paymentStatus,
          ...(invoiceData.is_vat_invoice
            ? {
                is_vat_invoice: true,
                vat_amount: Number(invoiceData.vat_amount || 0),
                total_before_vat: Number(invoiceData.total_before_vat || 0),
              }
            : {}),
        })
        .eq('id', invoiceId)

      // ── STEP 5: Stock deduction runs in BACKGROUND (non-blocking) ─
      const trackedItems = preparedItems.filter((i) => i.product_id)
      if (trackedItems.length > 0) {
        _deductStockInBackground(companyId, invoiceId, invoiceNo, trackedItems).catch((err) =>
          console.warn('[invoiceStore] Background stock deduction error:', err),
        )
      }

      // ── STEP 6: Return invoice immediately ────────────────────────
      return await getInvoice(invoiceId)
    } finally {
      loading.value = false
    }
  }

  // ── Background stock deduction (fire-and-forget) ──────────────────
  async function _deductStockInBackground(companyId, invoiceId, invoiceNo, trackedItems) {
    // Fetch warehouse + GIN counter + item details + fallback UOM all in PARALLEL
    const [whResult, ginResult, itemsResult, uomResult] = await Promise.all([
      supabase
        .from('warehouses')
        .select('id, branch_id')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('is_default', { ascending: false })
        .limit(1)
        .single(),
      supabase
        .from('inventory_documents')
        .select('doc_number')
        .eq('company_id', companyId)
        .like('doc_number', `GIN-${new Date().getFullYear()}-%`)
        .order('doc_number', { ascending: false })
        .limit(1)
        .single(),
      supabase
        .from('items')
        .select('id, avg_cost, inventory_uom_id')
        .in(
          'id',
          trackedItems.map((i) => i.product_id),
        ),
      supabase.from('uom').select('id').eq('company_id', companyId).limit(1).single(),
    ])

    const wh = whResult.data
    if (!wh) return

    // Generate GIN number
    const ginYear = new Date().getFullYear().toString()
    let ginCounter = 1
    if (ginResult.data?.doc_number) {
      const gParts = ginResult.data.doc_number.split('-')
      const gNum = parseInt(gParts[gParts.length - 1], 10)
      if (!isNaN(gNum)) ginCounter = gNum + 1
    }
    const ginDocNumber = `GIN-${ginYear}-${String(ginCounter).padStart(5, '0')}`

    // Create GIN document
    const { data: ginDoc, error: ginError } = await supabase
      .from('inventory_documents')
      .insert({
        company_id: companyId,
        branch_id: wh.branch_id,
        doc_type: 'GIN',
        doc_number: ginDocNumber,
        doc_date: new Date().toISOString().split('T')[0],
        warehouse_id: wh.id,
        reference_id: invoiceId,
        reference_type: 'invoice',
        status: 'draft',
        remarks: `Auto stock deduction for invoice ${invoiceNo}`,
        created_by: authStore.user?.id,
      })
      .select('id')
      .single()

    if (ginError || !ginDoc) return

    // Build item map
    const itemMap = {}
    ;(itemsResult.data || []).forEach((it) => {
      itemMap[it.id] = it
    })
    const fallbackUomId = uomResult.data?.id || null

    // Build GIN lines
    const ginLines = []
    let lineNum = 1
    for (const ti of trackedItems) {
      const detail = itemMap[ti.product_id] || {}
      const uomId = detail.inventory_uom_id || fallbackUomId
      if (uomId) {
        ginLines.push({
          document_id: ginDoc.id,
          line_number: lineNum++,
          item_id: ti.product_id,
          uom_id: uomId,
          quantity: ti.qty,
          unit_cost: detail.avg_cost || 0,
          notes: 'Sale from invoice',
        })
      }
    }

    if (ginLines.length > 0) {
      const { error: linesError } = await supabase
        .from('inventory_document_lines')
        .insert(ginLines)
      if (!linesError) {
        await supabase.from('inventory_documents').update({ status: 'posted' }).eq('id', ginDoc.id)
      }
    } else {
      await supabase.from('inventory_documents').delete().eq('id', ginDoc.id)
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
        query = query.ilike('invoice_no', `%${filters.invoice_no.trim()}%`)
      }

      if (filters.search && filters.search.trim() !== '') {
        const qStr = filters.search.trim()
        const qPattern = `%${qStr}%`

        // Search matching invoice items first
        const { data: itemData } = await supabase
          .from('invoice_items')
          .select('invoice_id')
          .ilike('description', qPattern)

        const matchedInvoiceIds = (itemData || []).map((i) => i.invoice_id)

        let orString = `invoice_no.ilike.${qPattern},customer_po_no.ilike.${qPattern},customer_snapshot->>name.ilike.${qPattern},customer_snapshot->>phone.ilike.${qPattern},notes.ilike.${qPattern}`

        if (matchedInvoiceIds.length > 0) {
          const uuidQueries = matchedInvoiceIds.map((id) => `id.eq.${id}`).join(',')
          orString += `,${uuidQueries}`
        }

        query = query.or(orString)
      }

      if (filters.dateFrom) {
        query = query.gte('invoice_date', filters.dateFrom)
      }
      if (filters.dateTo) {
        query = query.lte('invoice_date', filters.dateTo)
      }

      const { data, error } = await query
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
        '*, items:invoice_items(id, invoice_id, product_id, description, item_code, qty, unit_price, discount, line_total, warranty, serial_number, cost_unit_price_snapshot, selling_unit_price_snapshot, discount_type, discount_amount)',
      )
      .eq('id', id)
      .single()

    // If select fails due to missing columns, retry without them
    if (invError && (invError.message?.includes('discount_type') || invError.message?.includes('discount_amount'))) {
      const { data: fallbackInvoice, error: fallbackErr } = await supabase
        .from('invoices')
        .select(
          '*, items:invoice_items(id, invoice_id, product_id, description, item_code, qty, unit_price, discount, line_total, warranty, serial_number, cost_unit_price_snapshot, selling_unit_price_snapshot)',
        )
        .eq('id', id)
        .single()
      if (fallbackErr) throw fallbackErr
      // Add defaults for missing fields
      if (fallbackInvoice?.items) {
        fallbackInvoice.items = fallbackInvoice.items.map((i) => ({
          ...i,
          discount_type: 'amount',
          discount_amount: Number(i.discount || 0),
        }))
      }
      // Continue with fallback data
      const { data: payments } = await supabase
        .from('invoice_payments')
        .select('*')
        .eq('invoice_id', id)
        .order('paid_at', { ascending: false })
      fallbackInvoice.payments = payments || []
      return fallbackInvoice
    }

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

  async function deleteInvoice(id) {
    loading.value = true
    try {
      const { error } = await supabase.from('invoices').delete().eq('id', id)
      if (error) throw error
      return true
    } finally {
      loading.value = false
    }
  }

  async function updateInvoice(id, invoiceData, items) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) throw new Error('Company ID missing')

      // Build payload matching what update_invoice_v2 expects
      const _total      = Number(invoiceData.total || 0)
      const _paid       = Number(invoiceData.paid_amount || 0)
      const _balance    = Math.max(0, Math.round((_total - _paid) * 100) / 100)
      const _payStatus  = _balance <= 0 && _total > 0 ? 'paid'
                        : _paid > 0 && _balance > 0   ? 'partial'
                        : 'unpaid'

      const p_payload = {
        customer_id:       invoiceData.customer_id || null,
        status:            invoiceData.status || 'issued',
        payment_type:      invoiceData.payment_type || 'cash',
        subtotal:          String(Number(invoiceData.subtotal || 0)),
        discount:          String(Number(invoiceData.discount || 0)),
        tax:               String(Number(invoiceData.tax || 0)),
        total:             String(_total),
        paid_amount:       String(_paid),
        balance:           String(_balance),
        payment_status:    _payStatus,
        customer_snapshot: invoiceData.customer_snapshot || {},
        notes:             invoiceData.notes || null,
        collection_date:   invoiceData.collection_date || null,
        invoice_date:      invoiceData.invoice_date || null,
        is_vat_invoice:    String(!!invoiceData.is_vat_invoice),
        vat_amount:        String(Number(invoiceData.vat_amount || 0)),
        total_before_vat:  String(Number(invoiceData.total_before_vat || 0)),
        is_service_invoice: String(!!invoiceData.is_service_invoice),
        service_job_id:    invoiceData.service_job_id || null,
        customer_po_no:    invoiceData.customer_po_no || null,
        created_by:        invoiceData.created_by || null,
      }

      const p_items = items.map((item) => ({
        product_id: item.product_id || null,
        description: item.description,
        item_code: item.item_code || null,
        qty: String(Number(item.qty || 0)),
        unit_price: String(Number(item.unit_price || 0)),
        discount: String(Number(item.discount || 0)),
        discount_type: item.discount_type || 'amount',
        discount_amount: String(Number(item.discount_amount || item.discount || 0)),
        line_total: String(Number(item.line_total || 0)),
        warranty: item.warranty || null,
        serial_number: item.serial_number || null,
        selling_unit_price_snapshot: String(Number(item.unit_price || item.selling_price || 0)),
        cost_unit_price_snapshot: String(Number(item.cost_price || 0)),
      }))

      // update_invoice_v2 atomically:
      //   1. Cancels the existing posted GIN (reverses stock)
      //   2. Updates invoice header (incl. payment_status recalculation)
      //   3. Replaces invoice_items (with discount_type/discount_amount)
      //   4. Creates & posts a new GIN for updated items
      const { data, error: rpcError } = await supabase.rpc('update_invoice_v2', {
        p_invoice_id: id,
        p_items,        // pass as-is — discount_type/discount_amount handled by SQL
        p_payload,
      })

      if (rpcError) throw rpcError
      if (data?.success === false) throw new Error(data?.message || 'update_invoice_v2 failed')

      return await getInvoice(id)
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
    deleteInvoice,
    updateInvoice,
  }
})

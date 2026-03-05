import { ref } from 'vue'
import { supabase } from 'src/boot/supabase'

// =====================================================
// TYPE DEFINITIONS
// =====================================================

interface DocumentFilters {
  companyId?: string
  documentTypeId?: string
  warehouseId?: string
  status?: string
  dateFrom?: string
  dateTo?: string
}

interface DocumentHeader {
  company_id: string
  branch_id: string
  doc_type_code: string
  document_date?: string
  warehouse_id?: string
  target_warehouse_id?: string
  supplier_id?: string
  reference_no?: string
  remarks?: string
  created_by?: string
}

interface DocumentLineItem {
  stock_item_id: string
  quantity: number
  unit_cost?: number
  batch_no?: string
  expiry_date?: string
  counted_qty?: number
  variance_qty?: number
  notes?: string
}

// =====================================================
// INVENTORY DOCUMENTS (GRN, GIN, TRF, ADJ, CNT, etc.)
// =====================================================

export function useInventoryDocuments() {
  const documents = ref<any[]>([])
  const currentDoc = ref<any>(null)
  const docItems = ref<any[]>([])
  const documentTypes = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // ---------------------------------------------------
  // Fetch document types
  // ---------------------------------------------------
  async function fetchDocumentTypes() {
    const { data, error: err } = await supabase
      .from('inv_document_types')
      .select('*')
      .eq('is_active', true)
      .order('name')
    if (err) throw err
    documentTypes.value = data || []
    return data
  }

  // ---------------------------------------------------
  // List documents with filters
  // ---------------------------------------------------
  async function fetchDocuments(filters: DocumentFilters = {}, page = 1, pageSize = 25) {
    loading.value = true
    error.value = null
    try {
      let query = supabase
        .from('inv_documents')
        .select(
          `
          *,
          inv_document_types(code, name, direction),
          warehouses!warehouse_id(name, warehouse_type),
          target_warehouse:warehouses!target_warehouse_id(name),
          suppliers(name),
          profiles!created_by(full_name)
        `,
        )
        .order('created_at', { ascending: false })
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (filters.companyId) query = query.eq('company_id', filters.companyId)
      if (filters.documentTypeId) query = query.eq('document_type_id', filters.documentTypeId)
      if (filters.warehouseId) query = query.eq('warehouse_id', filters.warehouseId)
      if (filters.status) query = query.eq('status', filters.status)
      if (filters.dateFrom) query = query.gte('document_date', filters.dateFrom)
      if (filters.dateTo) query = query.lte('document_date', filters.dateTo)

      const { data, error: err } = await query
      if (err) throw err
      documents.value = data || []
    } catch (e: any) {
      error.value = e.message
    } finally {
      loading.value = false
    }
  }

  // ---------------------------------------------------
  // Fetch single document with lines
  // ---------------------------------------------------
  async function fetchDocument(docId: string) {
    loading.value = true
    try {
      const { data: header, error: err1 } = await supabase
        .from('inv_documents')
        .select(
          `
          *,
          inv_document_types(code, name, direction),
          warehouses!warehouse_id(name, warehouse_type),
          target_warehouse:warehouses!target_warehouse_id(name),
          suppliers(name),
          profiles!created_by(full_name)
        `,
        )
        .eq('id', docId)
        .single()
      if (err1) throw err1
      currentDoc.value = header

      const { data: items, error: err2 } = await supabase
        .from('inv_document_items')
        .select('*, stock_items(code, name, base_uom, avg_cost)')
        .eq('document_id', docId)
        .order('created_at')
      if (err2) throw err2
      docItems.value = items || []

      return { header, items }
    } catch (e: any) {
      error.value = e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  // ---------------------------------------------------
  // Create document (header + lines)
  // ---------------------------------------------------
  async function createDocument(headerData: DocumentHeader, lineItems: DocumentLineItem[] = []) {
    loading.value = true
    try {
      // Generate document number via RPC
      const { data: docNumber, error: seqErr } = await supabase.rpc('generate_inv_doc_number', {
        p_company_id: headerData.company_id,
        p_doc_type_code: headerData.doc_type_code,
      })
      if (seqErr) throw seqErr

      // Find doc type id
      const docType = documentTypes.value.find((dt: any) => dt.code === headerData.doc_type_code)
      if (!docType) throw new Error(`Unknown document type: ${headerData.doc_type_code}`)

      // Calculate totals
      const totalQty = lineItems.reduce((sum, li) => sum + (li.quantity || 0), 0)
      const totalAmt = lineItems.reduce(
        (sum, li) => sum + (li.quantity || 0) * (li.unit_cost || 0),
        0,
      )

      // Insert header
      const { data: doc, error: err1 } = await supabase
        .from('inv_documents')
        .insert({
          company_id: headerData.company_id,
          branch_id: headerData.branch_id,
          document_type_id: docType.id,
          document_number: docNumber,
          document_date: headerData.document_date || new Date().toISOString().split('T')[0],
          warehouse_id: headerData.warehouse_id,
          target_warehouse_id: headerData.target_warehouse_id || null,
          supplier_id: headerData.supplier_id || null,
          reference_no: headerData.reference_no || null,
          status: 'draft',
          remarks: headerData.remarks || null,
          total_amount: totalAmt,
          total_qty: totalQty,
          created_by: headerData.created_by,
        })
        .select()
        .single()
      if (err1) throw err1

      // Insert lines
      if (lineItems.length > 0) {
        const lines = lineItems.map((li) => ({
          document_id: doc.id,
          stock_item_id: li.stock_item_id,
          quantity: li.quantity,
          unit_cost: li.unit_cost || 0,
          batch_no: li.batch_no || null,
          expiry_date: li.expiry_date || null,
          counted_qty: li.counted_qty || null,
          variance_qty: li.variance_qty || null,
          notes: li.notes || null,
        }))

        const { error: err2 } = await supabase.from('inv_document_items').insert(lines)
        if (err2) throw err2
      }

      return doc
    } catch (e: any) {
      error.value = e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  // ---------------------------------------------------
  // Submit for approval
  // ---------------------------------------------------
  async function submitForApproval(docId: string) {
    const { data, error: err } = await supabase
      .from('inv_documents')
      .update({ status: 'pending_approval' })
      .eq('id', docId)
      .eq('status', 'draft')
      .select()
      .single()
    if (err) throw err
    return data
  }

  // ---------------------------------------------------
  // Approve document
  // ---------------------------------------------------
  async function approveDocument(docId: string, approvedBy: string) {
    const { data, error: err } = await supabase
      .from('inv_documents')
      .update({
        status: 'approved',
        approved_by: approvedBy,
        approved_at: new Date().toISOString(),
      })
      .eq('id', docId)
      .eq('status', 'pending_approval')
      .select()
      .single()
    if (err) throw err
    return data
  }

  // ---------------------------------------------------
  // Post document (calls the SQL function)
  // ---------------------------------------------------
  async function postDocument(docId: string) {
    // First update status to allow posting
    await supabase
      .from('inv_documents')
      .update({ status: 'approved' })
      .eq('id', docId)
      .in('status', ['draft', 'approved'])

    const { error: err } = await supabase.rpc('post_inv_document', {
      p_document_id: docId,
    })
    if (err) throw err
  }

  // ---------------------------------------------------
  // Cancel document
  // ---------------------------------------------------
  async function cancelDocument(docId: string) {
    const { data, error: err } = await supabase
      .from('inv_documents')
      .update({ status: 'cancelled' })
      .eq('id', docId)
      .not('status', 'eq', 'posted')
      .select()
      .single()
    if (err) throw err
    return data
  }

  // ---------------------------------------------------
  // Shorthand helpers for specific document types
  // ---------------------------------------------------

  async function createGRN(
    headerData: Omit<DocumentHeader, 'doc_type_code'>,
    items: DocumentLineItem[],
  ) {
    return createDocument({ ...headerData, doc_type_code: 'GRN' }, items)
  }

  async function createGIN(
    headerData: Omit<DocumentHeader, 'doc_type_code'>,
    items: DocumentLineItem[],
  ) {
    return createDocument({ ...headerData, doc_type_code: 'GIN' }, items)
  }

  async function createTransfer(
    headerData: Omit<DocumentHeader, 'doc_type_code'>,
    items: DocumentLineItem[],
  ) {
    return createDocument({ ...headerData, doc_type_code: 'TRF' }, items)
  }

  async function createAdjustment(
    headerData: Omit<DocumentHeader, 'doc_type_code'>,
    items: DocumentLineItem[],
  ) {
    return createDocument({ ...headerData, doc_type_code: 'ADJ' }, items)
  }

  async function createStockCount(
    headerData: Omit<DocumentHeader, 'doc_type_code'>,
    items: DocumentLineItem[],
  ) {
    return createDocument({ ...headerData, doc_type_code: 'CNT' }, items)
  }

  return {
    documents,
    currentDoc,
    docItems,
    documentTypes,
    loading,
    error,
    fetchDocumentTypes,
    fetchDocuments,
    fetchDocument,
    createDocument,
    submitForApproval,
    approveDocument,
    postDocument,
    cancelDocument,
    createGRN,
    createGIN,
    createTransfer,
    createAdjustment,
    createStockCount,
  }
}

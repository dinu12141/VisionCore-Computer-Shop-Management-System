/**
 * Inventory Service — centralised data layer for the Inventory module.
 *
 * All Supabase calls go through this single file.
 * The UI tabs import these composables instead of touching supabase directly.
 *
 * Naming convention follows the ACTUAL database tables:
 *   inventory_documents, inventory_document_lines, items, item_categories,
 *   warehouses, suppliers, uom, stock_on_hand, inventory_ledger
 *
 * Views:
 *   v_stock_on_hand, v_low_stock_alerts, v_inventory_ledger
 *
 * RPC:
 *   generate_inv_doc_number(p_company_id, p_doc_type)
 */

import { ref, type Ref } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'

/* -------------------------------------------------------
   Helpers — Lazy calls to useAuthStore() avoid calling
   before Pinia has initialized.
------------------------------------------------------- */

function getCompanyId(): string | null {
  const auth = useAuthStore()
  return auth.currentBranch?.company_id ?? auth.profile?.company_id ?? null
}

function getBranchId(): string | null {
  const auth = useAuthStore()
  return auth.currentBranch?.id ?? null
}

function getUserId(): string | null {
  const auth = useAuthStore()
  return auth.user?.id ?? null
}

/* ====================================================================
   DOCUMENT FILTERS
==================================================================== */

export interface DocumentFilters {
  docType?: string
  status?: string
  warehouseId?: string
  dateFrom?: string
  dateTo?: string
  search?: string
}

export interface DocumentLinePayload {
  item_id: string
  uom_id: string
  quantity: number
  unit_cost: number
  batch_no?: string
  expiry_date?: string
  system_qty?: number
  counted_qty?: number
  variance_qty?: number
  notes?: string
}

export interface DocumentHeaderPayload {
  doc_type: string
  doc_date: string
  warehouse_id: string
  target_warehouse_id?: string
  supplier_id?: string
  reference_no?: string
  remarks?: string
}

/* ====================================================================
   1.  listDocuments(filters)
==================================================================== */

export function useDocumentList() {
  const documents: Ref<any[]> = ref([])
  const loading = ref(false)
  const error: Ref<string | null> = ref(null)
  let channel: any = null

  async function listDocuments(filters: DocumentFilters = {}) {
    loading.value = true
    error.value = null
    try {
      const companyId = getCompanyId()
      if (!companyId) throw new Error('No company context — please log in.')

      let query = supabase
        .from('inventory_documents')
        .select(
          `
          *,
          warehouse:warehouses!warehouse_id(id, name, code, warehouse_type),
          target_wh:warehouses!target_warehouse_id(id, name, code),
          supplier:suppliers(id, name),
          creator:profiles!created_by(full_name)
        `,
        )
        .eq('company_id', companyId)
        .order('doc_date', { ascending: false })
        .order('created_at', { ascending: false })

      if (filters.docType) query = query.eq('doc_type', filters.docType)
      if (filters.status) query = query.eq('status', filters.status)
      if (filters.warehouseId) query = query.eq('warehouse_id', filters.warehouseId)
      if (filters.dateFrom) query = query.gte('doc_date', filters.dateFrom)
      if (filters.dateTo) query = query.lte('doc_date', filters.dateTo)
      if (filters.search) {
        query = query.or(
          `doc_number.ilike.%${filters.search}%,reference_no.ilike.%${filters.search}%`,
        )
      }

      const { data, error: err } = await query.limit(200)
      if (err) throw err

      // Flatten for UI convenience
      documents.value = (data || []).map((d: any) => ({
        ...d,
        warehouse_name: d.warehouse?.name || '',
        warehouse_code: d.warehouse?.code || '',
        target_warehouse_name: d.target_wh?.name || '',
        supplier_name: d.supplier?.name || '',
        created_by_name: d.creator?.full_name || '',
      }))

      // Real-time
      if (!channel) {
        channel = supabase
          .channel('inventory-docs-list-realtime')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'inventory_documents',
              filter: `company_id=eq.${companyId}`,
            },
            () => {
              listDocuments(filters)
            },
          )
          .subscribe()
      }
    } catch (e: any) {
      error.value = e.message
      console.error('[inventoryService] listDocuments error:', e)
    } finally {
      loading.value = false
    }
  }

  return { documents, loading, error, listDocuments }
}

/**
 * listOpenPOs()
 * Returns all POSTED Purchase Orders that have NOT been referenced by a GRN yet.
 */
export async function listOpenPOs() {
  const companyId = getCompanyId()
  if (!companyId) return []

  try {
    // 1. Get all posted POs
    const { data: pos, error: poErr } = await supabase
      .from('inventory_documents')
      .select(
        `
        *,
        supplier:suppliers!supplier_id(id, name, email),
        warehouse:warehouses!warehouse_id(id, name)
      `,
      )
      .eq('company_id', companyId)
      .eq('doc_type', 'PO')
      .eq('status', 'posted')
    if (poErr) throw poErr
    if (!pos || pos.length === 0) return []

    // 2. Get all GRNs to check which POs are already used
    // We look for "Imported from PO: {doc_number}" in the remarks
    const { data: grns, error: grnErr } = await supabase
      .from('inventory_documents')
      .select('remarks')
      .eq('company_id', companyId)
      .eq('doc_type', 'GRN')
      .not('status', 'eq', 'cancelled')

    if (grnErr) throw grnErr

    const usedPONumbers = new Set<string>()
    grns?.forEach((g) => {
      if (g.remarks) {
        pos.forEach((po) => {
          if (g.remarks.includes(`Imported from PO: ${po.doc_number}`)) {
            usedPONumbers.add(po.doc_number)
          }
        })
      }
    })

    return pos.filter((po) => !usedPONumbers.has(po.doc_number))
  } catch (e) {
    console.error('[inventoryService] listOpenPOs error:', e)
    throw e
  }
}

export interface DocumentHeaderPayload {
  doc_type: string
  doc_date: string
  warehouse_id: string
  target_warehouse_id?: string | null
  supplier_id?: string | null
  reference_no?: string | null
  remarks?: string | null
  // SAP Inspired fields
  posting_date?: string
  delivery_date?: string
  sub_total?: number
  tax_total?: number
  grand_total?: number
}

export interface DocumentLinePayload {
  item_id: string
  quantity: number
  unit_cost: number
  batch_no?: string
  expiry_date?: string
  notes?: string
  // SAP Inspired fields
  tax_code?: string
  tax_amount?: number
  line_total?: number
}

/* ====================================================================
   2.  fetchDocument(id)  — single doc + lines
==================================================================== */

export async function fetchDocumentById(docId: string) {
  const { data: header, error: err1 } = await supabase
    .from('inventory_documents')
    .select(
      `
      *,
      warehouse:warehouses!warehouse_id(id, name, code, warehouse_type),
      target_wh:warehouses!target_warehouse_id(id, name, code),
      supplier:suppliers(id, name, code, email),
      creator:profiles!created_by(full_name)
    `,
    )
    .eq('id', docId)
    .single()
  if (err1) throw err1

  const { data: lines, error: err2 } = await supabase
    .from('inventory_document_lines')
    .select(
      `
      *,
      item:items(id, code, name, avg_cost),
      uom:uom(id, code)
    `,
    )
    .eq('document_id', docId)
    .order('line_number')
  if (err2) throw err2

  return {
    header: {
      ...header,
      warehouse_name: header.warehouse?.name || '',
      supplier_name: header.supplier?.name || '',
      supplier_code: header.supplier?.code || '',
      supplier_email: header.supplier?.email || '',
      target_warehouse_name: header.target_wh?.name || '',
      created_by_name: header.creator?.full_name || '',
      reference_no: header.reference_type || '',
    },
    lines: (lines || []).map((l: any) => ({
      ...l,
      item_name: l.item?.name || '',
      item_code: l.item?.code || '',
      uom_code: l.uom?.code || '',
    })),
  }
}

/**
 * sendPOEmail(docId)
 * Triggers the send-po-email Edge Function
 */
export async function sendPOEmail(docId: string, customMessage?: string): Promise<any> {
  const { data, error } = await supabase.functions.invoke('send-po-email', {
    body: { docId, customMessage },
  })
  if (error) throw error
  return data
}

/* ====================================================================
   3.  createDocument(header, lines)
==================================================================== */

export async function createDocument(
  header: DocumentHeaderPayload,
  lines: DocumentLinePayload[],
): Promise<any> {
  const companyId = getCompanyId()
  const branchId = getBranchId()
  const userId = getUserId()

  if (!companyId || !branchId) throw new Error('No company/branch context.')

  // 1. Generate doc number via RPC
  const { data: docNumber, error: seqErr } = await supabase.rpc('generate_inv_doc_number', {
    p_company_id: companyId,
    p_doc_type: header.doc_type,
  })
  if (seqErr) throw seqErr

  // 2. Calculate totals
  const totalQty = lines.reduce((s, l) => s + (l.quantity || 0), 0)
  const totalCost = lines.reduce((s, l) => s + (l.quantity || 0) * (l.unit_cost || 0), 0)

  // 3. Insert header
  const { data: doc, error: err1 } = await supabase
    .from('inventory_documents')
    .insert({
      company_id: companyId,
      branch_id: branchId,
      doc_type: header.doc_type,
      doc_number: docNumber,
      doc_date: header.doc_date || new Date().toISOString().split('T')[0],
      warehouse_id: header.warehouse_id,
      target_warehouse_id: header.target_warehouse_id || null,
      supplier_id: header.supplier_id || null,
      remarks: header.remarks || null,
      status: 'draft',
      total_qty: totalQty,
      total_cost: totalCost,
      created_by: userId || null,
    })
    .select()
    .single()
  if (err1) throw err1

  // 4. Insert lines
  if (lines.length > 0) {
    const rows = lines.map((l, idx) => ({
      document_id: doc.id,
      line_number: idx + 1,
      item_id: l.item_id,
      uom_id: l.uom_id,
      quantity: l.quantity,
      unit_cost: l.unit_cost || 0,
      batch_no: l.batch_no || null,
      expiry_date: l.expiry_date || null,
      system_qty: l.system_qty ?? null,
      counted_qty: l.counted_qty ?? null,
      variance_qty: l.variance_qty ?? null,
      notes: l.notes || null,
    }))
    const { error: err2 } = await supabase.from('inventory_document_lines').insert(rows)
    if (err2) throw err2
  }

  return doc
}

/* ====================================================================
   4.  updateDraft(document)  — update header + replace lines
==================================================================== */

export async function updateDraft(
  docId: string,
  header: Partial<DocumentHeaderPayload>,
  lines: DocumentLinePayload[],
): Promise<any> {
  // Update header
  const totalQty = lines.reduce((s, l) => s + (l.quantity || 0), 0)
  const totalCost = lines.reduce((s, l) => s + (l.quantity || 0) * (l.unit_cost || 0), 0)

  const { data: doc, error: err1 } = await supabase
    .from('inventory_documents')
    .update({
      doc_type: header.doc_type,
      doc_date: header.doc_date,
      warehouse_id: header.warehouse_id,
      target_warehouse_id: header.target_warehouse_id || null,
      supplier_id: header.supplier_id || null,
      reference_no: header.reference_no || null,
      remarks: header.remarks || null,
      total_qty: totalQty,
      total_cost: totalCost,
      // SAP Fields
      posting_date: header.posting_date,
      delivery_date: header.delivery_date,
      sub_total: header.sub_total,
      tax_total: header.tax_total,
      grand_total: header.grand_total,
    })
    .eq('id', docId)
    .eq('status', 'draft') // RLS: only drafts can be edited
    .select()
    .single()
  if (err1) throw err1

  // Delete old lines, insert new ones
  const { error: delErr } = await supabase
    .from('inventory_document_lines')
    .delete()
    .eq('document_id', docId)
  if (delErr) throw delErr

  if (lines.length > 0) {
    const rows = lines.map((l, idx) => ({
      document_id: docId,
      line_number: idx + 1,
      item_id: l.item_id,
      uom_id: l.uom_id,
      quantity: l.quantity,
      unit_cost: l.unit_cost || 0,
      batch_no: l.batch_no || null,
      expiry_date: l.expiry_date || null,
      system_qty: l.system_qty ?? null,
      counted_qty: l.counted_qty ?? null,
      variance_qty: l.variance_qty ?? null,
      notes: l.notes || null,
      // SAP Fields
      tax_code: l.tax_code || null,
      tax_amount: l.tax_amount || 0,
      // line_total handled by DB
    }))
    const { error: err2 } = await supabase.from('inventory_document_lines').insert(rows)
    if (err2) throw err2
  }

  return doc
}

/* ====================================================================
   5.  postDocument(docId)
       Triggers the BEFORE UPDATE trigger which does all ledger inserts
==================================================================== */

export async function postDocument(docId: string): Promise<any> {
  const { data, error } = await supabase
    .from('inventory_documents')
    .update({ status: 'posted' })
    .eq('id', docId)
    .eq('status', 'draft')
    .select()
    .single()
  if (error) throw error
  return data
}

/* ====================================================================
   6.  cancelDocument(docId)
       The trigger's cancel branch creates reversal ledger entries
==================================================================== */

export async function cancelDocument(docId: string): Promise<any> {
  const { data, error } = await supabase
    .from('inventory_documents')
    .update({ status: 'cancelled' })
    .eq('id', docId)
    .eq('status', 'posted')
    .select()
    .single()
  if (error) throw error
  return data
}

export async function deleteDocument(docId: string): Promise<void> {
  const { error } = await supabase.from('inventory_documents').delete().eq('id', docId)
  if (error) throw error
}

/* ====================================================================
   7.  ITEMS MASTER (CRUD)
==================================================================== */

export function useItemsList() {
  const items: Ref<any[]> = ref([])
  const loading = ref(false)
  let channel: any = null

  async function listItems() {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) {
        return
      }

      const { data, error } = await supabase
        .from('v_items_registry')
        .select('*')
        .eq('company_id', companyId)
        .order('code', { ascending: false })

      if (error) throw error
      items.value = (data || []).map((i: any) => ({
        ...i,
        cost_price: Number(i.cost_price || 0),
        sale_price: Number(i.sale_price || 0),
        avg_cost: Number(i.avg_cost || 0),
        last_purchase_price: Number(i.last_purchase_price || 0),
        reorder_level: Number(i.reorder_level || 0),
        total_qty: Number(i.total_qty || 0),
        uom_id: i.inventory_uom_id || '',
      }))

      // Real-time
      if (!channel) {
        channel = supabase
          .channel('items-list-realtime')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'items',
              filter: `company_id=eq.${companyId}`,
            },
            () => {
              listItems()
            },
          )
          .subscribe()
      }
    } catch (e: any) {
      console.error('[inventoryService] listItems error:', e)
    } finally {
      loading.value = false
    }
  }

  function cleanItemPayload(payload: Record<string, any>, mode: 'create' | 'update' = 'create') {
    const clean = { ...payload }
    const toDelete = [
      // View-only fields (from v_items_registry / joins)
      'category_name',
      'uom_code',
      'uom_name',
      'uom_id', // items table uses inventory_uom_id, not uom_id
      'supplier_name',
      'total_qty',
      // Nested join objects returned by .select()
      'category',
      'inv_uom',
      'default_supplier',
      // System-managed
      'id',
      'created_at',
      'updated_at',
      'company_id',
      // UI-only fields that should never go to the DB
      'initial_stock',
      'initial_warehouse_id',
      // Prevent stock overwrites on item edit:
      'qty_on_hand',
      'stock_on_hand'
    ]
    // On update, also strip serials to prevent accidental overwrites
    if (mode === 'update') {
      toDelete.push('serials')
    }
    toDelete.forEach((key) => delete (clean as any)[key])
    return clean
  }

  async function createItem(item: Record<string, any>) {
    const companyId = getCompanyId()

    // Whitelist: only send columns that actually exist on the items table
    const validCols = [
      'category_id', 'code', 'name', 'description',
      'inventory_uom_id', 'purchase_uom_id', 'purchase_to_inventory_factor',
      'default_supplier_id', 'avg_cost', 'last_purchase_price',
      'reorder_level', 'reorder_qty', 'is_active',
      'cost_price', 'sale_price', 'brand', 'model_number',
      'barcode', 'warranty', 'serials', 'attrs',
    ]
    const dataToInsert: Record<string, any> = { company_id: companyId }
    for (const col of validCols) {
      if (item[col] !== undefined) {
        if (['cost_price', 'sale_price', 'avg_cost', 'last_purchase_price', 'reorder_level', 'reorder_qty'].includes(col)) {
          dataToInsert[col] = Number(item[col] || 0)
        } else {
          dataToInsert[col] = item[col]
        }
      }
    }

    const { data, error } = await supabase
      .from('items')
      .insert(dataToInsert)
      .select(
        `
        *,
        category:item_categories(id, name),
        inv_uom:uom!inventory_uom_id(id, code, name),
        default_supplier:suppliers(id, name)
      `,
      )
      .single()
    if (error) throw error

    const mapped = {
      ...data,
      cost_price: Number(data.cost_price || 0),
      sale_price: Number(data.sale_price || 0),
      avg_cost: Number(data.avg_cost || 0),
      last_purchase_price: Number(data.last_purchase_price || 0),
      reorder_level: Number(data.reorder_level || 0),
      category_name: data.category?.name || '',
      uom_code: data.inv_uom?.code || '',
      uom_id: data.inv_uom?.id || '',
      supplier_name: data.default_supplier?.name || '',
    }

    items.value.push(mapped)
    return mapped
  }

  async function updateItem(id: string, updates: Record<string, any>) {
    // Whitelist: only send columns that actually exist on the items table
    const validCols = [
      'category_id', 'code', 'name', 'description',
      'inventory_uom_id', 'purchase_uom_id', 'purchase_to_inventory_factor',
      'default_supplier_id', 'avg_cost', 'last_purchase_price',
      'reorder_level', 'reorder_qty', 'is_active',
      'cost_price', 'sale_price', 'brand', 'model_number',
      'barcode', 'warranty', 'attrs',
    ]
    const dataToUpdate: Record<string, any> = {}
    for (const col of validCols) {
      if (updates[col] !== undefined) {
        // Ensure numeric fields are numbers
        if (['cost_price', 'sale_price', 'avg_cost', 'last_purchase_price', 'reorder_level', 'reorder_qty'].includes(col)) {
          dataToUpdate[col] = Number(updates[col] || 0)
        } else {
          dataToUpdate[col] = updates[col]
        }
      }
    }

    console.log('[inventoryService] updateItem payload:', JSON.stringify(dataToUpdate))

    const { data, error } = await supabase
      .from('items')
      .update(dataToUpdate)
      .eq('id', id)
      .select(
        `
        *,
        category:item_categories(id, name),
        inv_uom:uom!inventory_uom_id(id, code, name),
        default_supplier:suppliers(id, name)
      `,
      )
      .single()
    if (error) throw error

    const mapped = {
      ...data,
      cost_price: Number(data.cost_price || 0),
      sale_price: Number(data.sale_price || 0),
      avg_cost: Number(data.avg_cost || 0),
      last_purchase_price: Number(data.last_purchase_price || 0),
      reorder_level: Number(data.reorder_level || 0),
      category_name: data.category?.name || '',
      uom_code: data.inv_uom?.code || '',
      uom_id: data.inv_uom?.id || '',
      supplier_name: data.default_supplier?.name || '',
    }

    const idx = items.value.findIndex((i: any) => i.id === id)
    if (idx !== -1) {
      items.value[idx] = mapped
    }
    return mapped
  }

  async function deactivateItem(id: string) {
    return updateItem(id, { is_active: false })
  }

  async function deleteItem(id: string) {
    const { error } = await supabase.from('items').delete().eq('id', id)
    if (error) throw error
    items.value = items.value.filter((i) => i.id !== id)
  }

  async function generateNextItemCode() {
    const companyId = getCompanyId()
    if (!companyId) return ''
    const { data, error } = await supabase.rpc('generate_item_code', {
      p_company_id: companyId,
    })
    if (error) throw error
    return data
  }

  return {
    items,
    loading,
    listItems,
    createItem,
    updateItem,
    deactivateItem,
    deleteItem,
    generateNextItemCode,
  }
}

/* ====================================================================
   8.  WAREHOUSES (CRUD)
==================================================================== */

export function useWarehouseList() {
  const warehouses: Ref<any[]> = ref([])
  const loading = ref(false)
  let channel: any = null

  async function listWarehouses() {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) {
        return
      }

      const { data, error } = await supabase
        .from('warehouses')
        .select('*')
        .eq('company_id', companyId)
        .order('warehouse_type')
        .order('name')

      if (error) throw error
      warehouses.value = data || []

      // Real-time
      if (!channel) {
        channel = supabase
          .channel('warehouses-list-realtime')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'warehouses',
              filter: `company_id=eq.${companyId}`,
            },
            () => {
              listWarehouses()
            },
          )
          .subscribe()
      }
    } catch (e: any) {
      console.error('[inventoryService] listWarehouses error:', e)
    } finally {
      loading.value = false
    }
  }

  async function createWarehouse(wh: Record<string, any>) {
    const companyId = getCompanyId()
    const branchId = getBranchId()
    const { data, error } = await supabase
      .from('warehouses')
      .insert({ ...wh, company_id: companyId, branch_id: branchId })
      .select()
      .single()
    if (error) throw error
    warehouses.value.push(data)
    return data
  }

  async function updateWarehouse(id: string, updates: Record<string, any>) {
    const { data, error } = await supabase
      .from('warehouses')
      .update(updates)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    const idx = warehouses.value.findIndex((w: any) => w.id === id)
    if (idx !== -1) warehouses.value[idx] = { ...warehouses.value[idx], ...data }
    return data
  }

  return { warehouses, loading, listWarehouses, createWarehouse, updateWarehouse }
}

/* ====================================================================
   9.  SUPPLIERS
==================================================================== */

export function useSupplierList() {
  const suppliers: Ref<any[]> = ref([])
  const loading = ref(false)

  async function listSuppliers() {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) {
        console.warn('[inventoryService] listSuppliers: No company ID found.')
        return
      }
      const { data, error } = await supabase
        .from('suppliers')
        .select('*')
        .eq('company_id', companyId)
        .order('name')
      if (error) throw error
      suppliers.value = data || []
    } catch (e: any) {
      console.error('[inventoryService] listSuppliers error:', e)
    } finally {
      loading.value = false
    }
  }

  async function createSupplier(supplier: Record<string, any>) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Authentication required: Company ID not found.')

    const payload: any = { ...supplier, company_id: companyId }
    // If code is missing, generate one
    if (!payload.code) {
      const { data: nextCode } = await supabase.rpc('generate_supplier_code', {
        p_company_id: companyId,
      })
      if (nextCode) payload.code = nextCode
    }

    const { data, error } = await supabase.from('suppliers').insert(payload).select().single()
    if (error) throw error
    suppliers.value.push(data)
    return data
  }

  async function updateSupplier(id: string, updates: Record<string, any>) {
    const { data, error } = await supabase
      .from('suppliers')
      .update(updates)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    const idx = suppliers.value.findIndex((s: any) => s.id === id)
    if (idx !== -1) suppliers.value[idx] = { ...suppliers.value[idx], ...data }
    return data
  }

  async function generateNextSupplierCode() {
    const companyId = getCompanyId()
    if (!companyId) return ''
    const { data, error } = await supabase.rpc('generate_supplier_code', {
      p_company_id: companyId,
    })
    if (error) throw error
    return data
  }

  async function deleteSupplier(id: string) {
    const { error } = await supabase.from('suppliers').delete().eq('id', id)
    if (error) throw error
    suppliers.value = suppliers.value.filter((s: any) => s.id !== id)
  }

  return {
    suppliers,
    loading,
    listSuppliers,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    generateNextSupplierCode,
  }
}

/* ====================================================================
   10.  CATEGORIES
==================================================================== */

export function useCategoryList() {
  const categories: Ref<any[]> = ref([])
  const loading = ref(false)
  let channel: any = null

  async function listCategories() {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) {
        return
      }
      const { data, error } = await supabase
        .from('item_categories')
        .select('*')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('name')
      if (error) throw error
      categories.value = data || []

      // Real-time subscription for categories
      if (!channel && companyId) {
        channel = supabase
          .channel('categories-list-realtime')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'item_categories',
              filter: `company_id=eq.${companyId}`,
            },
            () => {
              listCategories()
            },
          )
          .subscribe()
      }
    } catch (e: any) {
      console.error('[inventoryService] listCategories error:', e)
    } finally {
      loading.value = false
    }
  }

  async function createCategory(name: string) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('No company context.')

    const { data, error } = await supabase
      .from('item_categories')
      .insert({ name, company_id: companyId, is_active: true })
      .select('*')
      .single()

    if (error) throw error
    categories.value.push(data)
    categories.value.sort((a, b) => a.name.localeCompare(b.name))
    return data
  }

  return { categories, loading, listCategories, createCategory }
}

/* ====================================================================
   11.  UOMs
==================================================================== */

export function useUomList() {
  const uoms: Ref<any[]> = ref([])
  const loading = ref(false)

  async function listUoms() {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) return
      const { data, error } = await supabase
        .from('uom')
        .select('*')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('code')
      if (error) throw error
      uoms.value = data || []
    } catch (e: any) {
      console.error('[inventoryService] listUoms error:', e)
    } finally {
      loading.value = false
    }
  }

  return { uoms, loading, listUoms }
}

/* ====================================================================
   12.  STOCK ON HAND (Dashboard)
==================================================================== */

export function useStockDashboard() {
  const stockOnHand: Ref<any[]> = ref([])
  const lowStockAlerts: Ref<any[]> = ref([])
  const stats = ref({ totalStockValue: 0, lowStockCount: 0, todayGRN: 0, todayGIN: 0 })
  const loading = ref(false)
  let channel: any = null
  let docChannel: any = null
  let itemChannel: any = null

  async function loadStats() {
    const s = await fetchDashboardStats()
    stats.value = s
  }

  function updateAlerts() {
    lowStockAlerts.value = stockOnHand.value.filter(
      (r: any) => r.stock_status === 'low_stock' || r.stock_status === 'out_of_stock',
    )
  }

  async function fetchStockOnHand() {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) return

      // 1. Initial Fetch
      const [stockRes] = await Promise.all([
        supabase.from('v_stock_on_hand').select('*').eq('company_id', companyId).order('item_name'),
        loadStats(),
      ])

      if (stockRes.error) throw stockRes.error
      stockOnHand.value = stockRes.data || []
      updateAlerts()

      // 2. Real-time Subscription for Stock
      if (!channel) {
        channel = supabase
          .channel('stock-on-hand-realtime')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'stock_on_hand',
              filter: `company_id=eq.${companyId}`,
            },
            async () => {
              const { data: newData } = await supabase
                .from('v_stock_on_hand')
                .select('*')
                .eq('company_id', companyId)
                .order('item_name')
              if (newData) {
                stockOnHand.value = newData
                updateAlerts()
                // Also refresh aggregate stats when stock values change
                await loadStats()
              }
            },
          )
          .subscribe()
      }

      // 3. Real-time Subscription for Documents (GRN/GIN counts)
      if (!docChannel) {
        docChannel = supabase
          .channel('inventory-docs-realtime')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'inventory_documents',
              filter: `company_id=eq.${companyId}`,
            },
            () => {
              loadStats()
            },
          )
          .subscribe()
      }

      // 4. Real-time Subscription for Items Master (Products count)
      if (!itemChannel) {
        itemChannel = supabase
          .channel('inventory-items-realtime')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'items',
              filter: `company_id=eq.${companyId}`,
            },
            () => {
              loadStats()
            },
          )
          .subscribe()
      }
    } catch (e: any) {
      console.error('[inventoryService] fetchStockOnHand error:', e)
    } finally {
      loading.value = false
    }
  }

  return { stockOnHand, lowStockAlerts, stats, loading, fetchStockOnHand }
}

/* ====================================================================
   13.  STOCK LEDGER (Audit Trail)
==================================================================== */

export interface LedgerFilters {
  docType?: string
  direction?: string
  dateFrom?: string
  dateTo?: string
  search?: string
}

export function useStockLedger() {
  const entries: Ref<any[]> = ref([])
  const loading = ref(false)
  let channel: any = null

  async function fetchLedger(filters: LedgerFilters = {}) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) return
      let query = supabase
        .from('v_inventory_ledger')
        .select('*')
        .eq('company_id', companyId)
        .order('posted_at', { ascending: false })
        .limit(500)

      if (filters.docType) query = query.eq('doc_type', filters.docType)
      if (filters.direction) query = query.eq('direction', filters.direction)
      if (filters.dateFrom) query = query.gte('posted_at', filters.dateFrom)
      if (filters.dateTo) query = query.lte('posted_at', filters.dateTo + 'T23:59:59')
      if (filters.search)
        query = query.or(`item_name.ilike.%${filters.search}%,doc_number.ilike.%${filters.search}%`)

      const { data, error } = await query
      if (error) throw error
      entries.value = data || []

      // Real-time subscription for ledger entries
      if (!channel) {
        channel = supabase
          .channel('inventory-ledger-realtime')
          .on(
            'postgres_changes',
            {
              event: 'INSERT',
              schema: 'public',
              table: 'inventory_ledger',
              filter: `company_id=eq.${companyId}`,
            },
            async () => {
              // Refresh siliently to get updated view data
              const { data: newData } = await supabase
                .from('v_inventory_ledger')
                .select('*')
                .eq('company_id', companyId)
                .order('posted_at', { ascending: false })
                .limit(500)
              if (newData) entries.value = newData
            },
          )
          .subscribe()
      }
    } catch (e: any) {
      console.error('[inventoryService] fetchLedger error:', e)
    } finally {
      loading.value = false
    }
  }

  return { entries, loading, fetchLedger }
}

/* ====================================================================
   14.  DASHBOARD STATS (aggregated via RPC or simple queries)
==================================================================== */

export async function fetchDashboardStats() {
  const companyId = getCompanyId()
  if (!companyId) {
    return { totalStockValue: 0, lowStockCount: 0, todayGRN: 0, todayGIN: 0, totalItems: 0 }
  }
  const today = new Date().toISOString().split('T')[0]

  const [stockRes, grnRes, ginRes, itemsRes] = await Promise.all([
    supabase
      .from('v_stock_on_hand')
      .select('total_value, stock_status')
      .eq('company_id', companyId),
    supabase
      .from('inventory_documents')
      .select('id', { count: 'exact', head: true })
      .eq('company_id', companyId)
      .eq('doc_type', 'GRN')
      .eq('status', 'posted')
      .eq('doc_date', today),
    supabase
      .from('inventory_documents')
      .select('id', { count: 'exact', head: true })
      .eq('company_id', companyId)
      .eq('doc_type', 'GIN')
      .eq('status', 'posted')
      .eq('doc_date', today),
    supabase.from('items').select('id', { count: 'exact', head: true }).eq('company_id', companyId),
  ])

  const stockRows = stockRes.data || []
  const totalValue = stockRows.reduce((s: number, r: any) => s + (r.total_value || 0), 0)
  const lowStockCount = stockRows.filter(
    (r: any) => r.stock_status === 'low_stock' || r.stock_status === 'out_of_stock',
  ).length

  return {
    totalStockValue: totalValue,
    lowStockCount,
    todayGRN: grnRes.count ?? 0,
    todayGIN: ginRes.count ?? 0,
    totalItems: itemsRes.count ?? 0,
  }
}

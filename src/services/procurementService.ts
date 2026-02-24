/**
 * procurementService.ts
 * =====================
 * Full Supabase-backed service for the Procurement module.
 * Covers: Suppliers, PO, GRN, AP Invoices, Payments, Returns.
 *
 * Design decisions:
 *  - All mutating operations (POST / status changes) run through Supabase RPC
 *    wrappers (SECURITY DEFINER) so validation and ledger logic sit in the DB.
 *  - All helpers return { data, error } so callers can handle errors uniformly.
 *  - Toast feedback via Quasar $q.notify is NOT done here; callers handle UX.
 *    The service only throws / rejects with descriptive error messages.
 *  - Loading state is managed in the composable / page layer.
 */

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'

// ─────────────────────────────────────────────
// Types (mirrors DB schema)
// ─────────────────────────────────────────────

export interface Supplier {
  id: string
  code: string
  name: string
  contact_person?: string
  phone?: string
  email?: string
  address?: string
  tax_id?: string
  payment_terms_days?: number
  is_active: boolean
  payment_term_id?: string
  credit_limit?: number
  balance?: number
}

export interface POLine {
  id?: string
  line_number: number
  item_id: string
  description?: string
  uom_id: string
  quantity: number
  unit_price: number
  discount_pct?: number
  tax_pct?: number
  warehouse_id?: string
  notes?: string
  // computed / read-only
  received_qty?: number
  invoiced_qty?: number
  returned_qty?: number
  open_qty?: number
  line_total?: number
}

export interface PurchaseOrder {
  id?: string
  doc_number?: string
  doc_date: string
  expected_date?: string
  supplier_id: string
  warehouse_id?: string
  currency?: string
  exchange_rate?: number
  status?: string
  subtotal?: number
  discount_pct?: number
  discount_amount?: number
  tax_amount?: number
  total_amount?: number
  remarks?: string
  internal_memo?: string
  lines?: POLine[]
}

export interface GRNLine {
  id?: string
  line_number: number
  po_line_id?: string
  item_id: string
  description?: string
  uom_id: string
  quantity: number
  unit_cost: number
  batch_no?: string
  expiry_date?: string
  warehouse_id?: string
  notes?: string
  invoiced_qty?: number
  line_total?: number
}

export interface GoodsReceipt {
  id?: string
  doc_number?: string
  doc_date: string
  po_id?: string
  supplier_id: string
  warehouse_id: string
  status?: string
  subtotal?: number
  tax_amount?: number
  total_amount?: number
  remarks?: string
  lines?: GRNLine[]
}

export interface APInvoiceLine {
  id?: string
  line_number: number
  grn_line_id?: string
  po_line_id?: string
  item_id?: string
  description?: string
  uom_id?: string
  quantity: number
  unit_price: number
  discount_pct?: number
  tax_pct?: number
  notes?: string
  line_total?: number
}

export interface APInvoice {
  id?: string
  doc_number?: string
  supplier_inv_no?: string
  doc_date: string
  due_date?: string
  supplier_id: string
  grn_id?: string
  po_id?: string
  currency?: string
  exchange_rate?: number
  status?: string
  subtotal?: number
  discount_pct?: number
  discount_amount?: number
  tax_amount?: number
  total_amount?: number
  paid_amount?: number
  balance_due?: number
  remarks?: string
  lines?: APInvoiceLine[]
}

export interface PaymentAllocation {
  invoice_id: string
  amount: number
}

export interface SupplierPayment {
  id?: string
  doc_number?: string
  doc_date: string
  supplier_id: string
  payment_method: 'cash' | 'bank_transfer' | 'cheque' | 'credit_card' | 'wowcher' | 'other'
  bank_account?: string
  cheque_no?: string
  cheque_date?: string
  reference_no?: string
  currency?: string
  exchange_rate?: number
  total_amount: number
  allocated_amount?: number
  status?: string
  remarks?: string
  allocations?: PaymentAllocation[]
}

export interface ReturnLine {
  id?: string
  line_number: number
  grn_line_id?: string
  item_id: string
  description?: string
  uom_id: string
  quantity: number
  unit_cost: number
  batch_no?: string
  return_reason?: string
  notes?: string
  line_total?: number
}

export interface PurchaseReturn {
  id?: string
  doc_number?: string
  doc_date: string
  grn_id?: string
  supplier_id: string
  warehouse_id: string
  status?: string
  subtotal?: number
  tax_amount?: number
  total_amount?: number
  return_reason?: string
  remarks?: string
  lines?: ReturnLine[]
}

export interface POFilterOptions {
  status?: string
  supplier_id?: string
  from_date?: string
  to_date?: string
}

export interface InvoiceFilterOptions {
  status?: string
  supplier_id?: string
  from_date?: string
  to_date?: string
}

// ─────────────────────────────────────────────
// Internal helper – get company_id / branch_id
// ─────────────────────────────────────────────
function getContext(): { company_id: string; branch_id: string; user_id: string } {
  const authStore = useAuthStore()
  const branch = authStore.currentBranch
  const user_id = authStore.user?.id

  if (!branch?.id || !branch?.company_id) {
    throw new Error('No active branch found. Please select a branch first.')
  }
  if (!user_id) {
    throw new Error('Not authenticated.')
  }
  return {
    company_id: branch.company_id as string,
    branch_id: branch.id as string,
    user_id,
  }
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 1: SUPPLIERS
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/**
 * List all suppliers for the current company.
 * Optional: filter by active status.
 */
export async function listSuppliers(activeOnly = false): Promise<Supplier[]> {
  const { company_id } = getContext()
  let query = supabase
    .from('suppliers')
    .select(
      'id, code, name, contact_person, phone, email, address, tax_id, payment_terms_days, is_active, credit_limit, balance',
    )
    .eq('company_id', company_id)
    .order('name')

  if (activeOnly) {
    query = query.eq('is_active', true)
  }

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return (data ?? []) as any[]
}

/**
 * Create or update a supplier record.
 * Pass `id` to update, omit to create.
 */
export async function upsertSupplier(
  supplier: Partial<Supplier> & { name: string; code?: string },
) {
  const { company_id, user_id } = getContext()

  let finalCode = supplier.code
  if (!supplier.id && !finalCode) {
    const { data: nextCode } = await supabase.rpc('generate_supplier_code', {
      p_company_id: company_id,
    })
    finalCode = nextCode || `SUP-${Date.now()}`
  }

  const payload: any = {
    name: supplier.name,
    code: finalCode,
    contact_person: supplier.contact_person,
    phone: supplier.phone,
    email: supplier.email,
    address: supplier.address,
    tax_id: supplier.tax_id,
    payment_terms_days: supplier.payment_terms_days || 30,
    is_active: supplier.is_active ?? true,
    payment_term_id: supplier.payment_term_id,
  }

  if (supplier.id) {
    // Update
    const { data, error } = await supabase
      .from('suppliers')
      .update(payload)
      .eq('id', supplier.id)
      .select()
      .single()
    if (error) throw new Error(error.message)
    return data
  } else {
    // Create
    const { data, error } = await supabase
      .from('suppliers')
      .insert({
        ...payload,
        company_id,
        created_by: user_id,
      })
      .select()
      .single()
    if (error) throw new Error(error.message)
    return data
  }
}

/**
 * Fetch the current outstanding balance and ledger summary for a supplier.
 */
export async function getSupplierBalance(supplierId: string) {
  const { company_id } = getContext()

  const [supplierRes, ledgerRes] = await Promise.all([
    supabase
      .from('suppliers')
      .select('id, name')
      .eq('id', supplierId)
      .eq('company_id', company_id)
      .single(),
    supabase
      .from('ap_ledger')
      .select('entry_type, debit, credit')
      .eq('supplier_id', supplierId)
      .eq('company_id', company_id),
  ])

  if (supplierRes.error) throw new Error(supplierRes.error.message)

  const ledger = ledgerRes.data ?? []
  const totalDebit = ledger.reduce((s, r) => s + (r.debit || 0), 0)
  const totalCredit = ledger.reduce((s, r) => s + (r.credit || 0), 0)

  return {
    supplier: supplierRes.data,
    totalDebit,
    totalCredit,
    computedBalance: totalCredit - totalDebit,
  }
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 2: PURCHASE ORDERS
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/**
 * List purchase orders with optional filters.
 */
export async function listPO(filters: POFilterOptions = {}): Promise<PurchaseOrder[]> {
  const { company_id } = getContext()

  let query = supabase
    .from('purchase_orders')
    .select(
      `id, doc_number, doc_date, expected_date:delivery_date, status,
       supplier_id, suppliers(id, name, code),
       payment_term_id, warehouse_id,
       subtotal, discount_amount, tax_amount, total_amount,
       remarks, created_at, approved_at, closed_at`,
    )
    .eq('company_id', company_id)
    .order('doc_date', { ascending: false })

  if (filters.status) query = query.eq('status', filters.status)
  if (filters.supplier_id) query = query.eq('supplier_id', filters.supplier_id)
  if (filters.from_date) query = query.gte('doc_date', filters.from_date)
  if (filters.to_date) query = query.lte('doc_date', filters.to_date)

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return (data ?? []) as unknown as PurchaseOrder[]
}

/**
 * Fetch a single PO with all its lines.
 */
export async function getPODetails(poId: string) {
  const { data: po, error: poErr } = await supabase
    .from('purchase_orders')
    .select(
      `*,
       suppliers(id, name, code, payment_term_id),
       purchase_order_lines(
         *,
         items!purchase_order_lines_item_id_fkey(id, name, code, purchase_uom_id),
         uom!purchase_order_lines_uom_id_fkey(id, code, name)
       )`,
    )
    .eq('id', poId)
    .single()

  if (poErr) throw new Error(poErr.message)

  // Map fields for frontend
  if (po) {
    if (po.delivery_date) po.expected_date = po.delivery_date
    if (po.purchase_order_lines) {
      po.lines = po.purchase_order_lines.map((l: any) => ({
        ...l,
        default_uom_id: l.items?.purchase_uom_id,
        unit_cost: l.items?.last_purchase_price,
      }))
    }
  }

  return po
}

/**
 * Create a new Purchase Order with lines.
 * The trigger/function handles doc_number generation via generate_proc_doc_number().
 */
export async function createPO(header: Omit<PurchaseOrder, 'id' | 'doc_number'>, lines: POLine[]) {
  const { company_id, branch_id, user_id } = getContext()

  if (!lines || lines.length === 0) throw new Error('At least one line item is required.')

  // Insert header
  const { data: po, error: poErr } = await supabase
    .from('purchase_orders')
    .insert({
      company_id,
      branch_id,
      doc_number: `PO-DRAFT-${Date.now()}`, // temporary, trigger-aware prefix
      doc_date: header.doc_date,
      delivery_date: header.expected_date || null,
      supplier_id: header.supplier_id,
      warehouse_id: header.warehouse_id || null,
      currency: header.currency || 'LKR',
      exchange_rate: header.exchange_rate || 1,
      remarks: header.remarks || null,
      internal_memo: header.internal_memo || null,
      status: 'draft',
      created_by: user_id,
    })
    .select()
    .single()

  if (poErr) throw new Error(poErr.message)

  // Generate proper doc number
  const { data: docNum, error: seqErr } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'PO',
  })
  if (!seqErr && docNum) {
    await supabase.from('purchase_orders').update({ doc_number: docNum }).eq('id', po.id)
  }

  // Insert lines
  const linePayloads = lines.map((l, idx) => ({
    po_id: po.id,
    line_number: idx + 1,
    item_id: l.item_id,
    description: l.description || null,
    uom_id: l.uom_id,
    quantity: l.quantity,
    unit_price: l.unit_price,
    discount_pct: l.discount_pct || 0,
    tax_pct: l.tax_pct || 0,
    warehouse_id: l.warehouse_id || null,
    notes: l.notes || null,
  }))

  const { error: linesErr } = await supabase.from('purchase_order_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  // Update totals on header
  const subtotal = lines.reduce(
    (s, l) => s + l.quantity * l.unit_price * (1 - (l.discount_pct || 0) / 100),
    0,
  )
  await supabase
    .from('purchase_orders')
    .update({ subtotal, total_amount: subtotal })
    .eq('id', po.id)

  return po
}

/**
 * Approve a draft PO → status becomes 'approved' (open for GRN).
 */
export async function approvePO(poId: string) {
  const { user_id } = getContext()
  const { error } = await supabase
    .from('purchase_orders')
    .update({ status: 'approved', approved_by: user_id, approved_at: new Date().toISOString() })
    .eq('id', poId)
    .eq('status', 'draft')

  if (error) throw new Error(error.message)
  return { success: true }
}

/**
 * Cancel a PO (only if draft or approved).
 */
export async function cancelPO(poId: string, reason?: string) {
  const { error } = await supabase
    .from('purchase_orders')
    .update({
      status: 'cancelled',
      cancel_reason: reason || null,
      cancelled_at: new Date().toISOString(),
    })
    .eq('id', poId)
    .in('status', ['draft', 'approved'])

  if (error) throw new Error(error.message)
  return { success: true }
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 3: GOODS RECEIPTS (GRN)
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/**
 * List GRNs with optional filters.
 */
export async function listGRNs(
  filters: { status?: string; supplier_id?: string; from_date?: string; to_date?: string } = {},
) {
  const { company_id } = getContext()
  let query = supabase
    .from('goods_receipts')
    .select(
      `id, doc_number, doc_date, status, total_amount, remarks,
       supplier_id, suppliers(id, name, code),
       po_id, purchase_orders(id, doc_number),
       warehouse_id, warehouses(id, name),
       posted_at, created_at`,
    )
    .eq('company_id', company_id)
    .order('doc_date', { ascending: false })

  if (filters.status) query = query.eq('status', filters.status)
  if (filters.supplier_id) query = query.eq('supplier_id', filters.supplier_id)
  if (filters.from_date) query = query.gte('doc_date', filters.from_date)
  if (filters.to_date) query = query.lte('doc_date', filters.to_date)

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return data ?? []
}

/**
 * Fetch a single GRN with its lines.
 */
export async function getGRNDetails(grnId: string) {
  const { data, error } = await supabase
    .from('goods_receipts')
    .select(
      `*, suppliers(id, name, code),
       purchase_orders(id, doc_number),
       warehouses(id, name),
       goods_receipt_lines(
         *,
         items!goods_receipt_lines_item_id_fkey(id, name, code, purchase_uom_id),
         uom!goods_receipt_lines_uom_id_fkey(id, code, name)
       ) mapping_lines`,
    )
    .eq('id', grnId)
    .single()

  if (error) throw new Error(error.message)
  return data
}

/**
 * Create a GRN pre-populated from a Purchase Order.
 * Copies open PO lines into GRN lines (max: open_qty per line).
 */
export async function createGRNFromPO(
  poId: string,
  overrides: {
    doc_date?: string
    warehouse_id?: string
    remarks?: string
  } = {},
) {
  const { company_id, branch_id, user_id } = getContext()

  // Fetch PO header + open lines
  const { data: po, error: poErr } = await supabase
    .from('purchase_orders')
    .select(
      `*, purchase_order_lines(
         id, item_id, description, uom_id, quantity, unit_price,
         discount_pct, open_qty, warehouse_id, notes
       )`,
    )
    .eq('id', poId)
    .single()

  if (poErr) throw new Error(poErr.message)
  if (!po) throw new Error('PO not found.')
  if (!['approved', 'open', 'partial'].includes(po.status)) {
    throw new Error(
      `PO "${po.doc_number}" is ${po.status}. Only approved/open/partial POs can receive goods.`,
    )
  }

  const openLines = (po.purchase_order_lines ?? []).filter((l: any) => (l.open_qty ?? 0) > 0)
  if (openLines.length === 0) throw new Error('All lines on this PO have been fully received.')

  // Create GRN header
  const warehouseId = overrides.warehouse_id || po.warehouse_id
  if (!warehouseId)
    throw new Error('Warehouse required. Set a warehouse on the PO or pass one explicitly.')

  const { data: docNum } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'GRN',
  })

  const { data: grn, error: grnErr } = await supabase
    .from('goods_receipts')
    .insert({
      company_id,
      branch_id,
      doc_number: docNum || `GRN-${Date.now()}`,
      doc_date: overrides.doc_date || new Date().toISOString().slice(0, 10),
      po_id: poId,
      supplier_id: po.supplier_id,
      warehouse_id: warehouseId,
      remarks: overrides.remarks || null,
      status: 'draft',
      created_by: user_id,
    })
    .select()
    .single()

  if (grnErr) throw new Error(grnErr.message)

  // Insert GRN lines from PO open lines
  const linePayloads = openLines.map((pol: any, idx: number) => ({
    grn_id: grn.id,
    line_number: idx + 1,
    po_line_id: pol.id,
    item_id: pol.item_id,
    description: pol.description || null,
    uom_id: pol.uom_id,
    quantity: pol.open_qty,
    unit_cost: pol.unit_price ?? 0,
    warehouse_id: pol.warehouse_id || warehouseId,
    notes: pol.notes || null,
  }))

  const { error: linesErr } = await supabase.from('goods_receipt_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  // Update subtotal
  const subtotal = linePayloads.reduce(
    (s: number, l: any) => s + l.quantity * (l.unit_cost ?? 0),
    0,
  )
  await supabase
    .from('goods_receipts')
    .update({ subtotal, total_amount: subtotal })
    .eq('id', grn.id)

  return grn
}

/**
 * Create a direct GRN (not from a PO).
 */
export async function createGRN(header: Omit<GoodsReceipt, 'id' | 'doc_number'>, lines: GRNLine[]) {
  const { company_id, branch_id, user_id } = getContext()

  if (!lines || lines.length === 0) throw new Error('At least one line item is required.')
  if (!header.warehouse_id) throw new Error('Warehouse is required.')

  const { data: docNum } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'GRN',
  })

  const { data: grn, error: grnErr } = await supabase
    .from('goods_receipts')
    .insert({
      company_id,
      branch_id,
      doc_number: docNum || `GRN-${Date.now()}`,
      doc_date: header.doc_date,
      po_id: header.po_id || null,
      supplier_id: header.supplier_id,
      warehouse_id: header.warehouse_id,
      remarks: header.remarks || null,
      status: 'draft',
      created_by: user_id,
    })
    .select()
    .single()

  if (grnErr) throw new Error(grnErr.message)

  const linePayloads = lines.map((l, idx) => ({
    grn_id: grn.id,
    line_number: idx + 1,
    po_line_id: l.po_line_id || null,
    item_id: l.item_id,
    description: l.description || null,
    uom_id: l.uom_id,
    quantity: l.quantity,
    unit_cost: l.unit_cost ?? 0,
    batch_no: l.batch_no || null,
    expiry_date: l.expiry_date || null,
    warehouse_id: l.warehouse_id || null,
    notes: l.notes || null,
  }))

  const { error: linesErr } = await supabase.from('goods_receipt_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  const subtotal = lines.reduce((s, l) => s + l.quantity * (l.unit_cost ?? 0), 0)
  await supabase
    .from('goods_receipts')
    .update({ subtotal, total_amount: subtotal })
    .eq('id', grn.id)

  return grn
}

/**
 * Update an existing draft GRN.
 */
export async function updateGRN(grnId: string, header: Partial<GoodsReceipt>, lines: GRNLine[]) {
  const { user_id } = getContext()

  // Update header
  const { error: grnErr } = await supabase
    .from('goods_receipts')
    .update({
      doc_date: header.doc_date,
      warehouse_id: header.warehouse_id,
      remarks: header.remarks,
      updated_at: new Date().toISOString(),
    })
    .eq('id', grnId)
    .eq('status', 'draft')

  if (grnErr) throw new Error(grnErr.message)

  // Update lines: Simple approach - delete and re-insert
  const { error: delErr } = await supabase.from('goods_receipt_lines').delete().eq('grn_id', grnId)
  if (delErr) throw new Error(delErr.message)

  const linePayloads = lines.map((l, idx) => ({
    grn_id: grnId,
    line_number: idx + 1,
    po_line_id: l.po_line_id || null,
    item_id: l.item_id,
    description: l.description || null,
    uom_id: l.uom_id,
    quantity: l.quantity,
    unit_cost: l.unit_cost ?? 0,
    batch_no: l.batch_no || null,
    expiry_date: l.expiry_date || null,
    warehouse_id: l.warehouse_id || null,
    notes: l.notes || null,
  }))

  const { error: linesErr } = await supabase.from('goods_receipt_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  // Update subtotal
  const subtotal = lines.reduce((s, l) => s + l.quantity * (l.unit_cost ?? 0), 0)
  await supabase.from('goods_receipts').update({ subtotal, total_amount: subtotal }).eq('id', grnId)

  return { id: grnId }
}

/**
 * Post a GRN via safe RPC wrapper.
 * On success: stock updated, PO received_qty updated, avg cost recalculated.
 */
export async function postGRN(
  grnId: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('post_grn', { p_grn_id: grnId })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

/**
 * Cancel a posted GRN via safe RPC wrapper.
 */
export async function cancelGRN(
  grnId: string,
  reason?: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('cancel_grn', {
    p_grn_id: grnId,
    p_reason: reason ?? null,
  })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

/** Stub – returns a print URL or triggers browser print */
export function printGRN(grnId: string) {
  // TODO: Integrate with a reporting/PDF service
  console.info('[printGRN] stub – would print GRN', grnId)
  window.print()
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 4: AP INVOICES
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/**
 * List AP invoices with optional filters.
 */
export async function listInvoices(filters: InvoiceFilterOptions = {}) {
  const { company_id } = getContext()

  let query = supabase
    .from('ap_invoices')
    .select(
      `id, doc_number, supplier_inv_no, doc_date, due_date, status,
       total_amount, paid_amount, balance_due, currency,
       supplier_id, suppliers(id, name, code),
       grn_id, goods_receipts(id, doc_number),
       po_id, posted_at, created_at`,
    )
    .eq('company_id', company_id)
    .order('doc_date', { ascending: false })

  if (filters.status) query = query.eq('status', filters.status)
  if (filters.supplier_id) query = query.eq('supplier_id', filters.supplier_id)
  if (filters.from_date) query = query.gte('doc_date', filters.from_date)
  if (filters.to_date) query = query.lte('doc_date', filters.to_date)

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return data ?? []
}

/**
 * Fetch a single AP invoice with lines.
 */
export async function getInvoiceDetails(invoiceId: string) {
  const { data, error } = await supabase
    .from('ap_invoices')
    .select(
      `*, suppliers(id, name, code),
       goods_receipts(id, doc_number),
       ap_invoice_lines(
         *,
         items!ap_invoice_lines_item_id_fkey(id, name, code, purchase_uom_id),
         uom!ap_invoice_lines_uom_id_fkey(id, code, name)
       )`,
    )
    .eq('id', invoiceId)
    .single()

  if (error) throw new Error(error.message)
  return data
}

/**
 * Create an AP invoice linked to a GRN (3-way match).
 * Copies GRN lines that haven't been fully invoiced yet.
 */
export async function createInvoiceFromGRN(
  grnId: string,
  overrides: { supplier_inv_no?: string; doc_date?: string; remarks?: string } = {},
) {
  const { company_id, branch_id, user_id } = getContext()

  // Fetch GRN with lines
  const { data: grn, error: grnErr } = await supabase
    .from('goods_receipts')
    .select(
      `*, goods_receipt_lines(
         id, item_id, description, uom_id, quantity, unit_cost, invoiced_qty, po_line_id
       )`,
    )
    .eq('id', grnId)
    .single()

  if (grnErr) throw new Error(grnErr.message)
  if (grn.status !== 'posted')
    throw new Error(`GRN "${grn.doc_number}" must be posted before invoicing.`)

  const invoiceableLines = (grn.goods_receipt_lines ?? []).filter(
    (l: any) => l.quantity - (l.invoiced_qty ?? 0) > 0.0001,
  )
  if (invoiceableLines.length === 0) throw new Error('All GRN lines have already been invoiced.')

  // Generate doc number
  const { data: docNum } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'AP_INV',
  })

  const linePayloads = invoiceableLines.map((l: any, idx: number) => {
    const qty = l.quantity - (l.invoiced_qty ?? 0)
    return {
      line_number: idx + 1,
      grn_line_id: l.id,
      po_line_id: l.po_line_id || null,
      item_id: l.item_id,
      description: l.description || null,
      uom_id: l.uom_id,
      quantity: qty,
      unit_price: l.unit_cost ?? 0,
    }
  })

  const subtotal = linePayloads.reduce((s, l) => s + l.quantity * l.unit_price, 0)

  const { data: invoice, error: invErr } = await supabase
    .from('ap_invoices')
    .insert({
      company_id,
      branch_id,
      doc_number: docNum || `APINV-${Date.now()}`,
      supplier_inv_no: overrides.supplier_inv_no || null,
      doc_date: overrides.doc_date || new Date().toISOString().slice(0, 10),
      supplier_id: grn.supplier_id,
      grn_id: grnId,
      po_id: grn.po_id || null,
      status: 'draft',
      subtotal,
      total_amount: subtotal,
      remarks: overrides.remarks || null,
      created_by: user_id,
    })
    .select()
    .single()

  if (invErr) throw new Error(invErr.message)

  // Insert lines (add invoice_id to each)
  const { error: linesErr } = await supabase
    .from('ap_invoice_lines')
    .insert(linePayloads.map((l) => ({ ...l, invoice_id: invoice.id })))

  if (linesErr) throw new Error(linesErr.message)
  return invoice
}

/**
 * Create a direct AP invoice (not backed by a specific GRN).
 */
export async function createInvoice(
  header: Omit<APInvoice, 'id' | 'doc_number'>,
  lines: APInvoiceLine[],
) {
  const { company_id, branch_id, user_id } = getContext()

  if (!lines || lines.length === 0) throw new Error('At least one line item is required.')

  const { data: docNum } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'AP_INV',
  })

  const subtotal = lines.reduce(
    (s, l) => s + l.quantity * l.unit_price * (1 - (l.discount_pct || 0) / 100),
    0,
  )

  const { data: invoice, error: invErr } = await supabase
    .from('ap_invoices')
    .insert({
      company_id,
      branch_id,
      doc_number: docNum || `APINV-${Date.now()}`,
      supplier_inv_no: header.supplier_inv_no || null,
      doc_date: header.doc_date,
      due_date: header.due_date || null,
      supplier_id: header.supplier_id,
      grn_id: header.grn_id || null,
      po_id: header.po_id || null,
      currency: header.currency || 'LKR',
      exchange_rate: header.exchange_rate || 1,
      status: 'draft',
      subtotal,
      discount_amount: header.discount_amount || 0,
      tax_amount: header.tax_amount || 0,
      total_amount: subtotal + (header.tax_amount || 0) - (header.discount_amount || 0),
      remarks: header.remarks || null,
      created_by: user_id,
    })
    .select()
    .single()

  if (invErr) throw new Error(invErr.message)

  const linePayloads = lines.map((l, idx) => ({
    invoice_id: invoice.id,
    line_number: idx + 1,
    grn_line_id: l.grn_line_id || null,
    po_line_id: l.po_line_id || null,
    item_id: l.item_id || null,
    description: l.description || null,
    uom_id: l.uom_id || null,
    quantity: l.quantity,
    unit_price: l.unit_price,
    discount_pct: l.discount_pct || 0,
    tax_pct: l.tax_pct || 0,
    notes: l.notes || null,
  }))

  const { error: linesErr } = await supabase.from('ap_invoice_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  return invoice
}

/**
 * Update an existing draft AP invoice.
 */
export async function updateInvoice(
  invoiceId: string,
  header: Partial<APInvoice>,
  lines: APInvoiceLine[],
) {
  const { error: invErr } = await supabase
    .from('ap_invoices')
    .update({
      supplier_inv_no: header.supplier_inv_no,
      doc_date: header.doc_date,
      due_date: header.due_date,
      remarks: header.remarks,
      updated_at: new Date().toISOString(),
    })
    .eq('id', invoiceId)
    .eq('status', 'draft')

  if (invErr) throw new Error(invErr.message)

  // Update lines: delete and re-insert
  const { error: delErr } = await supabase
    .from('ap_invoice_lines')
    .delete()
    .eq('invoice_id', invoiceId)
  if (delErr) throw new Error(delErr.message)

  const linePayloads = lines.map((l, idx) => ({
    invoice_id: invoiceId,
    line_number: idx + 1,
    grn_line_id: l.grn_line_id || null,
    po_line_id: l.po_line_id || null,
    item_id: l.item_id || null,
    description: l.description || null,
    uom_id: l.uom_id || null,
    quantity: l.quantity,
    unit_price: l.unit_price,
    discount_pct: l.discount_pct || 0,
    tax_pct: l.tax_pct || 0,
    notes: l.notes || null,
  }))

  const { error: linesErr } = await supabase.from('ap_invoice_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  const subtotal = lines.reduce(
    (s, l) => s + l.quantity * l.unit_price * (1 - (l.discount_pct || 0) / 100),
    0,
  )
  await supabase
    .from('ap_invoices')
    .update({ subtotal, total_amount: subtotal })
    .eq('id', invoiceId)

  return { id: invoiceId }
}

/**
 * Post an AP invoice. Fires DB trigger:
 *  - Creates ap_ledger CREDIT row
 *  - Updates supplier.balance
 *  - Stamps due_date from payment_terms if not set
 */
export async function postInvoice(
  invoiceId: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('post_ap_invoice_rpc', { p_invoice_id: invoiceId })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

/**
 * Get all open (unpaid / partially paid) invoices for a supplier.
 * Used in the payment allocation dialog.
 */
export async function getOpenInvoicesForSupplier(supplierId: string) {
  const { company_id } = getContext()
  const { data, error } = await supabase
    .from('ap_invoices')
    .select('id, doc_number, doc_date, due_date, total_amount, paid_amount, balance_due')
    .eq('company_id', company_id)
    .eq('supplier_id', supplierId)
    .in('status', ['posted', 'partial_paid'])
    .order('due_date', { ascending: true })

  if (error) throw new Error(error.message)
  return data ?? []
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 5: SUPPLIER PAYMENTS
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/**
 * List supplier payments.
 */
export async function listPayments(
  filters: { status?: string; supplier_id?: string; from_date?: string; to_date?: string } = {},
) {
  const { company_id } = getContext()

  let query = supabase
    .from('supplier_payments')
    .select(
      `id, doc_number, doc_date, status, total_amount, allocated_amount, payment_method,
       supplier_id, suppliers(id, name, code),
       cheque_no, reference_no, posted_at, created_at`,
    )
    .eq('company_id', company_id)
    .order('doc_date', { ascending: false })

  if (filters.status) query = query.eq('status', filters.status)
  if (filters.supplier_id) query = query.eq('supplier_id', filters.supplier_id)
  if (filters.from_date) query = query.gte('doc_date', filters.from_date)
  if (filters.to_date) query = query.lte('doc_date', filters.to_date)

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return data ?? []
}

/**
 * Create a draft supplier payment (without allocations).
 * Call allocatePayment() afterwards to link invoices.
 */
export async function createPayment(header: Omit<SupplierPayment, 'id' | 'doc_number'>) {
  const { company_id, branch_id, user_id } = getContext()

  const { data: docNum } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'SUP_PAY',
  })

  const { data: payment, error } = await supabase
    .from('supplier_payments')
    .insert({
      company_id,
      branch_id,
      doc_number: docNum || `PAY-${Date.now()}`,
      doc_date: header.doc_date,
      supplier_id: header.supplier_id,
      payment_method: header.payment_method,
      bank_account: header.bank_account || null,
      cheque_no: header.cheque_no || null,
      cheque_date: header.cheque_date || null,
      reference_no: header.reference_no || null,
      currency: header.currency || 'LKR',
      exchange_rate: header.exchange_rate || 1,
      total_amount: header.total_amount,
      status: 'draft',
      remarks: header.remarks || null,
      created_by: user_id,
    })
    .select()
    .single()

  if (error) throw new Error(error.message)
  return payment
}

/**
 * Upsert allocations for a draft payment.
 * Deletes existing allocations for this payment, then inserts the new ones.
 * MUST be called before postPayment().
 */
export async function allocatePayment(paymentId: string, allocations: PaymentAllocation[]) {
  // Clear existing allocations
  const { error: delErr } = await supabase
    .from('supplier_payment_allocations')
    .delete()
    .eq('payment_id', paymentId)

  if (delErr) throw new Error(delErr.message)

  if (allocations.length === 0) return []

  const payload = allocations.map((a) => ({
    payment_id: paymentId,
    invoice_id: a.invoice_id,
    amount: a.amount,
  }))

  const { data, error } = await supabase
    .from('supplier_payment_allocations')
    .insert(payload)
    .select()

  if (error) throw new Error(error.message)
  return data
}

/**
 * Post a supplier payment via safe RPC.
 * Fires DB trigger:
 *  - Creates ap_ledger DEBIT row
 *  - Reduces supplier.balance
 *  - Updates invoice paid_amount and status via allocations
 */
export async function postPayment(
  paymentId: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('post_supplier_payment_rpc', {
    p_payment_id: paymentId,
  })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 6: PURCHASE RETURNS
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/**
 * List purchase returns.
 */
export async function listReturns(
  filters: { status?: string; supplier_id?: string; from_date?: string; to_date?: string } = {},
) {
  const { company_id } = getContext()

  let query = supabase
    .from('purchase_returns')
    .select(
      `id, doc_number, doc_date, status, total_amount, return_reason,
       supplier_id, suppliers(id, name, code),
       grn_id, goods_receipts(id, doc_number),
       warehouse_id, warehouses(id, name),
       posted_at, created_at`,
    )
    .eq('company_id', company_id)
    .order('doc_date', { ascending: false })

  if (filters.status) query = query.eq('status', filters.status)
  if (filters.supplier_id) query = query.eq('supplier_id', filters.supplier_id)
  if (filters.from_date) query = query.gte('doc_date', filters.from_date)
  if (filters.to_date) query = query.lte('doc_date', filters.to_date)

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return data ?? []
}

/**
 * Fetch a single Return with lines.
 */
export async function getReturnDetails(returnId: string) {
  const { data, error } = await supabase
    .from('purchase_returns')
    .select(
      `*,
       suppliers(id, name, code),
       goods_receipts(id, doc_number),
       purchase_return_lines(
         *,
         items!purchase_return_lines_item_id_fkey(id, name, code, purchase_uom_id),
         uom!purchase_return_lines_uom_id_fkey(id, code, name)
       )`,
    )
    .eq('id', returnId)
    .single()

  if (error) throw new Error(error.message)
  return data
}

/**
 * Create a Purchase Return from a posted GRN.
 * Populates lines from GRN (user can reduce qty before saving).
 */
export async function createReturnFromGRN(
  grnId: string,
  overrides: {
    doc_date?: string
    warehouse_id?: string
    return_reason?: string
    remarks?: string
  } = {},
) {
  const { company_id, branch_id, user_id } = getContext()

  // Fetch GRN with lines
  const { data: grn, error: grnErr } = await supabase
    .from('goods_receipts')
    .select(
      `*, goods_receipt_lines(
         id, item_id, description, uom_id, quantity, unit_cost, batch_no, po_line_id
       )`,
    )
    .eq('id', grnId)
    .single()

  if (grnErr) throw new Error(grnErr.message)
  if (grn.status !== 'posted') throw new Error('Only posted GRNs can be returned.')

  const warehouseId = overrides.warehouse_id || grn.warehouse_id
  if (!warehouseId) throw new Error('Warehouse required for purchase return.')

  const { data: docNum } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'PUR_RET',
  })

  const { data: ret, error: retErr } = await supabase
    .from('purchase_returns')
    .insert({
      company_id,
      branch_id,
      doc_number: docNum || `RET-${Date.now()}`,
      doc_date: overrides.doc_date || new Date().toISOString().slice(0, 10),
      grn_id: grnId,
      supplier_id: grn.supplier_id,
      warehouse_id: warehouseId,
      status: 'draft',
      return_reason: overrides.return_reason || null,
      remarks: overrides.remarks || null,
      created_by: user_id,
    })
    .select()
    .single()

  if (retErr) throw new Error(retErr.message)

  const linePayloads = (grn.goods_receipt_lines ?? []).map((l: any, idx: number) => ({
    return_id: ret.id,
    line_number: idx + 1,
    grn_line_id: l.id,
    item_id: l.item_id,
    description: l.description || null,
    uom_id: l.uom_id,
    quantity: l.quantity,
    unit_cost: l.unit_cost ?? 0,
    batch_no: l.batch_no || null,
  }))

  const { error: linesErr } = await supabase.from('purchase_return_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  const subtotal = linePayloads.reduce((s, l) => s + l.quantity * (l.unit_cost ?? 0), 0)
  await supabase
    .from('purchase_returns')
    .update({ subtotal, total_amount: subtotal })
    .eq('id', ret.id)

  return ret
}

/**
 * Create a direct purchase return (not from GRN).
 */
export async function createReturn(
  header: Omit<PurchaseReturn, 'id' | 'doc_number'>,
  lines: ReturnLine[],
) {
  const { company_id, branch_id, user_id } = getContext()

  if (!lines || lines.length === 0) throw new Error('At least one line item is required.')
  if (!header.warehouse_id) throw new Error('Warehouse is required.')

  const { data: docNum } = await supabase.rpc('generate_proc_doc_number', {
    p_company_id: company_id,
    p_branch_id: branch_id,
    p_doc_type: 'PUR_RET',
  })

  const subtotal = lines.reduce((s, l) => s + l.quantity * (l.unit_cost ?? 0), 0)

  const { data: ret, error: retErr } = await supabase
    .from('purchase_returns')
    .insert({
      company_id,
      branch_id,
      doc_number: docNum || `RET-${Date.now()}`,
      doc_date: header.doc_date,
      grn_id: header.grn_id || null,
      supplier_id: header.supplier_id,
      warehouse_id: header.warehouse_id,
      status: 'draft',
      subtotal,
      total_amount: subtotal,
      return_reason: header.return_reason || null,
      remarks: header.remarks || null,
      created_by: user_id,
    })
    .select()
    .single()

  if (retErr) throw new Error(retErr.message)

  const linePayloads = lines.map((l, idx) => ({
    return_id: ret.id,
    line_number: idx + 1,
    grn_line_id: l.grn_line_id || null,
    item_id: l.item_id,
    description: l.description || null,
    uom_id: l.uom_id,
    quantity: l.quantity,
    unit_cost: l.unit_cost ?? 0,
    batch_no: l.batch_no || null,
    return_reason: l.return_reason || null,
    notes: l.notes || null,
  }))

  const { error: linesErr } = await supabase.from('purchase_return_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  return ret
}

/**
 * Update an existing draft Purchase Return.
 */
export async function updateReturn(
  returnId: string,
  header: Partial<PurchaseReturn>,
  lines: ReturnLine[],
) {
  const { error: retErr } = await supabase
    .from('purchase_returns')
    .update({
      doc_date: header.doc_date,
      return_reason: header.return_reason,
      warehouse_id: header.warehouse_id,
      remarks: header.remarks,
      updated_at: new Date().toISOString(),
    })
    .eq('id', returnId)
    .eq('status', 'draft')

  if (retErr) throw new Error(retErr.message)

  // Update lines
  const { error: delErr } = await supabase
    .from('purchase_return_lines')
    .delete()
    .eq('return_id', returnId)
  if (delErr) throw new Error(delErr.message)

  const linePayloads = lines.map((l, idx) => ({
    return_id: returnId,
    line_number: idx + 1,
    grn_line_id: l.grn_line_id || null,
    item_id: l.item_id,
    description: l.description || null,
    uom_id: l.uom_id,
    quantity: l.quantity,
    unit_cost: l.unit_cost ?? 0,
    batch_no: l.batch_no || null,
    return_reason: l.return_reason || null,
    notes: l.notes || null,
  }))

  const { error: linesErr } = await supabase.from('purchase_return_lines').insert(linePayloads)
  if (linesErr) throw new Error(linesErr.message)

  const subtotal = lines.reduce((s, l) => s + l.quantity * (l.unit_cost ?? 0), 0)
  await supabase
    .from('purchase_returns')
    .update({ subtotal, total_amount: subtotal })
    .eq('id', returnId)

  return { id: returnId }
}

/**
 * Post a purchase return via safe RPC.
 * Fires DB trigger:
 *  - Creates inventory GIN doc (stock OUT)
 *  - Creates ap_ledger CREDIT_NOTE (reduces supplier liability)
 *  - Reduces supplier.balance
 */
export async function postReturn(
  returnId: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('post_purchase_return_rpc', { p_return_id: returnId })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 7: REFERENCE DATA
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/** Fetch all active warehouses for the current branch */
export async function listWarehouses() {
  const { branch_id, company_id } = getContext()
  const { data, error } = await supabase
    .from('warehouses')
    .select('id, code, name, warehouse_type, is_default')
    .eq('company_id', company_id)
    .eq('branch_id', branch_id)
    .eq('is_active', true)
    .order('name')

  if (error) throw new Error(error.message)
  return data ?? []
}

/** Fetch purchasable items with their default UOM */
export async function listItems() {
  const { company_id } = getContext()
  const { data, error } = await supabase
    .from('items')
    .select(
      `id, code, name, purchase_uom_id,
       uom!purchase_uom_id(id, code, name),
       last_purchase_price`,
    )
    .eq('company_id', company_id)
    .eq('is_active', true)
    .order('name')

  if (error) throw new Error(error.message)

  return (
    (data || []).map((item) => ({
      ...item,
      default_uom_id: item.purchase_uom_id,
      unit_cost: item.last_purchase_price,
    })) ?? []
  )
}

/** Fetch payment terms for a company */
export async function listPaymentTerms() {
  const { company_id } = getContext()
  const { data, error } = await supabase
    .from('payment_terms')
    .select('id, code, name, net_days, discount_pct, discount_days')
    .eq('company_id', company_id)
    .eq('is_active', true)
    .order('name')

  if (error) throw new Error(error.message)
  return data ?? []
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 8: REPORTS (read-only queries)
// ════════════════════════════════════════
// ─────────────────────────────────────────────

/**
 * Supplier Statement: AP ledger entries for a supplier in date range.
 */
export async function getSupplierStatement(supplierId: string, fromDate: string, toDate: string) {
  const { company_id } = getContext()
  const { data, error } = await supabase
    .from('ap_ledger')
    .select('id, entry_type, doc_number, doc_date, due_date, debit, credit, description, posted_at')
    .eq('company_id', company_id)
    .eq('supplier_id', supplierId)
    .gte('doc_date', fromDate)
    .lte('doc_date', toDate)
    .order('doc_date', { ascending: true })

  if (error) throw new Error(error.message)
  const rows = data ?? []
  const totalDebit = rows.reduce((s, r) => s + (r.debit || 0), 0)
  const totalCredit = rows.reduce((s, r) => s + (r.credit || 0), 0)
  return { rows, totalDebit, totalCredit, balance: totalCredit - totalDebit }
}

/**
 * AP Aging Summary: outstanding invoices bucketed into aging periods.
 */
export async function getAPAging() {
  const { company_id } = getContext()
  const today = new Date().toISOString().slice(0, 10)

  const { data, error } = await supabase
    .from('ap_invoices')
    .select(
      `id, doc_number, doc_date, due_date, total_amount, paid_amount, balance_due,
       supplier_id, suppliers(id, name)`,
    )
    .eq('company_id', company_id)
    .in('status', ['posted', 'partial_paid'])
    .order('due_date', { ascending: true })

  if (error) throw new Error(error.message)

  const rows = (data ?? []).map((inv: any) => {
    const daysOverdue = inv.due_date
      ? Math.floor((new Date(today).getTime() - new Date(inv.due_date).getTime()) / 86_400_000)
      : 0
    return {
      ...inv,
      daysOverdue,
      bucket:
        daysOverdue <= 0
          ? 'current'
          : daysOverdue <= 30
            ? '1-30'
            : daysOverdue <= 60
              ? '31-60'
              : daysOverdue <= 90
                ? '61-90'
                : '90+',
    }
  })

  return rows
}

/**
 * PO vs GRN vs Invoice Variance: compare ordered qty, received qty, invoiced qty.
 */
export async function getPOVarianceReport(
  filters: { from_date?: string; to_date?: string; supplier_id?: string } = {},
) {
  const { company_id } = getContext()
  let query = supabase
    .from('purchase_order_lines')
    .select(
      `id, quantity, unit_price, received_qty, invoiced_qty, returned_qty, open_qty,
       items(id, name, code),
       po_id, purchase_orders!inner(
         id, doc_number, doc_date, status, supplier_id,
         suppliers(id, name)
       )`,
    )
    .eq('purchase_orders.company_id', company_id)

  if (filters.from_date) query = query.gte('purchase_orders.doc_date', filters.from_date)
  if (filters.to_date) query = query.lte('purchase_orders.doc_date', filters.to_date)
  if (filters.supplier_id) query = query.eq('purchase_orders.supplier_id', filters.supplier_id)

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return data ?? []
}

// ─────────────────────────────────────────────
// ════════════════════════════════════════
// SECTION 9: PROCUREMENT SETTINGS
// ════════════════════════════════════════
// ─────────────────────────────────────────────

export interface ProcurementSetting {
  id: string
  setting_key: string
  setting_value: any
}

/**
 * Get all procurement settings for the current company.
 */
export async function getProcurementSettings(): Promise<ProcurementSetting[]> {
  const { company_id } = getContext()
  const { data, error } = await supabase
    .from('module_settings')
    .select('id, setting_key, setting_value')
    .eq('company_id', company_id)
    .eq('module_code', 'PROCUREMENT')

  if (error) throw new Error(error.message)
  return (data ?? []) as ProcurementSetting[]
}

/**
 * Upsert a single procurement setting.
 */
export async function saveProcurementSetting(key: string, value: any): Promise<void> {
  const { company_id } = getContext()
  const { error } = await supabase.from('module_settings').upsert(
    {
      company_id,
      module_code: 'PROCUREMENT',
      setting_key: key,
      setting_value: JSON.stringify(value),
    },
    { onConflict: 'company_id,module_code,setting_key' },
  )

  if (error) throw new Error(error.message)
}

/**
 * Approve a PO via RPC (only works if po_approval_required is enabled).
 */
export async function approvePORpc(
  poId: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('approve_po', { p_po_id: poId })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

/**
 * Approve a GRN via RPC (only works if grn_approval_required is enabled).
 */
export async function approveGRN(
  grnId: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('approve_grn', { p_grn_id: grnId })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

/**
 * Approve an AP Invoice via RPC (only works if invoice_approval_required is enabled).
 */
export async function approveInvoice(
  invoiceId: string,
): Promise<{ success: boolean; doc_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc('approve_ap_invoice', {
    p_invoice_id: invoiceId,
  })
  if (error) return { success: false, error: error.message }
  return data as { success: boolean; doc_number?: string; error?: string }
}

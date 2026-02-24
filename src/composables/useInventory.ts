import { ref } from 'vue'
import { supabase } from 'src/boot/supabase'

// =====================================================
// TYPE DEFINITIONS
// =====================================================

interface StockOnHandFilters {
  warehouseId?: string
  companyId?: string
  stockStatus?: string
}

interface LedgerFilters {
  warehouseId?: string
  stockItemId?: string
  documentType?: string
  dateFrom?: string
  dateTo?: string
}

interface WarehouseFilters {
  branchId?: string
  companyId?: string
  warehouseType?: string
}

// =====================================================
// STOCK ON HAND
// =====================================================

export function useStockOnHand() {
  const stockOnHand = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function fetchStockOnHand(filters: StockOnHandFilters = {}) {
    loading.value = true
    error.value = null
    try {
      let query = supabase.from('v_stock_on_hand').select('*').order('item_name')

      if (filters.warehouseId) query = query.eq('warehouse_id', filters.warehouseId)
      if (filters.companyId) query = query.eq('company_id', filters.companyId)
      if (filters.stockStatus) query = query.eq('stock_status', filters.stockStatus)

      const { data, error: err } = await query
      if (err) throw err
      stockOnHand.value = data || []
    } catch (e: any) {
      error.value = e.message
    } finally {
      loading.value = false
    }
  }

  return { stockOnHand, loading, error, fetchStockOnHand }
}

// =====================================================
// LOW STOCK ALERTS
// =====================================================

export function useLowStockAlerts() {
  const alerts = ref<any[]>([])
  const loading = ref(false)

  async function fetchAlerts(companyId: string) {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('v_low_stock_alerts')
        .select('*')
        .eq('company_id', companyId)
        .order('qty_on_hand', { ascending: true })

      if (error) throw error
      alerts.value = data || []
    } catch (e) {
      console.error('Low stock alerts error:', e)
    } finally {
      loading.value = false
    }
  }

  return { alerts, loading, fetchAlerts }
}

// =====================================================
// STOCK LEDGER (Immutable Audit Trail)
// =====================================================

export function useStockLedger() {
  const ledgerEntries = ref<any[]>([])
  const loading = ref(false)
  const totalCount = ref(0)

  async function fetchLedger(filters: LedgerFilters = {}, page = 1, pageSize = 50) {
    loading.value = true
    try {
      let query = supabase
        .from('v_recent_movements')
        .select('*', { count: 'exact' })
        .order('posted_at', { ascending: false })
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (filters.warehouseId) query = query.eq('warehouse_id', filters.warehouseId)
      if (filters.stockItemId) query = query.eq('stock_item_id', filters.stockItemId)
      if (filters.documentType) query = query.eq('document_type', filters.documentType)
      if (filters.dateFrom) query = query.gte('posted_at', filters.dateFrom)
      if (filters.dateTo) query = query.lte('posted_at', filters.dateTo)

      const { data, error, count } = await query
      if (error) throw error
      ledgerEntries.value = data || []
      totalCount.value = count || 0
    } catch (e) {
      console.error('Stock ledger error:', e)
    } finally {
      loading.value = false
    }
  }

  return { ledgerEntries, loading, totalCount, fetchLedger }
}

// =====================================================
// STOCK ITEMS (Item Master CRUD)
// =====================================================

export function useStockItems() {
  const items = ref<any[]>([])
  const loading = ref(false)

  async function fetchItems(companyId: string) {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('stock_items')
        .select('*, item_groups(name)')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('name')

      if (error) throw error
      items.value = data || []
    } catch (e) {
      console.error('Fetch stock items error:', e)
    } finally {
      loading.value = false
    }
  }

  async function createItem(item: Record<string, any>) {
    const { data, error } = await supabase.from('stock_items').insert(item).select().single()
    if (error) throw error
    return data
  }

  async function updateItem(id: string, updates: Record<string, any>) {
    const { data, error } = await supabase
      .from('stock_items')
      .update(updates)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  }

  async function deactivateItem(id: string) {
    return updateItem(id, { is_active: false })
  }

  return { items, loading, fetchItems, createItem, updateItem, deactivateItem }
}

// =====================================================
// ITEM GROUPS
// =====================================================

export function useItemGroups() {
  const groups = ref<any[]>([])
  const loading = ref(false)

  async function fetchGroups(companyId: string) {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('item_groups')
        .select('*')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('name')

      if (error) throw error
      groups.value = data || []
    } catch (e) {
      console.error('Fetch item groups error:', e)
    } finally {
      loading.value = false
    }
  }

  async function createGroup(group: Record<string, any>) {
    const { data, error } = await supabase.from('item_groups').insert(group).select().single()
    if (error) throw error
    return data
  }

  return { groups, loading, fetchGroups, createGroup }
}

// =====================================================
// WAREHOUSES
// =====================================================

export function useWarehouses() {
  const warehouses = ref<any[]>([])
  const loading = ref(false)

  async function fetchWarehouses(filters: WarehouseFilters = {}) {
    loading.value = true
    try {
      let query = supabase
        .from('warehouses')
        .select('*')
        .eq('is_active', true)
        .order('warehouse_type')
        .order('name')

      if (filters.branchId) query = query.eq('branch_id', filters.branchId)
      if (filters.companyId) query = query.eq('company_id', filters.companyId)
      if (filters.warehouseType) query = query.eq('warehouse_type', filters.warehouseType)

      const { data, error } = await query
      if (error) throw error
      warehouses.value = data || []
    } catch (e) {
      console.error('Fetch warehouses error:', e)
    } finally {
      loading.value = false
    }
  }

  async function createWarehouse(wh: Record<string, any>) {
    const { data, error } = await supabase.from('warehouses').insert(wh).select().single()
    if (error) throw error
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
    return data
  }

  return { warehouses, loading, fetchWarehouses, createWarehouse, updateWarehouse }
}

// =====================================================
// SUPPLIERS
// =====================================================

export function useSuppliers() {
  const suppliers = ref<any[]>([])
  const loading = ref(false)

  async function fetchSuppliers(companyId: string) {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('suppliers')
        .select('*')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('name')

      if (error) throw error
      suppliers.value = data || []
    } catch (e) {
      console.error('Fetch suppliers error:', e)
    } finally {
      loading.value = false
    }
  }

  async function createSupplier(supplier: Record<string, any>) {
    const { data, error } = await supabase.from('suppliers').insert(supplier).select().single()
    if (error) throw error
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
    return data
  }

  return { suppliers, loading, fetchSuppliers, createSupplier, updateSupplier }
}

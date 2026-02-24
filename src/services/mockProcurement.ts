import { uid } from 'quasar'

// --- Types (Mirroring SQL Schema) ---

export type Supplier = {
  id: string
  code: string
  name: string
  contact_person?: string
  phone?: string
  email?: string
  address?: string
  tax_id?: string
  payment_term_id?: string
  credit_limit: number
  balance: number
  is_active: boolean
}

export type PurchaseOrder = {
  id: string
  doc_number: string
  doc_date: string // YYYY-MM-DD
  expected_date?: string
  supplier_id: string
  supplier?: Supplier
  warehouse_id?: string
  status: 'draft' | 'approved' | 'open' | 'partial' | 'closed' | 'cancelled'
  currency: string
  subtotal: number
  tax_amount: number
  discount_amount: number
  total_amount: number
  remarks?: string
  lines: PurchaseOrderLine[]
}

export type PurchaseOrderLine = {
  id: string
  po_id: string
  line_number: number
  item_id: string
  item_name?: string // Joined
  uom_id: string
  uom_name?: string // Joined
  quantity: number
  unit_price: number
  line_total: number
  received_qty: number
  open_qty: number
}

export type GoodsReceipt = {
  id: string
  doc_number: string
  doc_date: string
  po_id?: string
  supplier_id: string
  warehouse_id: string
  status: 'draft' | 'posted' | 'cancelled'
  total_amount: number
  remarks?: string
  lines: GoodsReceiptLine[]
}

export type GoodsReceiptLine = {
  id: string
  grn_id: string
  line_number: number
  po_line_id?: string
  item_id: string
  uom_id: string
  quantity: number
  unit_cost: number
  line_total: number
  invoiced_qty: number
}

// --- Mock Data ---

const suppliers: Supplier[] = [
  {
    id: 's1',
    code: 'SUP-001',
    name: 'Fresh Veggies Co.',
    contact_person: 'John Doe',
    phone: '0771234567',
    email: 'sales@freshveggies.com',
    address: '123 Farm Rd, Nuwara Eliya',
    credit_limit: 100000,
    balance: 15000,
    is_active: true,
  },
  {
    id: 's2',
    code: 'SUP-002',
    name: 'Meat Masters Ltd',
    contact_person: 'Jane Smith',
    phone: '0719876543',
    email: 'orders@meatmasters.lk',
    address: '45 Industrial Zone, Colombo',
    credit_limit: 500000,
    balance: 0,
    is_active: true,
  },
]

const purchaseOrders: PurchaseOrder[] = [
  {
    id: 'po1',
    doc_number: 'PO-2025-00001',
    doc_date: '2025-02-19',
    expected_date: '2025-02-25',
    supplier_id: 's1',
    status: 'open',
    currency: 'LKR',
    subtotal: 5000,
    tax_amount: 0,
    discount_amount: 0,
    total_amount: 5000,
    lines: [
      {
        id: 'pol1',
        po_id: 'po1',
        line_number: 1,
        item_id: 'i1',
        item_name: 'Carrots',
        uom_id: 'u1',
        uom_name: 'KG',
        quantity: 50,
        unit_price: 100,
        line_total: 5000,
        received_qty: 0,
        open_qty: 50,
      },
    ],
  },
]

// --- Items Mock ---
const items = [
  { id: 'i1', name: 'Carrots', code: 'ITM-001', uom_name: 'KG', unit_price: 150 },
  { id: 'i2', name: 'Potatoes', code: 'ITM-002', uom_name: 'KG', unit_price: 120 },
  { id: 'i3', name: 'Chicken Breast', code: 'ITM-003', uom_name: 'KG', unit_price: 1200 },
  { id: 'i4', name: 'Rice (Samba)', code: 'ITM-004', uom_name: 'KG', unit_price: 220 },
]

// --- Service Methods ---

export const mockProcurement = {
  getSuppliers: async () => {
    return new Promise<Supplier[]>((resolve) => setTimeout(() => resolve([...suppliers]), 500))
  },

  getSupplier: async (id: string) => {
    return new Promise<Supplier | undefined>((resolve) =>
      setTimeout(() => resolve(suppliers.find((s) => s.id === id)), 300),
    )
  },

  createSupplier: async (data: Partial<Supplier>) => {
    const newSup = {
      ...data,
      id: uid(),
      code: `SUP-${suppliers.length + 1}`,
      balance: 0,
    } as Supplier
    suppliers.push(newSup)
    return newSup
  },

  updateSupplier: async (id: string, data: Partial<Supplier>) => {
    const idx = suppliers.findIndex((s) => s.id === id)
    if (idx > -1) {
      suppliers[idx] = { ...suppliers[idx], ...data }
      return suppliers[idx]
    }
    throw new Error('Supplier not found')
  },

  getItems: async () => {
    return new Promise<any[]>((resolve) => setTimeout(() => resolve([...items]), 300))
  },

  getPOs: async () => {
    // Populate supplier details for list view
    const enriched = purchaseOrders.map((po) => ({
      ...po,
      supplier: suppliers.find((s) => s.id === po.supplier_id),
    }))
    return new Promise<PurchaseOrder[]>((resolve) => setTimeout(() => resolve(enriched), 500))
  },

  getPO: async (id: string) => {
    const po = purchaseOrders.find((p) => p.id === id)
    if (po) {
      po.supplier = suppliers.find((s) => s.id === po.supplier_id)
    }
    return new Promise<PurchaseOrder | undefined>((resolve) => setTimeout(() => resolve(po), 300))
  },

  createPO: async (data: Partial<PurchaseOrder>) => {
    const newPO = {
      ...data,
      id: uid(),
      doc_number: `PO-2025-${(purchaseOrders.length + 1).toString().padStart(4, '0')}`,
      status: 'draft',
    } as PurchaseOrder
    purchaseOrders.push(newPO)
    return newPO
  },

  updatePO: async (id: string, data: Partial<PurchaseOrder>) => {
    const idx = purchaseOrders.findIndex((p) => p.id === id)
    if (idx > -1) {
      purchaseOrders[idx] = { ...purchaseOrders[idx], ...data }
      return purchaseOrders[idx]
    }
    throw new Error('PO not found')
  },

  // --- GRN Methods ---
  getWarehouses: async () => {
    // Mock warehouses
    return new Promise<any[]>((resolve) =>
      setTimeout(
        () =>
          resolve([
            { id: 'w1', name: 'Main Kitchen Store' },
            { id: 'w2', name: 'Bar Store' },
          ]),
        300,
      ),
    )
  },

  getGRNs: async () => {
    // Mock GRNs linked to Suppliers
    const grns: any[] = [] // Start empty or add some mocks if needed
    return new Promise<any[]>((resolve) => setTimeout(() => resolve(grns), 500))
  },

  createGRN: async (data: any) => {
    // Return a mocked created GRN
    return { ...data, id: uid(), doc_number: `GRN-2025-${Math.floor(Math.random() * 1000)}` }
  },

  updateGRN: async (id: string, data: any) => {
    return { ...data, id }
  },

  // --- Invoice Methods ---

  getInvoices: async () => {
    // Mock Invoices
    const invoices: any[] = []
    return new Promise<any[]>((resolve) => setTimeout(() => resolve(invoices), 500))
  },

  createInvoice: async (data: any) => {
    return { ...data, id: uid(), doc_number: `INV-2025-${Math.floor(Math.random() * 1000)}` }
  },

  updateInvoice: async (id: string, data: any) => {
    return { ...data, id }
  },

  // --- Payment Methods ---

  getPayments: async () => {
    // Mock Payments
    const payments: any[] = []
    return new Promise<any[]>((resolve) => setTimeout(() => resolve(payments), 500))
  },

  createPayment: async (data: any) => {
    return { ...data, id: uid(), doc_number: `PAY-2025-${Math.floor(Math.random() * 1000)}` }
  },

  updatePayment: async (id: string, data: any) => {
    return { ...data, id }
  },

  getSupplierInvoices: async (supplierId: string) => {
    // Mock fetching open invoices for supplier
    return new Promise<any[]>((resolve) =>
      setTimeout(
        () =>
          resolve([
            { id: 'inv1', doc_number: 'INV-001', doc_date: '2025-02-15', balance_due: 5000 },
            { id: 'inv2', doc_number: 'INV-002', doc_date: '2025-02-18', balance_due: 2500 },
          ]),
        300,
      ),
    )
  },

  // --- Returns Methods ---
  getReturns: async () => {
    // Mock Returns
    const returns: any[] = []
    return new Promise<any[]>((resolve) => setTimeout(() => resolve(returns), 500))
  },

  createReturn: async (data: any) => {
    return { ...data, id: uid(), doc_number: `RET-2025-${Math.floor(Math.random() * 1000)}` }
  },

  updateReturn: async (id: string, data: any) => {
    return { ...data, id }
  },
}

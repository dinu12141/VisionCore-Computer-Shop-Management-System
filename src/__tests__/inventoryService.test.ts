/**
 * Unit tests — inventoryService.ts
 * Covers: createDocument, postDocument, cancelDocument, updateItem, useStockDashboard cleanup
 *
 * Key: vi.clearAllMocks() clears call history but NOT mockReturnValueOnce queues.
 * We call fromSpy.mockReset() in every beforeEach to flush stale queued returns.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'

// ─── Shared mock spies ────────────────────────────────────────────────────────
// Module-scope so every test references the same instances via vi.mock closure.
const makeBuilder = () => ({
  select: vi.fn().mockReturnThis(),
  insert: vi.fn().mockReturnThis(),
  update: vi.fn().mockReturnThis(),
  delete: vi.fn().mockReturnThis(),
  upsert: vi.fn().mockReturnThis(),
  eq: vi.fn().mockReturnThis(),
  neq: vi.fn().mockReturnThis(),
  or: vi.fn().mockReturnThis(),
  order: vi.fn().mockReturnThis(),
  limit: vi.fn().mockReturnThis(),
  range: vi.fn().mockReturnThis(),
  contains: vi.fn().mockReturnThis(),
  ilike: vi.fn().mockReturnThis(),
  single: vi.fn().mockResolvedValue({ data: null, error: null }),
  maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
  then: vi.fn((resolve: (v: unknown) => void) => resolve({ data: [], error: null })),
})

const fromSpy = vi.fn(() => makeBuilder())
const rpcSpy = vi.fn(() => Promise.resolve({ data: null, error: null }))
const removeChannelSpy = vi.fn()

// vi.mock is hoisted before all imports — inventoryService never sees real Supabase
vi.mock('src/boot/supabase', () => ({
  supabase: {
    from: fromSpy,
    rpc: rpcSpy,
    removeChannel: removeChannelSpy,
    channel: vi.fn(() => ({ on: vi.fn().mockReturnThis(), subscribe: vi.fn().mockReturnThis() })),
    auth: {
      getSession: vi.fn(() => Promise.resolve({ data: { session: null }, error: null })),
    },
  },
  default: { boot: vi.fn() },
}))

// Plain function (not vi.fn) so vi.clearAllMocks() / vi.resetAllMocks() can't wipe it
vi.mock('src/stores/auth', () => ({
  useAuthStore: () => ({
    currentBranch: { id: 'branch-uuid-0001', company_id: 'company-uuid-0001' },
    user: { id: 'user-uuid-0001' },
    profile: { company_id: 'company-uuid-0001' },
  }),
}))

// ─── Helpers ─────────────────────────────────────────────────────────────────
/** Reset fromSpy and restore a safe default implementation before each test. */
function resetFrom() {
  fromSpy.mockReset()                           // clears history + queued once-values
  fromSpy.mockImplementation(() => makeBuilder()) // safe default for un-mocked calls
}

// ─── createDocument ───────────────────────────────────────────────────────────
describe('createDocument', () => {
  beforeEach(resetFrom)

  it('throws when no company context', async () => {
    const authMod = await import('src/stores/auth')
    const backup = authMod.useAuthStore
    ;(authMod as { useAuthStore: () => unknown }).useAuthStore = () => ({
      currentBranch: null, user: null, profile: null,
    })
    const { createDocument } = await import('src/services/inventoryService')
    await expect(
      createDocument({ doc_type: 'GRN', warehouse_id: 'wh-1' }, []),
    ).rejects.toThrow('No company/branch context.')
    ;(authMod as { useAuthStore: () => unknown }).useAuthStore = backup
  })

  it('calls generate_inv_doc_number RPC with the company_id', async () => {
    rpcSpy.mockResolvedValueOnce({ data: 'GRN-2026-00001', error: null })

    const headerBuilder = makeBuilder()
    headerBuilder.single = vi.fn().mockResolvedValue({
      data: { id: 'doc-uuid-0001', doc_number: 'GRN-2026-00001' },
      error: null,
    })
    fromSpy
      .mockReturnValueOnce(headerBuilder as never)                           // inventory_documents insert
      .mockReturnValueOnce({ insert: vi.fn().mockResolvedValue({ error: null }) } as never) // lines insert

    const { createDocument } = await import('src/services/inventoryService')
    await createDocument({ doc_type: 'GRN', warehouse_id: 'wh-1' }, [])

    expect(rpcSpy).toHaveBeenCalledWith('generate_inv_doc_number', {
      p_company_id: 'company-uuid-0001',
      p_doc_type: 'GRN',
    })
  })
})

// ─── postDocument ─────────────────────────────────────────────────────────────
describe('postDocument', () => {
  beforeEach(resetFrom)

  it('updates status to posted', async () => {
    const b = makeBuilder()
    b.single = vi.fn().mockResolvedValue({ data: { id: 'doc-uuid-0001', status: 'posted' }, error: null })
    fromSpy.mockReturnValueOnce(b as never)

    const { postDocument } = await import('src/services/inventoryService')
    const result = await postDocument('doc-uuid-0001')
    expect(result.status).toBe('posted')
    expect(b.update).toHaveBeenCalledWith({ status: 'posted' })
  })

  it('throws when Supabase returns an error', async () => {
    const b = makeBuilder()
    b.single = vi.fn().mockResolvedValue({ data: null, error: { message: 'INSUFFICIENT_STOCK' } })
    fromSpy.mockReturnValueOnce(b as never)

    const { postDocument } = await import('src/services/inventoryService')
    await expect(postDocument('doc-uuid-0001')).rejects.toMatchObject({ message: 'INSUFFICIENT_STOCK' })
  })
})

// ─── cancelDocument ───────────────────────────────────────────────────────────
describe('cancelDocument', () => {
  beforeEach(resetFrom)

  it('updates status to cancelled', async () => {
    const b = makeBuilder()
    b.single = vi.fn().mockResolvedValue({
      data: { id: 'doc-uuid-0001', status: 'cancelled', cancelled_at: new Date().toISOString() },
      error: null,
    })
    fromSpy.mockReturnValueOnce(b as never)

    const { cancelDocument } = await import('src/services/inventoryService')
    const result = await cancelDocument('doc-uuid-0001')
    expect(result.status).toBe('cancelled')
    expect(b.update).toHaveBeenCalledWith({ status: 'cancelled' })
  })
})

// ─── updateItem ───────────────────────────────────────────────────────────────
describe('updateItem', () => {
  beforeEach(resetFrom)

  it('never sends serials column to the database', async () => {
    const b = makeBuilder()
    b.single = vi.fn().mockResolvedValue({ data: { id: 'item-uuid-0001', name: 'RAM 16GB' }, error: null })
    fromSpy.mockReturnValueOnce(b as never)

    const { useItemsList } = await import('src/services/inventoryService')
    const { updateItem } = useItemsList()
    await updateItem('item-uuid-0001', { name: 'RAM 16GB', serials: ['SN-001'] })

    const payload = (b.update as ReturnType<typeof vi.fn>).mock.calls[0]?.[0]
    expect(payload).toBeDefined()
    expect(payload).not.toHaveProperty('serials')
    expect(payload).toHaveProperty('name', 'RAM 16GB')
  })

  it('never sends qty_on_hand or stock_on_hand to the database', async () => {
    const b = makeBuilder()
    b.single = vi.fn().mockResolvedValue({ data: { id: 'item-uuid-0001' }, error: null })
    fromSpy.mockReturnValueOnce(b as never)

    const { useItemsList } = await import('src/services/inventoryService')
    const { updateItem } = useItemsList()
    await updateItem('item-uuid-0001', { name: 'SSD', qty_on_hand: 99, stock_on_hand: 99 })

    const payload = (b.update as ReturnType<typeof vi.fn>).mock.calls[0]?.[0]
    expect(payload).toBeDefined()
    expect(payload).not.toHaveProperty('qty_on_hand')
    expect(payload).not.toHaveProperty('stock_on_hand')
  })
})

// ─── useStockDashboard cleanup ────────────────────────────────────────────────
describe('useStockDashboard — cleanup', () => {
  beforeEach(resetFrom)

  it('exposes a cleanup function', async () => {
    const { useStockDashboard } = await import('src/services/inventoryService')
    const { cleanup } = useStockDashboard()
    expect(typeof cleanup).toBe('function')
  })

  it('cleanup does not throw before any subscription is opened', async () => {
    const { useStockDashboard } = await import('src/services/inventoryService')
    const { cleanup } = useStockDashboard()
    expect(() => cleanup()).not.toThrow()
  })
})

// ─── Multi-tenancy ────────────────────────────────────────────────────────────
describe('multi-tenancy — company_id always in queries', () => {
  beforeEach(resetFrom)

  it('listDocuments queries inventory_documents table with company_id filter', async () => {
    const calledTables: string[] = []
    const calledEqCols: string[] = []

    fromSpy.mockImplementation((table: string) => {
      calledTables.push(table)
      const b = makeBuilder()
      const origEq = b.eq
      b.eq = vi.fn((col: string, ...rest: unknown[]) => {
        calledEqCols.push(col)
        return origEq.call(b, col, ...rest)
      })
      b.limit = vi.fn().mockResolvedValue({ data: [], error: null })
      return b as never
    })

    const { useDocumentList } = await import('src/services/inventoryService')
    const { listDocuments } = useDocumentList()
    await listDocuments()

    expect(calledTables).toContain('inventory_documents')
    expect(calledEqCols).toContain('company_id')
  })

  it('fetchStockOnHand queries v_stock_on_hand with company_id filter', async () => {
    const calledTables: string[] = []
    const calledEqCols: string[] = []

    fromSpy.mockImplementation((table: string) => {
      calledTables.push(table)
      const b = makeBuilder()
      const origEq = b.eq
      b.eq = vi.fn((col: string, ...rest: unknown[]) => {
        calledEqCols.push(col)
        return origEq.call(b, col, ...rest)
      })
      b.then = vi.fn((resolve: (v: unknown) => void) =>
        resolve({ data: [], error: null, count: 0 }),
      )
      return b as never
    })

    const { useStockDashboard } = await import('src/services/inventoryService')
    const { fetchStockOnHand } = useStockDashboard()
    await fetchStockOnHand()

    expect(calledTables).toContain('v_stock_on_hand')
    expect(calledEqCols).toContain('company_id')
  })
})

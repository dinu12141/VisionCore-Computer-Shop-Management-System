/**
 * Supabase client mock for unit tests.
 * Returns a chainable builder that resolves to { data: null, error: null }
 * unless overridden with mockResolvedValueOnce in individual tests.
 */
import { vi } from 'vitest'

function makeBuilder(override?: { data?: unknown; error?: unknown; count?: number }) {
  const result = override ?? { data: null, error: null }
  const builder: Record<string, unknown> = {}
  const chainMethods = [
    'select', 'insert', 'update', 'delete', 'upsert',
    'eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'is', 'in',
    'not', 'or', 'and', 'filter', 'match',
    'order', 'limit', 'range', 'single', 'maybeSingle',
    'contains', 'ilike', 'like', 'textSearch',
  ]
  chainMethods.forEach((m) => {
    builder[m] = vi.fn(() => builder)
  })
  // Thenable — await resolves with the result
  builder.then = vi.fn((resolve: (v: unknown) => void) => resolve(result))
  return builder
}

export const supabaseMock = {
  from: vi.fn(() => makeBuilder()),
  rpc: vi.fn(() => Promise.resolve({ data: null, error: null })),
  auth: {
    getSession: vi.fn(() => Promise.resolve({ data: { session: null }, error: null })),
    signInWithPassword: vi.fn(),
    signOut: vi.fn(() => Promise.resolve({ error: null })),
    onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
  },
  channel: vi.fn(() => ({
    on: vi.fn().mockReturnThis(),
    subscribe: vi.fn().mockReturnThis(),
    unsubscribe: vi.fn(),
  })),
  removeChannel: vi.fn(),
}

export const supabase = supabaseMock

export default { boot: vi.fn() }

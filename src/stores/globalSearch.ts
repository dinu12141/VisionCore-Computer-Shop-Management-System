/**
 * ╔═══════════════════════════════════════════════╗
 * ║  VisionCore ERP — Global Search Store         ║
 * ║  Pinia store for unified ERP search           ║
 * ╚═══════════════════════════════════════════════╝
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from './auth'

export interface SearchResult {
  entity_type: 'customer' | 'invoice' | 'item' | 'supplier' | 'payment' | 'service_job'
  entity_id: string
  title: string
  subtitle: string
  extra: Record<string, unknown>
  score: number
}

// Entity display config — icons, colors, route templates
export const ENTITY_CONFIG = {
  customer: {
    icon: 'people_alt',
    color: 'orange-7',
    bgColor: 'orange-1',
    label: 'Customers',
    route: (id: string) => `/customers`,
  },
  invoice: {
    icon: 'receipt_long',
    color: 'blue-7',
    bgColor: 'blue-1',
    label: 'Invoices',
    route: (id: string) => `/billing/history`,
  },
  item: {
    icon: 'inventory_2',
    color: 'green-7',
    bgColor: 'green-1',
    label: 'Items',
    route: (id: string) => `/inventory`,
  },
  supplier: {
    icon: 'local_shipping',
    color: 'purple-7',
    bgColor: 'purple-1',
    label: 'Suppliers',
    route: (id: string) => `/inventory`,
  },
  payment: {
    icon: 'payments',
    color: 'teal-7',
    bgColor: 'teal-1',
    label: 'Payments',
    route: (id: string) => `/collections/outstanding`,
  },
  service_job: {
    icon: 'build',
    color: 'deep-purple-7',
    bgColor: 'deep-purple-1',
    label: 'Service Jobs',
    route: (id: string) => `/services/jobs/${id}`,
  },
} as const

export const useGlobalSearchStore = defineStore('globalSearch', () => {
  const query = ref('')
  const loading = ref(false)
  const results = ref<SearchResult[]>([])
  const selectedIndex = ref(-1)
  const recentSearches = ref<string[]>(loadRecentSearches())
  const searchTime = ref(0)

  const authStore = useAuthStore()

  // ── Grouped results ──────────────────────────────────────
  const groupedResults = computed(() => {
    const groups: Record<string, SearchResult[]> = {}
    // Maintain display order
    const order = ['customer', 'invoice', 'item', 'supplier', 'payment', 'service_job']
    for (const type of order) {
      const items = results.value.filter((r) => r.entity_type === type)
      if (items.length > 0) groups[type] = items
    }
    return groups
  })

  const totalResults = computed(() => results.value.length)

  // ── Perform Search ───────────────────────────────────────────
  async function performSearch(val: string, limit = 12) {
    const trimmed = val?.trim()
    if (!trimmed || trimmed.length < 2) {
      results.value = []
      loading.value = false
      return
    }

    loading.value = true
    const start = performance.now()

    try {
      const companyId =
        authStore.currentBranch?.company_id ||
        authStore.user?.user_metadata?.company_id ||
        authStore.profile?.company_id

      if (!companyId) {
        console.warn('[GlobalSearch] No company ID found.')
        loading.value = false
        return
      }

      // ── Try RPC first ──────────────────────────────────────
      const { data, error } = await supabase.rpc('global_search', {
        p_company_id: companyId,
        q: trimmed,
        p_limit: limit,
      })

      if (error) {
        console.warn('[GlobalSearch] RPC failed, using fallback search:', error.message)
        // ── Fallback: direct table queries ─────────────────
        await fallbackSearch(companyId, trimmed, limit)
      } else {
        results.value = (data || []) as SearchResult[]
        selectedIndex.value = -1
        searchTime.value = Math.round(performance.now() - start)
        addRecentSearch(trimmed)
      }
    } catch (err) {
      console.error('[GlobalSearch] Unexpected error:', err)
      results.value = []
    } finally {
      loading.value = false
      searchTime.value = Math.round(performance.now() - start)
    }
  }

  // ── Fallback direct-query search (when RPC not available) ─────────────────
  async function fallbackSearch(companyId: string, q: string, limit: number) {
    const pat = `%${q}%`
    const out: SearchResult[] = []

    // Customers
    const { data: custs } = await supabase
      .from('customers')
      .select('id, name, phone, customer_code')
      .eq('company_id', companyId)
      .or(`name.ilike.${pat},phone.ilike.${pat},customer_code.ilike.${pat}`)
      .limit(limit)
    ;(custs || []).forEach((c) =>
      out.push({
        entity_type: 'customer',
        entity_id: c.id,
        title: c.name,
        subtitle: `Phone: ${c.phone || 'N/A'}`,
        extra: { phone: c.phone, code: c.customer_code },
        score: 80,
      }),
    )

    // Invoices (Search by invoice_no or serial number sold)
    // First, find invoice IDs matching serial numbers sold
    const { data: soldSerialHits } = await supabase
      .from('invoice_items')
      .select('invoice_id, serial_number, description')
      .ilike('serial_number', pat)
      .limit(10)

    const soldInvoiceIds = (soldSerialHits || []).map((s) => s.invoice_id)

    // Now search invoices table
    let invQuery = supabase
      .from('invoices')
      .select('id, invoice_no, total, payment_status, customer_snapshot, customer_po_no')
      .eq('company_id', companyId)

    if (soldInvoiceIds.length > 0) {
      invQuery = invQuery.or(`invoice_no.ilike.${pat},customer_po_no.ilike.${pat},id.in.(${soldInvoiceIds.join(',')})`)
    } else {
      invQuery = invQuery.or(`invoice_no.ilike.${pat},customer_po_no.ilike.${pat}`)
    }

    const { data: invs } = await invQuery.limit(limit)
    ;(invs || []).forEach((i) => {
      const matchedSN = soldSerialHits?.find((sh) => sh.invoice_id === i.id)?.serial_number
      out.push({
        entity_type: 'invoice',
        entity_id: i.id,
        title: i.invoice_no,
        subtitle: matchedSN
          ? `Contains SN: ${matchedSN} | Total: LKR ${i.total}`
          : `Customer: ${i.customer_snapshot?.name || 'Walk-in'} | ${i.payment_status} | LKR ${i.total}${i.customer_po_no ? ' | PO: ' + i.customer_po_no : ''}`,
        extra: {
          status: i.payment_status,
          total: i.total,
          customer: i.customer_snapshot?.name,
          matched_sn: matchedSN,
        },
        score: matchedSN ? 90 : 75,
      })
    })

    // Items (Search by name, code, or serial number stored in items.serials JSONB array)
    // NOTE: PostgreSQL cannot index inside a JSONB text array with ilike via PostgREST directly.
    // We fetch items matching name/code first, then do a separate query for SN matches
    // using the @> (contains) operator via a raw filter on the serials JSONB column.
    // This is safe — items.serials is JSONB array of strings, not a separate table.

    // Step A: items matching name or code
    const { data: nameCodeItems } = await supabase
      .from('items')
      .select('id, name, code, serials')
      .eq('company_id', companyId)
      .or(`name.ilike.${pat},code.ilike.${pat}`)
      .limit(limit)

    // Step B: items where any serial in the serials JSONB array matches the query
    // PostgREST cs (contains) only works for exact subset match, so we use
    // a text-search approach: filter where serials::text ilike the pattern
    const { data: serialMatchItems } = await supabase
      .from('items')
      .select('id, name, code, serials')
      .eq('company_id', companyId)
      .ilike('serials::text', pat)
      .limit(10)

    // Merge both result sets (dedupe by id)
    const allItemMap = new Map<string, NonNullable<typeof nameCodeItems>[number]>()
    for (const i of nameCodeItems || []) allItemMap.set(i.id, i)
    for (const i of serialMatchItems || []) if (!allItemMap.has(i.id)) allItemMap.set(i.id, i)

    const trimmedQ = q.toLowerCase()
    for (const i of allItemMap.values()) {
      // Check if the query matches a specific serial in this item's serials array
      const matchedSN = Array.isArray(i.serials)
        ? (i.serials as string[]).find((sn) => String(sn).toLowerCase().includes(trimmedQ))
        : undefined
      out.push({
        entity_type: 'item',
        entity_id: i.id,
        title: i.name,
        subtitle: matchedSN
          ? `In Stock SN: ${matchedSN} | Code: ${i.code || 'N/A'}`
          : `Code: ${i.code || 'N/A'}`,
        extra: { code: i.code, matched_sn: matchedSN },
        score: matchedSN ? 95 : 70,
      })
    }

    // Service Jobs
    const { data: jobs } = await supabase
      .from('service_jobs')
      .select('id, job_no, status, device_type, brand, serial_no')
      .eq('company_id', companyId)
      .or(`job_no.ilike.${pat},device_type.ilike.${pat},brand.ilike.${pat},serial_no.ilike.${pat}`)
      .limit(limit)
    ;(jobs || []).forEach((j: any) =>
      out.push({
        entity_type: 'service_job',
        entity_id: j.id,
        title: j.job_no,
        subtitle:
          `${j.device_type || ''} ${j.brand || ''} | ${j.status || ''} ${j.serial_no ? '| SN: ' + j.serial_no : ''}`.trim(),
        extra: { status: j.status, device: j.device_type, sn: j.serial_no },
        score: 65,
      }),
    )

    results.value = out.sort((a, b) => b.score - a.score).slice(0, limit)
    selectedIndex.value = -1
    addRecentSearch(q)
  }

  // ── Clear ────────────────────────────────────────────────
  function clearSearch() {
    query.value = ''
    results.value = []
    selectedIndex.value = -1
    loading.value = false
    searchTime.value = 0
  }

  // ── Recent Searches ──────────────────────────────────────
  function addRecentSearch(term: string) {
    const lower = term.toLowerCase()
    recentSearches.value = [lower, ...recentSearches.value.filter((s) => s !== lower)].slice(0, 5)
    try {
      localStorage.setItem('erp_recent_searches', JSON.stringify(recentSearches.value))
    } catch {
      /* ignore */
    }
  }

  function clearRecentSearches() {
    recentSearches.value = []
    localStorage.removeItem('erp_recent_searches')
  }

  return {
    query,
    loading,
    results,
    selectedIndex,
    recentSearches,
    searchTime,
    groupedResults,
    totalResults,
    performSearch,
    clearSearch,
    clearRecentSearches,
  }
})

function loadRecentSearches(): string[] {
  try {
    return JSON.parse(localStorage.getItem('erp_recent_searches') || '[]')
  } catch {
    return []
  }
}

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
  entity_type: 'customer' | 'invoice' | 'item' | 'supplier' | 'payment'
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
    const order = ['customer', 'invoice', 'item', 'supplier', 'payment']
    for (const type of order) {
      const items = results.value.filter((r) => r.entity_type === type)
      if (items.length > 0) groups[type] = items
    }
    return groups
  })

  const totalResults = computed(() => results.value.length)

  // ── Perform Search ───────────────────────────────────────
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
        console.warn('Global Search: No company ID found.')
        return
      }

      const { data, error } = await supabase.rpc('global_search', {
        p_company_id: companyId,
        p_query: trimmed,
        p_limit: limit,
      })

      if (error) throw error

      results.value = (data || []) as SearchResult[]
      selectedIndex.value = -1
      searchTime.value = Math.round(performance.now() - start)

      // Save to recent searches
      addRecentSearch(trimmed)
    } catch (err) {
      console.error('Global search error:', err)
      results.value = []
    } finally {
      loading.value = false
    }
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

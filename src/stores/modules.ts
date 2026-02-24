import { defineStore } from 'pinia'
import { supabase } from 'src/boot/supabase'

export interface SystemModule {
  id: string
  company_id: string
  code: string
  name: string
  description: string | null
  is_enabled: boolean
  icon: string
  sort_order: number
}

interface ModulesState {
  modules: SystemModule[]
  loading: boolean
  loaded: boolean
}

export const useModulesStore = defineStore('modules', {
  state: (): ModulesState => ({
    modules: [],
    loading: false,
    loaded: false,
  }),

  actions: {
    async fetchModules(companyId?: string) {
      if (this.loading) return
      this.loading = true
      try {
        let query = supabase
          .from('system_modules')
          .select('*')
          .order('sort_order', { ascending: true })

        if (companyId) {
          query = query.eq('company_id', companyId)
        }

        const { data, error } = await query

        if (error) throw error
        this.modules = (data || []) as SystemModule[]
        this.loaded = true
      } catch (err) {
        console.error('[Modules] Fetch error:', err)
      } finally {
        this.loading = false
      }
    },

    async toggleModule(moduleId: string, enabled: boolean) {
      const { error } = await supabase
        .from('system_modules')
        .update({ is_enabled: enabled })
        .eq('id', moduleId)

      if (error) throw error

      // Update local state
      const mod = this.modules.find((m) => m.id === moduleId)
      if (mod) mod.is_enabled = enabled
    },

    async batchUpdate(updates: { id: string; is_enabled: boolean }[]) {
      // Update each module — Supabase doesn't support bulk upsert with different values easily
      const promises = updates.map((u) =>
        supabase.from('system_modules').update({ is_enabled: u.is_enabled }).eq('id', u.id),
      )

      const results = await Promise.all(promises)
      const failed = results.filter((r) => r.error)
      if (failed.length > 0) {
        throw new Error(`Failed to update ${failed.length} module(s)`)
      }

      // Update local state
      for (const u of updates) {
        const mod = this.modules.find((m) => m.id === u.id)
        if (mod) mod.is_enabled = u.is_enabled
      }
    },

    clear() {
      this.modules = []
      this.loaded = false
    },
  },

  getters: {
    isModuleEnabled:
      (state) =>
      (code: string): boolean => {
        const mod = state.modules.find((m) => m.code === code)
        // If module not loaded or not found, treat as enabled (permissive default)
        if (!mod) return true
        return mod.is_enabled
      },

    enabledModules: (state) => state.modules.filter((m) => m.is_enabled),

    getModule:
      (state) =>
      (code: string): SystemModule | undefined => {
        return state.modules.find((m) => m.code === code)
      },
  },
})

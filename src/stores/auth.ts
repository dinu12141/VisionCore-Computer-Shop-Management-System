import { defineStore } from 'pinia'
import { supabase } from 'src/boot/supabase'
import { Session, User } from '@supabase/supabase-js'
import { ROLE_LANDING, canAccessRoute } from 'src/config/roles'

export type UserRole =
  | 'admin'
  | 'user'
  | 'manager'
  | 'inventory'
  | 'finance'
  | 'hr'
  | 'cashier'
  | 'waiter'
  | 'kitchen'

interface AuthState {
  user: User | null
  session: Session | null
  roles: UserRole[]
  profile: any | null
  branches: any[]
  loading: boolean
  error: string | null
  initialized: boolean
  _fetchingUserData: boolean
  // Dynamic route access loaded from DB (role_route_access table)
  // Map: roleName → string[] of allowed route prefixes
  dynamicRouteAccess: Record<string, string[]>
  // Per-user route overrides from user_route_access table
  // string[] of enabled route paths for this specific user
  userRouteAccess: string[] | null // null = not loaded yet; [] = no overrides
}

export const useAuthStore = defineStore('auth', {
  state: (): AuthState => ({
    user: null,
    session: null,
    roles: [],
    profile: null,
    branches: [],
    loading: false,
    error: null,
    initialized: false,
    _fetchingUserData: false,
    dynamicRouteAccess: {},
    userRouteAccess: null,
  }),
  actions: {
    async initialize() {
      if (this.initialized) return

      try {
        supabase.auth.onAuthStateChange((event, session) => {
          this.session = session
          this.user = session?.user || null

          if (event === 'SIGNED_OUT') {
            this._clearUserData()
          }
          if ((event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') && session) {
            this._backgroundFetchUserData()
          }
        })

        const {
          data: { session },
        } = await supabase.auth.getSession()

        if (session) {
          this.session = session
          this.user = session.user
          // Fetch user data in background - don't block app initialization
          this._backgroundFetchUserData()
        }
      } catch (err) {
        console.error('[Auth] Init error:', err)
      } finally {
        this.initialized = true
      }
    },

    async fetchUserData() {
      if (!this.user || this._fetchingUserData) return
      this._fetchingUserData = true
      try {
        // All queries run in parallel — fastest possible
        await Promise.all([
          this._fetchRoles(),
          this._fetchProfile(),
          this._fetchBranches(),
          this._fetchUserRouteAccess(),
        ])
      } finally {
        this._fetchingUserData = false
      }
    },

    /** Background fetch — doesn't block anything */
    _backgroundFetchUserData() {
      if (!this.user) return
      // Fire and forget — no await
      Promise.all([
        this._fetchRoles(),
        this._fetchProfile(),
        this._fetchBranches(),
        this._fetchUserRouteAccess(),
      ]).catch((err) => console.error('[Auth] Background fetch error:', err))
    },

    async _fetchRoles() {
      try {
        const { data, error } = await supabase.rpc('auth_get_roles')
        if (error) throw error
        this.roles = (data || []) as UserRole[]
      } catch (err) {
        console.warn('[Auth] RPC auth_get_roles failed, using fallback:', err)
        try {
          const { data, error } = await supabase
            .from('user_roles')
            .select('role:roles(name)')
            .eq('user_id', this.user?.id)

          if (error) throw error

          this.roles = (data?.map((r: any) => r.role?.name).filter(Boolean) || []) as UserRole[]
        } catch (fallbackErr) {
          console.error('[Auth] Fallback role fetch failed:', fallbackErr)
          this.roles = []
        }
      }

      // Load dynamic route access from DB for this user's roles
      await this._fetchDynamicRouteAccess()
    },

    async _fetchDynamicRouteAccess() {
      if (this.roles.length === 0) return
      try {
        const { data, error } = await supabase
          .from('role_route_access')
          .select('route_path, roles!inner(name)')
          .in('roles.name', this.roles)

        if (error) throw error

        // Build map: roleName → route paths
        const map: Record<string, string[]> = {}
        for (const row of data || []) {
          const roleName = (row as any).roles?.name
          if (!roleName) continue
          if (!map[roleName]) map[roleName] = []
          map[roleName].push((row as any).route_path)
        }
        this.dynamicRouteAccess = map
      } catch (err) {
        console.warn('[Auth] Dynamic route access fetch failed, using hardcoded fallback:', err)
        this.dynamicRouteAccess = {}
      }
    },

    /** Load per-user route access overrides from user_route_access table */
    async _fetchUserRouteAccess() {
      if (!this.user) return
      try {
        const { data, error } = await supabase
          .from('user_route_access')
          .select('route_path, enabled')
          .eq('user_id', this.user.id)
          .eq('enabled', true)

        if (error) throw error

        // null means "no overrides configured → fall back to role access"
        if (!data || data.length === 0) {
          this.userRouteAccess = null
        } else {
          this.userRouteAccess = data.map((r: any) => r.route_path)
        }
      } catch (err) {
        console.warn('[Auth] User route access fetch failed:', err)
        this.userRouteAccess = null
      }
    },

    async _fetchProfile() {
      try {
        const { data } = await supabase
          .from('profiles')
          .select('full_name, email, phone, avatar_url')
          .eq('id', this.user?.id)
          .single()
        this.profile = data
      } catch {
        /* non-critical */
      }
    },

    async _fetchBranches() {
      try {
        const { data } = await supabase
          .from('user_branches')
          .select('is_home_branch, branches(id, name, company_id, is_main, is_active)')
          .eq('user_id', this.user?.id)
        this.branches = data || []
      } catch {
        /* non-critical */
      }
    },

    /**
     * FAST Sign In:
     * 1. Call Supabase signIn
     * 2. Set user + session immediately
     * 3. Fetch roles (critical for routing) — profile & branches in background
     * 4. Return ASAP so the UI can navigate
     */
    async signIn(email: string, password: string): Promise<{ data: any; error: any }> {
      this.loading = true
      this.error = null
      try {
        // Step 1: Fast Auth
        const { data, error } = await supabase.auth.signInWithPassword({ email, password })

        if (error) {
          let msg = error.message
          if (msg.includes('Invalid login credentials')) msg = 'Invalid email or password'
          else if (msg.includes('Email not confirmed')) msg = 'Please verify your email first'
          else if (msg.includes('Too many requests')) msg = 'Too many attempts. Try later'
          this.error = msg
          return { data: null, error: { message: msg } }
        }

        // Step 2: Set basic state immediately
        this.user = data.user
        this.session = data.session

        // Step 3: Trigger background data fetch but DON'T await it
        // This makes the UI feel instant as we return control immediately
        this.fetchUserData().catch(() => {})

        return { data, error: null }
      } catch (err: any) {
        this.error = err.message || 'An unexpected error occurred'
        return { data: null, error: err }
      } finally {
        this.loading = false
      }
    },

    /** Fetch profile + branches + modules without blocking */
    _backgroundFetchNonCritical() {
      Promise.all([this._fetchProfile(), this._fetchBranches()]).catch(() => {})
      // Load system modules in background (non-blocking, separate promise)
      import('src/stores/modules').then(({ useModulesStore }) => {
        const modulesStore = useModulesStore()
        const companyId = this.branches?.[0]?.branches?.company_id
        modulesStore.fetchModules(companyId).catch(() => {})
      })
    },

    /**
     * FAST Sign Out:
     * 1. Clear local state IMMEDIATELY (instant UI update)
     * 2. Call Supabase signOut in background (don't wait for it)
     */
    async signOut() {
      // Clear local state FIRST — instant logout feel
      this._clearUserData()

      // Fire Supabase signOut in background — don't block the UI
      supabase.auth.signOut().catch((err) => {
        console.error('Background signOut error:', err)
      })
    },

    /**
     * Server-verified role check using auth_has_role RPC.
     */
    async authHasRole(roleName: string): Promise<boolean> {
      try {
        const { data, error } = await supabase.rpc('auth_has_role', { role_name: roleName })
        if (error) throw error
        return !!data
      } catch {
        return this.roles.includes(roleName as UserRole)
      }
    },

    _clearUserData() {
      this.user = null
      this.session = null
      this.roles = []
      this.profile = null
      this.branches = []
      this.userRouteAccess = null
      this.dynamicRouteAccess = {}
    },
  },
  getters: {
    isAuthenticated: (state) => !!state.user,
    isAdmin: (state) => state.roles.includes('admin'),
    userDisplayName: (state) => state.profile?.full_name || state.user?.email || '',
    currentBranch: (state) => {
      const home = state.branches.find((b) => b.is_home_branch)
      return home?.branches || state.branches[0]?.branches || null
    },
    hasRole: (state) => {
      return (role: UserRole) => state.roles.includes(role)
    },
    hasAnyRole: (state) => {
      return (roles: UserRole[]) => roles.some((role) => state.roles.includes(role))
    },
    canAccess: (state) => {
      return (routePath: string) => {
        // Admin always has full access
        if (state.roles.includes('admin')) return true

        // 1st priority: per-user overrides from user_route_access table
        // If userRouteAccess is set (not null), use ONLY those routes
        if (state.userRouteAccess !== null) {
          return state.userRouteAccess.some((p) => routePath.startsWith(p))
        }

        // 2nd priority: role-based DB routes from role_route_access table
        if (Object.keys(state.dynamicRouteAccess).length > 0) {
          return state.roles.some((role) => {
            const allowedPaths = state.dynamicRouteAccess[role]
            if (!allowedPaths) return false
            if (allowedPaths.includes('*')) return true
            return allowedPaths.some((p) => routePath.startsWith(p))
          })
        }

        // 3rd priority: hardcoded config fallback
        return canAccessRoute(state.roles, routePath)
      }
    },
    defaultLandingPage: (state) => {
      // Check in priority order — highest privilege role wins the landing page
      const priority: UserRole[] = [
        'admin',
        'manager',
        'finance',
        'inventory',
        'cashier',
        'waiter',
        'kitchen',
        'hr',
      ]
      for (const role of priority) {
        if (state.roles.includes(role)) {
          return ROLE_LANDING[role] || '/dashboard'
        }
      }
      return '/dashboard'
    },
  },
})

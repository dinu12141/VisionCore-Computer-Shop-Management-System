import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useAuthStore } from 'src/stores/auth'
import { getRoleRestrictions, canAccessRoute, getFilteredNavItems } from 'src/config/roles'

export function useAuth() {
  const authStore = useAuthStore()
  const { user, session, roles, error, loading } = storeToRefs(authStore)

  /** Computed RBAC page-level restrictions */
  const restrictions = computed(() => getRoleRestrictions(authStore.roles))

  /** Computed filtered navigation items */
  const navItems = computed(() => getFilteredNavItems(authStore.roles))

  return {
    // State
    user,
    session,
    roles,
    error,
    loading,

    // Restrictions
    restrictions,
    navItems,

    // Actions
    login: authStore.signIn,
    logout: authStore.signOut,
    getCurrentUser: () => authStore.user,
    hasRole: authStore.hasRole,
    hasAnyRole: authStore.hasAnyRole,
    canAccess: (routePath: string) => canAccessRoute(authStore.roles, routePath),
    authHasRole: authStore.authHasRole, // Server-verified check via RPC
  }
}

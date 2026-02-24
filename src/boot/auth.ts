import { boot } from 'quasar/wrappers'
import { useAuthStore } from 'src/stores/auth'

export default boot(async ({ router }) => {
  const authStore = useAuthStore()

  // Initialize auth state (checks existing session)
  try {
    await authStore.initialize()
  } catch (err) {
    console.error('[Auth Boot] Initialization failed:', err)
  }

  router.beforeEach(async (to, _from, next) => {
    // Legacy HR path redirect
    if (to.path === '/hr' || to.path.startsWith('/hr/')) {
      return next('/dashboard')
    }

    const requiresAuth = to.matched.some((r) => r.meta.requiresAuth)

    // ── Not authenticated → send to login ────────────────────────────────
    if (requiresAuth && !authStore.isAuthenticated) {
      return next({ path: '/auth/login', query: { redirect: to.fullPath } })
    }

    // ── Already logged in → skip login page ──────────────────────────────
    if (to.path === '/auth/login' && authStore.isAuthenticated) {
      return next(authStore.defaultLandingPage)
    }

    // ── Role guard ────────────────────────────────────────────────────────
    if (requiresAuth && authStore.isAuthenticated) {
      // Admin bypasses all checks
      if (authStore.isAdmin) return next()

      // If roles are still loading (race on first navigation), let through
      if (authStore.roles.length === 0) return next()

      // Use DB-driven access check (with hardcoded fallback)
      if (!authStore.canAccess(to.path)) {
        return next(authStore.defaultLandingPage)
      }
    }

    next()
  })
})

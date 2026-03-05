/**
 * ╔══════════════════════════════════════════════════════╗
 * ║   VisionCore ERP — Role-Based Access Control (RBAC)  ║
 * ║   Single source of truth for all access decisions    ║
 * ╚══════════════════════════════════════════════════════╝
 */

import type { UserRole } from 'src/stores/auth'

// ─── All route prefixes each role can access ──────────────────────────────────
export const ROLE_ROUTE_ACCESS: Partial<Record<UserRole, string[]>> = {
  admin: ['*'],

  user: [
    '/dashboard',
    '/billing',
    '/collections',
    '/customers',
    '/inventory',
    '/finance',
    '/services',
    '/reports',
    '/search',
  ],

  manager: [
    '/dashboard',
    '/billing',
    '/collections',
    '/customers',
    '/inventory',
    '/finance',
    '/services',
    '/reports',
    '/search',
  ],

  finance: ['/finance', '/collections', '/reports', '/billing/history', '/search'],

  inventory: ['/inventory', '/reports/hub', '/search'],

  hr: ['/search'],

  cashier: ['/billing', '/collections', '/search'],

  waiter: ['/billing', '/search'],

  kitchen: ['/search'],
}

// ─── Default landing page per role ────────────────────────────────────────────
export const ROLE_LANDING: Partial<Record<UserRole, string>> = {
  admin: '/dashboard',
  user: '/billing',
  manager: '/dashboard',
  finance: '/finance',
  inventory: '/inventory',
  cashier: '/billing',
  waiter: '/billing',
  kitchen: '/billing',
  hr: '/dashboard',
}

// ─── Nav Item Type ─────────────────────────────────────────────────────────────
export interface NavItem {
  label: string
  icon: string
  to?: string
  roles: UserRole[]
  section?: string // Section group label (shown as separator header)
  sectionStart?: boolean // If true, renders a section divider above this item
  moduleCode?: string
  children?: NavItem[]
}

// ─── Enterprise Sidebar Navigation ────────────────────────────────────────────
// Structured following SAP Business One / Microsoft Dynamics hierarchy:
// Core → Transactions → Master Data → Operations → Intelligence → Administration
export const NAV_ITEMS: NavItem[] = [
  // ── OVERVIEW ──────────────────────────────────────────────────────────────
  {
    label: 'Dashboard',
    icon: 'grid_view',
    to: '/dashboard',
    roles: ['admin', 'manager', 'user', 'hr'],
    section: 'OVERVIEW',
    sectionStart: true,
  },

  // ── SALES ─────────────────────────────────────────────────────────────────
  {
    label: 'Sales & Billing',
    icon: 'receipt_long',
    roles: ['admin', 'manager', 'user', 'cashier', 'waiter'],
    moduleCode: 'FINANCE',
    section: 'SALES',
    sectionStart: true,
    children: [
      {
        label: 'New Invoice',
        icon: 'add_circle_outline',
        to: '/billing',
        roles: ['admin', 'manager', 'user', 'cashier', 'waiter'],
      },
      {
        label: 'Invoice History',
        icon: 'receipt',
        to: '/billing/history',
        roles: ['admin', 'manager', 'user', 'finance', 'cashier'],
      },
      {
        label: 'Outstanding Collections',
        icon: 'account_balance_wallet',
        to: '/collections/outstanding',
        roles: ['admin', 'manager', 'user', 'finance', 'cashier'],
      },
    ],
  },
  {
    label: 'Customers',
    icon: 'people_alt',
    to: '/customers',
    roles: ['admin', 'manager', 'user'],
    moduleCode: 'FINANCE',
    section: 'SALES',
  },

  // ── OPERATIONS ────────────────────────────────────────────────────────────
  {
    label: 'Inventory',
    icon: 'inventory_2',
    to: '/inventory',
    roles: ['admin', 'manager', 'user', 'inventory'],
    moduleCode: 'INVENTORY',
    section: 'OPERATIONS',
    sectionStart: true,
  },

  // ── FINANCE ───────────────────────────────────────────────────────────────
  {
    label: 'Finance',
    icon: 'account_balance',
    to: '/finance',
    roles: ['admin', 'manager', 'user', 'finance'],
    moduleCode: 'FINANCE',
    section: 'FINANCE',
    sectionStart: true,
  },

  // ── SERVICES ──────────────────────────────────────────────────────────────
  {
    label: 'Services',
    icon: 'build',
    roles: ['admin', 'manager', 'user'],
    moduleCode: 'SERVICES',
    section: 'OPERATIONS',
    children: [
      {
        label: 'Dashboard',
        icon: 'dashboard',
        to: '/services',
        roles: ['admin', 'manager', 'user'],
      },
      {
        label: 'Jobs List',
        icon: 'list_alt',
        to: '/services/jobs',
        roles: ['admin', 'manager', 'user'],
      },
      {
        label: 'New Job',
        icon: 'add_circle_outline',
        to: '/services/new',
        roles: ['admin', 'manager', 'user'],
      },
      {
        label: 'Reports',
        icon: 'assessment',
        to: '/services/reports',
        roles: ['admin', 'manager'],
      },
    ],
  },

  // ── INTELLIGENCE ──────────────────────────────────────────────────────────
  {
    label: 'Reports',
    icon: 'bar_chart',
    roles: ['admin', 'manager', 'user', 'finance', 'inventory'],
    section: 'INTELLIGENCE',
    sectionStart: true,
    children: [
      {
        label: 'Reports Hub',
        icon: 'summarize',
        to: '/reports/hub',
        roles: ['admin', 'manager', 'user', 'finance', 'inventory'],
      },
      {
        label: 'All Invoices',
        icon: 'receipt_long',
        to: '/reports/all-invoices',
        roles: ['admin', 'manager', 'user', 'finance'],
      },
      {
        label: 'Sales Report',
        icon: 'trending_up',
        to: '/reports/sales',
        roles: ['admin', 'manager'],
      },
      {
        label: 'Sales Detailed',
        icon: 'description',
        to: '/reports/invoices',
        roles: ['admin', 'manager', 'finance'],
      },
      {
        label: 'Payment Report',
        icon: 'payments',
        to: '/reports/payments',
        roles: ['admin', 'manager', 'finance'],
      },
    ],
  },

  // ── ADMINISTRATION ────────────────────────────────────────────────────────
  {
    label: 'Admin Control',
    icon: 'admin_panel_settings',
    to: '/admin',
    roles: ['admin'],
    section: 'ADMINISTRATION',
    sectionStart: true,
  },
]

// ─── Route Access Check ────────────────────────────────────────────────────────
export function canAccessRoute(userRoles: UserRole[], routePath: string): boolean {
  if (!userRoles || userRoles.length === 0) return false
  if (userRoles.includes('admin')) return true
  return userRoles.some((role) => {
    const allowedPaths = ROLE_ROUTE_ACCESS[role]
    if (!allowedPaths) return false
    if (allowedPaths.includes('*')) return true
    return allowedPaths.some((p) => routePath.startsWith(p))
  })
}

// ─── Sidebar Filter ────────────────────────────────────────────────────────────
export function getFilteredNavItems(
  userRoles: UserRole[],
  canAccessFn?: (path: string) => boolean,
): NavItem[] {
  function filterItems(items: NavItem[]): NavItem[] {
    return items
      .filter((item) => {
        if (userRoles.includes('admin')) return true

        // If a dynamic access function is provided, use it (checks DB user_route_access)
        if (canAccessFn) {
          if (item.to) return canAccessFn(item.to)
          if (item.children) return true // Let children mapping filter it, then check later
        }

        // Fallback to static role checking
        return item.roles.some((role) => userRoles.includes(role))
      })
      .map((item) => {
        if (item.children) {
          return { ...item, children: filterItems(item.children) }
        }
        return item
      })
      .filter((item) => {
        // Remove empty parent menus
        if (item.children && item.children.length === 0 && !item.to) return false
        return true
      })
  }
  return filterItems(NAV_ITEMS)
}

// ─── Page Feature Restrictions ────────────────────────────────────────────────
export interface RolePageRestrictions {
  canProcessPayment: boolean
}

export function getRoleRestrictions(roles: UserRole[]): RolePageRestrictions {
  return {
    canProcessPayment: roles.includes('admin') || roles.includes('manager'),
  }
}

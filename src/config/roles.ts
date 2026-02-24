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

  manager: [
    '/dashboard',
    '/billing',
    '/collections',
    '/customers',
    '/inventory',
    '/finance',
    '/reports',
    '/search',
  ],

  finance: [
    '/finance',
    '/collections',
    '/reports/invoices',
    '/reports/payments',
    '/billing/history',
    '/search',
  ],

  inventory: ['/inventory', '/search'],

  hr: ['/search'],

  cashier: ['/billing', '/collections', '/search'],

  waiter: ['/billing', '/search'],

  kitchen: ['/search'],
}

// ─── Default landing page per role ────────────────────────────────────────────
export const ROLE_LANDING: Partial<Record<UserRole, string>> = {
  admin: '/dashboard',
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
    roles: ['admin', 'manager', 'hr'],
    section: 'OVERVIEW',
    sectionStart: true,
  },

  // ── SALES ─────────────────────────────────────────────────────────────────
  {
    label: 'Sales & Billing',
    icon: 'receipt_long',
    roles: ['admin', 'manager', 'cashier', 'waiter'],
    moduleCode: 'FINANCE',
    section: 'SALES',
    sectionStart: true,
    children: [
      {
        label: 'New Invoice',
        icon: 'add_circle_outline',
        to: '/billing',
        roles: ['admin', 'manager', 'cashier', 'waiter'],
      },
      {
        label: 'Invoice History',
        icon: 'receipt',
        to: '/billing/history',
        roles: ['admin', 'manager', 'finance', 'cashier'],
      },
      {
        label: 'Outstanding Collections',
        icon: 'account_balance_wallet',
        to: '/collections/outstanding',
        roles: ['admin', 'manager', 'finance', 'cashier'],
      },
    ],
  },
  {
    label: 'Customers',
    icon: 'people_alt',
    to: '/customers',
    roles: ['admin', 'manager'],
    moduleCode: 'FINANCE',
    section: 'SALES',
  },

  // ── OPERATIONS ────────────────────────────────────────────────────────────
  {
    label: 'Inventory',
    icon: 'inventory_2',
    to: '/inventory',
    roles: ['admin', 'manager', 'inventory'],
    moduleCode: 'INVENTORY',
    section: 'OPERATIONS',
    sectionStart: true,
  },

  // ── FINANCE ───────────────────────────────────────────────────────────────
  {
    label: 'Finance',
    icon: 'account_balance',
    to: '/finance',
    roles: ['admin', 'manager', 'finance'],
    moduleCode: 'FINANCE',
    section: 'FINANCE',
    sectionStart: true,
  },

  // ── INTELLIGENCE ──────────────────────────────────────────────────────────
  {
    label: 'Reports',
    icon: 'bar_chart',
    roles: ['admin', 'manager', 'finance'],
    section: 'INTELLIGENCE',
    sectionStart: true,
    children: [
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
export function getFilteredNavItems(userRoles: UserRole[]): NavItem[] {
  function filterItems(items: NavItem[]): NavItem[] {
    return items
      .filter((item) => {
        if (userRoles.includes('admin')) return true
        return item.roles.some((role) => userRoles.includes(role))
      })
      .map((item) => {
        if (item.children) {
          return { ...item, children: filterItems(item.children) }
        }
        return item
      })
      .filter((item) => {
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

/**
 * VisionCore ERP — Routes
 *
 * Role-based access is enforced entirely by the router guard in src/boot/auth.ts
 * which calls canAccessRoute() from src/config/roles.ts.
 *
 * Do NOT add role restrictions here — manage access via Admin → Users panel.
 */

const routes = [
  {
    path: '/',
    component: () => import('layouts/MainLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', redirect: 'dashboard' },

      // ── Dashboard ────────────────────────────────────────────────
      {
        path: 'dashboard',
        component: () => import('pages/dashboard/DashboardPage.vue'),
      },

      // ── Reports ──────────────────────────────────────────────────
      {
        path: 'reports/hub',
        component: () => import('pages/reports/ReportsHub.vue'),
      },
      {
        path: 'reports/sales',
        component: () => import('pages/reports/SalesReport.vue'),
      },
      {
        path: 'reports/service-sales',
        component: () => import('pages/reports/SalesReport.vue'),
      },
      {
        path: 'reports/invoices',
        component: () => import('pages/reports/InvoiceReport.vue'),
      },
      {
        path: 'reports/all-invoices',
        component: () => import('pages/reports/InvoicesPage.vue'),
      },
      {
        path: 'reports/payments',
        component: () => import('pages/reports/PaymentReport.vue'),
      },

      // ── Billing & Invoices ────────────────────────────────────────
      {
        path: 'pos',
        component: () => import('pages/billing/BillingPage.vue'),
      },
      {
        path: 'billing',
        name: 'billing',
        component: () => import('pages/billing/BillingPage.vue'),
      },
      {
        path: 'billing/history',
        name: 'invoice-history',
        component: () => import('pages/billing/InvoiceHistoryPage.vue'),
      },
      {
        path: 'billing/print/:id',
        name: 'invoice-print',
        component: () => import('components/billing/InvoicePrint.vue'),
      },

      // ── Collections ───────────────────────────────────────────────
      {
        path: 'collections/outstanding',
        name: 'outstanding-collections',
        component: () => import('pages/collections/OutstandingCollectionsPage.vue'),
      },

      // ── Customers ────────────────────────────────────────────────
      {
        path: 'customers',
        component: () => import('pages/customers/CustomersPage.vue'),
      },

      // ── Inventory ────────────────────────────────────────────────
      {
        path: 'inventory',
        component: () => import('pages/InventoryPage.vue'),
      },

      // ── Finance ──────────────────────────────────────────────────
      {
        path: 'finance',
        component: () => import('pages/finance/FinanceOverview.vue'),
      },

      // ── Services (Device Repair & Management) ────────────────────
      {
        path: 'services',
        component: () => import('pages/services/ServiceDashboard.vue'),
      },
      {
        path: 'services/jobs',
        component: () => import('pages/services/JobsList.vue'),
      },
      {
        path: 'services/new',
        component: () => import('pages/services/CreateJob.vue'),
      },
      {
        path: 'services/edit/:id',
        name: 'service-job-edit',
        component: () => import('pages/services/CreateJob.vue'),
        props: true,
      },
      {
        path: 'services/jobs/:id',
        name: 'service-job-details',
        component: () => import('pages/services/JobDetails.vue'),
        props: true,
      },
      {
        path: 'services/reports',
        component: () => import('pages/services/ServiceReports.vue'),
      },

      // ── Search ───────────────────────────────────────────────────
      {
        path: 'search',
        component: () => import('pages/SearchPage.vue'),
      },

      // ── Admin (admin role only — enforced by canAccessRoute) ─────
      {
        path: 'admin',
        component: () => import('pages/AdminPage.vue'),
      },
      {
        path: 'admin/users',
        component: () => import('pages/admin/UsersPage.vue'),
      },
      {
        path: 'admin/roles',
        component: () => import('pages/admin/RolesPage.vue'),
      },
      {
        path: 'admin/branches',
        component: () => import('pages/admin/BranchesPage.vue'),
      },
      {
        path: 'admin/settings',
        component: () => import('pages/admin/SettingsPage.vue'),
      },
      {
        path: 'admin/backup',
        component: () => import('pages/admin/BackupCenter.vue'),
      },
    ],
  },

  // ── Auth ─────────────────────────────────────────────────────────────────
  {
    path: '/auth',
    component: () => import('layouts/AuthLayout.vue'),
    meta: { requiresAuth: false },
    children: [{ path: 'login', component: () => import('pages/auth/LoginPage.vue') }],
  },

  // ── 404 ──────────────────────────────────────────────────────────────────
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
]

export default routes

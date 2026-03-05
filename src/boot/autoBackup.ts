/**
 * Auto Backup Boot — VisionCore ERP
 * Runs a daily backup automatically when the user logs in.
 * Downloads a full JSON backup file once per day to the user's device.
 */
import { boot } from 'quasar/wrappers'
import { saveAs } from 'file-saver'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'

const BACKUP_TABLES = [
  'companies',
  'branches',
  'item_categories',
  'units_of_measure',
  'items',
  'warehouses',
  'item_warehouse_stock',
  'suppliers',
  'customers',
  'inventory_documents',
  'inventory_document_lines',
  'service_jobs',
  'service_job_parts',
  'invoices',
  'invoice_items',
  'payments',
  'expense_categories',
  'expenses',
  'employees',
  'attendance_records',
  'payroll_records',
  'commission_packages',
]

function todayKey() {
  return new Date().toISOString().slice(0, 10)
}

async function runAutoBackup(companyId: string | null) {
  console.log('[AutoBackup] Starting daily backup...')
  const backup: Record<string, unknown> = {
    _meta: {
      version: '1.0',
      app: 'VisionCore ERP',
      created_at: new Date().toISOString(),
      company_id: companyId,
      type: 'auto',
    },
    tables: {} as Record<string, unknown[]>,
  }

  const tables = backup.tables as Record<string, unknown[]>

  for (const table of BACKUP_TABLES) {
    try {
      const { data: probe } = await supabase.from(table).select('company_id').limit(1)
      const hasCompanyId =
        companyId && table !== 'companies' && probe?.[0] && 'company_id' in probe[0]
      const { data, error } = hasCompanyId
        ? await supabase
            .from(table)
            .select('*')
            .eq('company_id', companyId as string)
        : await supabase.from(table).select('*')
      tables[table] = error ? [] : (data ?? [])
    } catch {
      tables[table] = []
    }
  }

  const json = JSON.stringify(backup, null, 2)
  const blob = new Blob([json], { type: 'application/json' })
  const filename = `VisionCore_AutoBackup_${todayKey()}.json`
  saveAs(blob, filename)

  // Save to history
  const totalRecords = Object.values(tables).reduce((s, rows) => s + rows.length, 0)
  const LS_KEY = 'visioncore_backup_history'
  try {
    const existing = JSON.parse(localStorage.getItem(LS_KEY) || '[]')
    const entry = {
      id: Date.now().toString(),
      date: new Date().toISOString().replace('T', ' ').slice(0, 19),
      tables: Object.keys(tables).length,
      records: totalRecords,
      size: blob.size,
      filename,
      data: json,
    }
    const updated = [entry, ...existing].slice(0, 10)
    localStorage.setItem(LS_KEY, JSON.stringify(updated))
  } catch {
    // ignore localStorage errors
  }

  localStorage.setItem('visioncore_last_backup_date', todayKey())
  console.log(`[AutoBackup] Done — ${Object.keys(tables).length} tables, ${totalRecords} records`)
}

export default boot(({ router }) => {
  // Check after user successfully navigates to dashboard (i.e., is logged in)
  router.afterEach((to) => {
    if (to.path !== '/dashboard') return

    const lastDate = localStorage.getItem('visioncore_last_backup_date')
    if (lastDate === todayKey()) return // already backed up today

    // Delay 60 seconds to let the app fully load before downloading
    setTimeout(async () => {
      try {
        const authStore = useAuthStore()
        if (!authStore.isAuthenticated) return
        const companyId = authStore.currentBranch?.company_id ?? null
        await runAutoBackup(companyId)
      } catch (err) {
        console.warn('[AutoBackup] Failed:', err)
      }
    }, 60_000) // 60 seconds after dashboard load
  })
})

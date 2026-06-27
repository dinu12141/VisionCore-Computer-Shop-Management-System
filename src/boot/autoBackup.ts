/**
 * Auto Backup Boot — VisionCore ERP
 * Downloads a full JSON backup once per day when the user navigates to dashboard.
 *
 * Fixes applied (2026-06-25):
 * - CRASH FIX: Never store backup JSON data in localStorage (5-10 MB limit → quota exceeded)
 *   History entries now store only metadata (filename, size, record count, date).
 * - Corrected table names to match actual production schema:
 *     units_of_measure → uom
 *     item_warehouse_stock → stock_on_hand
 *     service_job_parts → service_parts_used
 * - Removed non-existent tables: employees, attendance_records, payroll_records,
 *   commission_packages (this is a computer parts shop, not a restaurant/HR system)
 * - Parallel fetch with concurrency cap (5 at a time) to avoid hammering the DB
 */
import { boot } from 'quasar/wrappers'
import { saveAs } from 'file-saver'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'

const BACKUP_TABLES = [
  'companies',
  'branches',
  'item_categories',
  'uom',                    // was: units_of_measure (wrong name)
  'items',
  'warehouses',
  'stock_on_hand',          // was: item_warehouse_stock (wrong name)
  'item_warehouse_settings',
  'suppliers',
  'customers',
  'inventory_documents',
  'inventory_document_lines',
  'inventory_ledger',
  'service_jobs',
  'service_parts_used',     // was: service_job_parts (wrong name)
  'invoices',
  'invoice_items',
  'invoice_payments',
]

const TABLES_WITHOUT_COMPANY_ID = new Set([
  'companies',
  'item_warehouse_settings',
  'inventory_document_lines',
  'invoice_items',
])

const LS_KEY = 'visioncore_backup_history'
const LS_DATE_KEY = 'visioncore_last_backup_date'
const CONCURRENCY = 5 // max parallel Supabase fetches

function todayKey(): string {
  return new Date().toISOString().slice(0, 10)
}

/** Run an array of async tasks with max concurrency */
async function pLimit<T>(
  tasks: (() => Promise<T>)[],
  concurrency: number,
): Promise<T[]> {
  const results: T[] = []
  let idx = 0

  async function worker() {
    while (idx < tasks.length) {
      const i = idx++
      results[i] = await tasks[i]!()
    }
  }

  const workers = Array.from({ length: Math.min(concurrency, tasks.length) }, worker)
  await Promise.all(workers)
  return results
}

async function fetchTable(
  table: string,
  companyId: string | null,
): Promise<unknown[]> {
  try {
    const hasCompanyId = companyId && !TABLES_WITHOUT_COMPANY_ID.has(table)

    const { data, error } = hasCompanyId
      ? await supabase.from(table).select('*').eq('company_id', companyId as string)
      : await supabase.from(table).select('*')

    return error ? [] : (data ?? [])
  } catch {
    return []
  }
}

async function runAutoBackup(companyId: string | null): Promise<void> {
  const tasks = BACKUP_TABLES.map((table) => () => fetchTable(table, companyId))
  const results = await pLimit(tasks, CONCURRENCY)

  const tables: Record<string, unknown[]> = {}
  BACKUP_TABLES.forEach((name, i) => { tables[name] = results[i] ?? [] })

  const backup = {
    _meta: {
      version: '1.1',
      app: 'VisionCore ERP',
      created_at: new Date().toISOString(),
      company_id: companyId,
      type: 'auto',
    },
    tables,
  }

  const json = JSON.stringify(backup, null, 2)
  const blob = new Blob([json], { type: 'application/json' })
  const filename = `VisionCore_AutoBackup_${todayKey()}.json`
  saveAs(blob, filename)

  // Persist METADATA ONLY in localStorage — never the raw JSON data (quota risk)
  const totalRecords = Object.values(tables).reduce((s, rows) => s + rows.length, 0)
  try {
    const existing: unknown[] = JSON.parse(localStorage.getItem(LS_KEY) || '[]')
    const entry = {
      id: Date.now().toString(),
      date: new Date().toISOString().replace('T', ' ').slice(0, 19),
      tables: Object.keys(tables).length,
      records: totalRecords,
      size: blob.size,
      filename,
      // data: json  ← REMOVED: storing MBs of JSON in localStorage causes QuotaExceededError
    }
    const updated = [entry, ...existing].slice(0, 10)
    localStorage.setItem(LS_KEY, JSON.stringify(updated))
  } catch {
    // Non-fatal — backup file was already downloaded
  }

  localStorage.setItem(LS_DATE_KEY, todayKey())
}

export default boot(({ router }) => {
  router.afterEach((to) => {
    if (to.path !== '/dashboard') return

    const lastDate = localStorage.getItem(LS_DATE_KEY)
    if (lastDate === todayKey()) return

    // Delay 60 s to let the app fully load before the download starts
    setTimeout(async () => {
      try {
        const authStore = useAuthStore()
        if (!authStore.isAuthenticated) return
        const companyId = authStore.currentBranch?.company_id ?? null
        await runAutoBackup(companyId)
      } catch {
        // Backup failure must never affect the user's session
      }
    }, 60_000)
  })
})

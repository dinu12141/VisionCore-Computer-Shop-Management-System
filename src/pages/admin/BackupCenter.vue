<template>
  <q-page class="q-pa-md backup-page">
    <PageHeader
      title="Backup Center"
      subtitle="Download, schedule and restore your VisionCore data"
      showBack
    />

    <!-- ── Top row: 3 action cards ──────────────────────────────────────── -->
    <div class="row q-col-gutter-md q-mt-sm">
      <!-- 1. Manual Backup -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="action-card full-height">
          <q-card-section>
            <div class="row items-center q-mb-sm">
              <q-avatar
                color="indigo-1"
                text-color="indigo"
                icon="backup"
                size="42px"
                class="q-mr-sm"
              />
              <div>
                <div class="text-h6 text-weight-bold">Download Backup</div>
                <div class="text-caption text-grey">Full JSON snapshot of all data</div>
              </div>
            </div>
            <q-separator class="q-my-md" />
            <div class="text-caption text-grey q-mb-md">
              Downloads a single <code>.json</code> file with
              <strong>all your business data</strong>: customers, items, service jobs, invoices,
              inventory and more.
            </div>
            <q-btn
              color="indigo"
              icon="file_download"
              label="Download Backup Now"
              class="full-width"
              size="md"
              unelevated
              :loading="backupRunning"
              @click="runBackup"
            />
            <div class="text-caption text-grey q-mt-sm text-center">
              <q-icon name="schedule" size="12px" />
              Auto-backup runs daily when you log in
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- 2. Import / Restore -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="action-card full-height">
          <q-card-section>
            <div class="row items-center q-mb-sm">
              <q-avatar
                color="teal-1"
                text-color="teal"
                icon="restore"
                size="42px"
                class="q-mr-sm"
              />
              <div>
                <div class="text-h6 text-weight-bold">Import / Restore</div>
                <div class="text-caption text-grey">Restore from a backup file</div>
              </div>
            </div>
            <q-separator class="q-my-md" />
            <div class="text-caption text-grey q-mb-md">
              Select a previously downloaded <code>.json</code> backup file. All existing data will
              be <strong>merged / replaced</strong> with the backup.
            </div>
            <q-file
              v-model="importFile"
              accept=".json"
              outlined
              dense
              label="Select backup .json file"
              class="q-mb-sm"
              :dark="$q.dark.isActive"
            >
              <template #prepend><q-icon name="attach_file" /></template>
            </q-file>
            <q-btn
              color="teal"
              icon="restore"
              label="Restore from Backup"
              class="full-width"
              size="md"
              unelevated
              :loading="importing"
              :disable="!importFile"
              @click="confirmImport"
            />
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- ── Backup Progress ───────────────────────────────────────────────── -->
    <q-card flat bordered class="q-mt-md" v-if="backupRunning || importProgress.active">
      <q-card-section>
        <div class="row items-center q-mb-sm">
          <q-spinner-dots color="primary" size="24px" class="q-mr-sm" />
          <div class="text-subtitle1 text-weight-medium">{{ progressLabel }}</div>
        </div>
        <q-linear-progress
          :value="progressValue"
          color="primary"
          rounded
          class="q-mb-xs"
          size="8px"
        />
        <div class="text-caption text-grey">{{ progressCaption }}</div>
      </q-card-section>
    </q-card>

    <!-- ── Backup History ────────────────────────────────────────────────── -->
    <q-card flat bordered class="q-mt-lg">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div>
          <div class="text-h6 text-weight-bold">Local Backup History</div>
          <div class="text-caption text-grey">Stored in this browser — last 10 backups</div>
        </div>
        <q-btn flat round icon="refresh" color="grey" @click="loadHistory" />
      </q-card-section>

      <q-table
        :rows="history"
        :columns="histCols"
        row-key="id"
        flat
        class="bg-transparent"
        :dark="$q.dark.isActive"
        :pagination="{ rowsPerPage: 10 }"
      >
        <template v-slot:body-cell-size="props">
          <q-td :props="props">{{ formatBytes(props.row.size) }}</q-td>
        </template>
        <template v-slot:body-cell-tables="props">
          <q-td :props="props">
            <q-chip dense color="indigo-1" text-color="indigo" size="sm">
              {{ props.row.tables }} tables
            </q-chip>
            <q-chip dense color="teal-1" text-color="teal" size="sm" class="q-ml-xs">
              {{ props.row.records.toLocaleString() }} records
            </q-chip>
          </q-td>
        </template>
        <template v-slot:body-cell-actions="props">
          <q-td :props="props">
            <q-btn
              flat
              dense
              round
              icon="file_download"
              color="indigo"
              size="sm"
              @click="reDownload(props.row)"
            >
              <q-tooltip>Re-download this backup</q-tooltip>
            </q-btn>
            <q-btn
              flat
              dense
              round
              icon="delete"
              color="negative"
              size="sm"
              @click="deleteHistory(props.row.id)"
            >
              <q-tooltip>Remove from history</q-tooltip>
            </q-btn>
          </q-td>
        </template>
        <template v-slot:no-data>
          <div class="full-width text-center q-pa-xl text-grey">
            <q-icon name="history" size="48px" color="grey-4" class="q-mb-md" /><br />
            No backups yet. Click "Download Backup Now" to create one.
          </div>
        </template>
      </q-table>
    </q-card>

    <!-- ── Import Result Dialog ──────────────────────────────────────────── -->
    <q-dialog v-model="importResultDialog">
      <q-card style="min-width: 420px">
        <q-card-section class="row items-center">
          <q-icon
            :name="importResult.success ? 'check_circle' : 'error'"
            :color="importResult.success ? 'positive' : 'negative'"
            size="28px"
            class="q-mr-sm"
          />
          <div class="text-h6">
            {{ importResult.success ? 'Restore Complete' : 'Restore Failed' }}
          </div>
        </q-card-section>
        <q-separator />
        <q-card-section>
          <div v-if="importResult.success">
            <div class="text-positive q-mb-md">✅ Data restored successfully!</div>
            <q-list dense>
              <q-item v-for="(count, table) in importResult.details" :key="table">
                <q-item-section avatar
                  ><q-icon name="table_chart" color="teal" size="18px"
                /></q-item-section>
                <q-item-section
                  ><q-item-label>{{ table }}</q-item-label></q-item-section
                >
                <q-item-section side
                  ><q-badge color="teal" :label="count + ' rows'"
                /></q-item-section>
              </q-item>
            </q-list>
          </div>
          <div v-else class="text-negative">{{ importResult.error }}</div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Close" v-close-popup @click="importFile = null" />
          <q-btn
            v-if="importResult.success"
            color="primary"
            label="Reload Page"
            @click="
              () => {
                importResultDialog = false
                window.location.reload()
              }
            "
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { saveAs } from 'file-saver'
import PageHeader from 'components/common/PageHeader.vue'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/auth'

const $q = useQuasar()
const auth = useAuthStore()
const getCompanyId = () => auth.currentBranch?.company_id

// ── State ──────────────────────────────────────────────────────────────────────
const backupRunning = ref(false)
const importing = ref(false)

const importFile = ref(null)
const history = ref([])
const importResultDialog = ref(false)
const importResult = ref({ success: false, details: {}, error: '' })
const progressValue = ref(0)
const progressLabel = ref('')
const progressCaption = ref('')
const importProgress = ref({ active: false })

// ── History columns ────────────────────────────────────────────────────────────
const histCols = [
  { name: 'date', label: 'Date', field: 'date', align: 'left', sortable: true },
  { name: 'tables', label: 'Contents', field: 'tables', align: 'left' },
  { name: 'size', label: 'Size', field: 'size', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

// ── Tables to backup (in dependency order for restore) ─────────────────────────
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

// ── Helpers ────────────────────────────────────────────────────────────────────
function formatBytes(bytes) {
  if (!bytes) return '0 B'
  const k = 1024,
    sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`
}

function now() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19)
}

function todayKey() {
  return new Date().toISOString().slice(0, 10)
}

// ── Local Storage history ──────────────────────────────────────────────────────
const LS_KEY = 'visioncore_backup_history'

function loadHistory() {
  try {
    history.value = JSON.parse(localStorage.getItem(LS_KEY) || '[]')
  } catch {
    history.value = []
  }
}

function saveToHistory(entry) {
  loadHistory()
  const list = [entry, ...history.value].slice(0, 10) // keep last 10
  localStorage.setItem(LS_KEY, JSON.stringify(list))
  history.value = list
}

function deleteHistory(id) {
  const list = history.value.filter((h) => h.id !== id)
  localStorage.setItem(LS_KEY, JSON.stringify(list))
  history.value = list
}

// ── Core: fetch all data from Supabase ────────────────────────────────────────
async function fetchAllData() {
  const companyId = getCompanyId()
  const backup = {
    _meta: {
      version: '1.0',
      app: 'VisionCore ERP',
      created_at: new Date().toISOString(),
      company_id: companyId,
    },
    tables: {},
  }

  let done = 0
  for (const table of BACKUP_TABLES) {
    progressLabel.value = `Fetching ${table}...`
    progressCaption.value = `${done + 1} / ${BACKUP_TABLES.length} tables`
    progressValue.value = done / BACKUP_TABLES.length

    try {
      let query = supabase.from(table).select('*')
      // Filter by company_id where applicable
      if (companyId && !['companies'].includes(table)) {
        const { data: sample } = await supabase.from(table).select('company_id').limit(1)
        if (sample?.[0]?.company_id !== undefined) {
          query = query.eq('company_id', companyId)
        }
      }
      const { data, error } = await query
      if (error) {
        console.warn(`[backup] ${table} skipped:`, error.message)
        backup.tables[table] = []
      } else {
        backup.tables[table] = data || []
      }
    } catch (e) {
      console.warn(`[backup] ${table} error:`, e.message)
      backup.tables[table] = []
    }
    done++
  }

  progressValue.value = 1
  return backup
}

// ── Run Backup ────────────────────────────────────────────────────────────────
async function runBackup(silent = false) {
  if (backupRunning.value) return
  backupRunning.value = true
  progressValue.value = 0
  progressLabel.value = 'Starting backup...'
  progressCaption.value = ''

  try {
    const backup = await fetchAllData()

    // Count total records
    const totalRecords = Object.values(backup.tables).reduce((s, rows) => s + rows.length, 0)
    const tableCount = Object.keys(backup.tables).length

    // Serialize
    const json = JSON.stringify(backup, null, 2)
    const blob = new Blob([json], { type: 'application/json' })
    const filename = `VisionCore_Backup_${todayKey()}.json`

    // Download
    saveAs(blob, filename)

    // Save to history
    saveToHistory({
      id: Date.now().toString(),
      date: now(),
      tables: tableCount,
      records: totalRecords,
      size: blob.size,
      filename,
      data: json, // store for re-download
    })

    // Mark daily auto-backup done
    localStorage.setItem('visioncore_last_backup_date', todayKey())

    if (!silent) {
      $q.notify({
        type: 'positive',
        icon: 'check_circle',
        message: 'Backup downloaded!',
        caption: `${tableCount} tables · ${totalRecords.toLocaleString()} records`,
        position: 'top-right',
        timeout: 5000,
      })
    }
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: 'Backup failed: ' + err.message,
      position: 'top-right',
    })
  } finally {
    backupRunning.value = false
    progressValue.value = 0
    progressLabel.value = ''
  }
}

// ── Re-download from history ──────────────────────────────────────────────────
function reDownload(entry) {
  if (!entry.data) {
    $q.notify({ type: 'warning', message: 'Backup data not stored locally. Run a new backup.' })
    return
  }
  const blob = new Blob([entry.data], { type: 'application/json' })
  saveAs(blob, entry.filename || `VisionCore_Backup.json`)
}

// ── Confirm Import ────────────────────────────────────────────────────────────
function confirmImport() {
  $q.dialog({
    title: '⚠️ Confirm Restore',
    message: `This will <strong>overwrite existing data</strong> with the data from your backup file.<br><br>
    All current records will be replaced. This <strong>cannot be undone</strong>.<br><br>
    Are you sure you want to continue?`,
    html: true,
    cancel: { label: 'Cancel', flat: true },
    ok: { label: 'Yes, Restore Data', color: 'teal', unelevated: true },
    dark: $q.dark.isActive,
    persistent: true,
  }).onOk(() => doImport())
}

// ── Do Import / Restore ───────────────────────────────────────────────────────
async function doImport() {
  if (!importFile.value) return
  importing.value = true
  importProgress.value = { active: true }
  progressValue.value = 0
  progressLabel.value = 'Reading backup file...'
  progressCaption.value = ''

  try {
    // Read file
    const text = await importFile.value.text()
    const backup = JSON.parse(text)

    if (!backup._meta || !backup.tables) {
      throw new Error('Invalid backup file format. Please use a VisionCore backup .json file.')
    }

    const tables = Object.entries(backup.tables)
    const details = {}
    let done = 0

    for (const [table, rows] of tables) {
      progressLabel.value = `Restoring ${table}...`
      progressCaption.value = `${done + 1} / ${tables.length} tables · ${rows.length} rows`
      progressValue.value = done / tables.length

      if (!rows.length) {
        details[table] = 0
        done++
        continue
      }

      try {
        // Upsert in chunks of 500
        const CHUNK = 500
        let restored = 0
        for (let i = 0; i < rows.length; i += CHUNK) {
          const chunk = rows.slice(i, i + CHUNK)
          const { error } = await supabase
            .from(table)
            .upsert(chunk, { onConflict: 'id', ignoreDuplicates: false })
          if (error) {
            console.warn(`[restore] ${table} chunk error:`, error.message)
          } else {
            restored += chunk.length
          }
        }
        details[table] = restored
      } catch (e) {
        console.warn(`[restore] ${table} failed:`, e.message)
        details[table] = 0
      }

      done++
    }

    progressValue.value = 1
    importResult.value = { success: true, details, error: '' }
    importResultDialog.value = true

    $q.notify({
      type: 'positive',
      message: 'Restore completed!',
      caption: `${tables.length} tables restored`,
      position: 'top-right',
      timeout: 5000,
    })
  } catch (err) {
    importResult.value = { success: false, details: {}, error: err.message }
    importResultDialog.value = true
  } finally {
    importing.value = false
    importProgress.value = { active: false }
    progressValue.value = 0
    progressLabel.value = ''
  }
}

// ── Auto daily backup check ────────────────────────────────────────────────────
function checkAutoBackup() {
  const lastDate = localStorage.getItem('visioncore_last_backup_date')
  if (lastDate !== todayKey()) {
    // Auto-trigger silently after 30s delay so app loads first
    setTimeout(() => {
      $q.notify({
        type: 'info',
        icon: 'backup',
        message: 'Daily auto-backup starting...',
        caption: 'Your data will be downloaded automatically',
        position: 'top-right',
        timeout: 4000,
      })
      runBackup(false)
    }, 30000) // 30 seconds after page load
  }
}

// ── Init ───────────────────────────────────────────────────────────────────────
onMounted(() => {
  loadHistory()
  checkAutoBackup()
})
</script>

<style scoped>
.backup-page {
  max-width: 1400px;
  margin: 0 auto;
}

.action-card {
  border-radius: 16px !important;
  transition: all 0.2s ease;
}

.action-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08) !important;
}
</style>

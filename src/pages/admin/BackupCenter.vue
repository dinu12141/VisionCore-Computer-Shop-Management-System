<template>
  <q-page class="q-pa-md backup-page">
    <PageHeader title="Backup Center" subtitle="Manage and monitor system data backups" />

    <!-- ── Top action row ─────────────────────────────────────────────────────── -->
    <div class="row q-col-gutter-md q-mt-sm">
      <!-- Run Now Card -->
      <div class="col-12 col-md-4">
        <q-card flat bordered class="run-now-card full-height">
          <q-card-section>
            <div class="row items-center q-mb-md">
              <q-icon name="backup" size="28px" color="primary" class="q-mr-sm" />
              <div>
                <div class="text-h6 text-weight-bold">Run Backup Now</div>
                <div class="text-caption text-grey">Manual full system backup</div>
              </div>
            </div>

            <q-banner v-if="backupRunning" rounded class="bg-blue-1 q-mb-md">
              <template v-slot:avatar>
                <q-spinner-dots color="primary" size="24px" />
              </template>
              <div class="text-primary text-weight-medium">Backup in progress...</div>
              <div class="text-caption">Run ID: {{ activeRunId }}</div>
            </q-banner>

            <q-banner v-else-if="lastRunStatus === 'success'" rounded class="bg-green-1 q-mb-md">
              <template v-slot:avatar><q-icon name="check_circle" color="green" /></template>
              <div class="text-positive text-weight-medium">Last backup succeeded</div>
              <div class="text-caption">{{ formatDate(lastRunAt) }}</div>
            </q-banner>

            <q-banner v-else-if="lastRunStatus === 'failed'" rounded class="bg-red-1 q-mb-md">
              <template v-slot:avatar><q-icon name="error" color="red" /></template>
              <div class="text-negative text-weight-medium">Last backup failed</div>
              <div class="text-caption">{{ formatDate(lastRunAt) }}</div>
            </q-banner>

            <q-btn
              color="primary"
              icon="play_arrow"
              label="Run Backup Now"
              class="full-width"
              size="lg"
              :loading="backupRunning"
              :disable="backupRunning"
              @click="triggerBackup"
            />

            <div class="text-caption text-grey q-mt-md text-center">
              <q-icon name="schedule" size="14px" class="q-mr-xs" />
              Also runs daily at <strong>02:00 (LKA)</strong> automatically
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Stats Cards -->
      <div class="col-12 col-md-8">
        <div class="row q-col-gutter-md">
          <div class="col-6 col-md-3">
            <q-card flat bordered class="stat-mini text-center q-pa-md">
              <q-icon name="history" color="blue" size="28px" />
              <div class="text-h5 text-weight-bold q-mt-xs">{{ logs.length }}</div>
              <div class="text-caption text-grey">Total Runs</div>
            </q-card>
          </div>
          <div class="col-6 col-md-3">
            <q-card flat bordered class="stat-mini text-center q-pa-md">
              <q-icon name="verified" color="green" size="28px" />
              <div class="text-h5 text-weight-bold q-mt-xs">{{ successRate }}%</div>
              <div class="text-caption text-grey">Success Rate</div>
            </q-card>
          </div>
          <div class="col-6 col-md-3">
            <q-card flat bordered class="stat-mini text-center q-pa-md">
              <q-icon name="timer" color="orange" size="28px" />
              <div class="text-h5 text-weight-bold q-mt-xs">{{ lastDuration }}</div>
              <div class="text-caption text-grey">Last Duration</div>
            </q-card>
          </div>
          <div class="col-6 col-md-3">
            <q-card flat bordered class="stat-mini text-center q-pa-md">
              <q-icon name="event_repeat" color="purple" size="28px" />
              <div class="text-subtitle2 text-weight-bold q-mt-xs">7d / 4w / 12m</div>
              <div class="text-caption text-grey">Retention</div>
            </q-card>
          </div>
        </div>

        <q-banner rounded class="bg-amber-1 text-amber-9 q-mt-md">
          <template v-slot:avatar>
            <q-icon name="info" color="amber-9" />
          </template>
          <div class="text-caption">
            <strong>Database Snapshots vs Full DB Restore:</strong>
            CSV exports cover your core data tables. For full Postgres point-in-time recovery use
            <a
              href="https://supabase.com/dashboard/project/ovdheejmgchtohnjozpn/settings/database"
              target="_blank"
              class="text-amber-9"
              >Supabase built-in database backups</a
            >
            (Dashboard → Settings → Database → Backups).
          </div>
        </q-banner>
      </div>
    </div>

    <!-- ── Backup History Table ────────────────────────────────────────────────── -->
    <q-card flat bordered class="q-mt-lg">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div>
          <div class="text-h6 text-weight-bold">Backup History</div>
          <div class="text-caption text-grey">Last 30 runs</div>
        </div>
        <q-btn flat round icon="refresh" :loading="tableLoading" @click="loadLogs" color="grey" />
      </q-card-section>

      <q-table
        :rows="logs"
        :columns="columns"
        row-key="id"
        flat
        :loading="tableLoading"
        :pagination="{ rowsPerPage: 15 }"
        class="bg-transparent"
      >
        <template v-slot:body-cell-status="props">
          <q-td :props="props">
            <q-chip
              :color="statusColor(props.row.status)"
              text-color="white"
              dense
              :icon="statusIcon(props.row.status)"
              size="sm"
            >
              {{ props.row.status }}
            </q-chip>
          </q-td>
        </template>

        <template v-slot:body-cell-mode="props">
          <q-td :props="props">
            <q-badge
              :color="props.row.mode === 'manual' ? 'blue' : 'purple'"
              :label="props.row.mode"
              style="text-transform: capitalize"
            />
          </q-td>
        </template>

        <template v-slot:body-cell-started_at="props">
          <q-td :props="props">{{ formatDate(props.row.started_at) }}</q-td>
        </template>

        <template v-slot:body-cell-duration_ms="props">
          <q-td :props="props">
            <span v-if="props.row.duration_ms">{{ formatDuration(props.row.duration_ms) }}</span>
            <span v-else class="text-grey">—</span>
          </q-td>
        </template>

        <template v-slot:body-cell-actions="props">
          <q-td :props="props">
            <div class="row no-wrap q-gutter-xs items-center">
              <!-- JSON metadata -->
              <q-btn
                v-if="props.row.status === 'success'"
                flat
                dense
                round
                icon="description"
                color="primary"
                size="sm"
                :loading="downloading[props.row.run_id + '_meta']"
                @click="downloadMetadata(props.row)"
              >
                <q-tooltip>Download metadata.json</q-tooltip>
              </q-btn>

              <!-- View / download artifacts -->
              <q-btn
                v-if="props.row.status === 'success' && props.row.artifacts?.length"
                flat
                dense
                round
                icon="folder_open"
                color="teal"
                size="sm"
                @click="viewArtifacts(props.row)"
              >
                <q-tooltip>View & Download Files</q-tooltip>
              </q-btn>

              <!-- Download ALL as ZIP -->
              <q-btn
                v-if="props.row.status === 'success' && props.row.artifacts?.length"
                flat
                dense
                round
                icon="archive"
                color="purple"
                size="sm"
                :loading="downloading[props.row.run_id + '_zip']"
                @click="downloadAllAsZip(props.row)"
              >
                <q-tooltip>Download All as ZIP</q-tooltip>
              </q-btn>

              <!-- Error -->
              <q-btn
                v-if="props.row.error"
                flat
                dense
                round
                icon="bug_report"
                color="negative"
                size="sm"
                @click="showError(props.row)"
              >
                <q-tooltip>View error</q-tooltip>
              </q-btn>
            </div>
          </q-td>
        </template>

        <template v-slot:no-data>
          <div class="full-width text-center q-pa-xl text-grey">
            <q-icon name="backup" size="48px" class="q-mb-md" color="grey-4" />
            <div>No backup runs yet. Click "Run Backup Now" to start.</div>
          </div>
        </template>
      </q-table>
    </q-card>

    <!-- ── Artifacts Dialog ───────────────────────────────────────────────────── -->
    <q-dialog
      v-model="artifactsDialog"
      maximized
      transition-show="slide-up"
      transition-hide="slide-down"
    >
      <q-card>
        <q-card-section class="row items-center q-pb-none">
          <q-icon name="folder_open" color="teal" class="q-mr-sm" />
          <div class="text-h6">Backup Files</div>
          <div class="text-caption text-grey q-ml-sm">Run: {{ selectedLog?.run_id }}</div>
          <q-space />
          <!-- Download All ZIP from dialog -->
          <q-btn
            v-if="selectedLog"
            flat
            icon="archive"
            label="Download All (.zip)"
            color="purple"
            :loading="downloading[selectedLog?.run_id + '_zip']"
            @click="downloadAllAsZip(selectedLog)"
            class="q-mr-sm"
          />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        <q-separator />

        <q-card-section>
          <!-- ── metadata.json ── -->
          <div class="text-subtitle2 text-weight-bold q-mb-sm">
            <q-icon name="code" class="q-mr-xs" color="primary" />
            Metadata (JSON)
          </div>
          <q-list bordered rounded class="q-mb-lg">
            <q-item
              clickable
              :disable="downloading[selectedLog?.run_id + '_meta']"
              @click="downloadMetadata(selectedLog)"
            >
              <q-item-section avatar>
                <q-icon
                  :name="
                    downloading[selectedLog?.run_id + '_meta'] ? 'hourglass_empty' : 'download'
                  "
                  color="primary"
                />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">metadata.json</q-item-label>
                <q-item-label caption
                  >Full run details, artifact list, storage summary</q-item-label
                >
              </q-item-section>
              <q-item-section side>
                <q-chip dense color="blue-1" text-color="blue" label="JSON" />
              </q-item-section>
            </q-item>
          </q-list>

          <!-- ── CSV Snapshots ── -->
          <div class="text-subtitle2 text-weight-bold q-mb-sm">
            <q-icon name="table_chart" class="q-mr-xs" color="teal" />
            Data Snapshots (CSV) — {{ snapshotArtifacts.length }} tables
          </div>
          <q-list bordered separator rounded>
            <q-item
              v-for="a in snapshotArtifacts"
              :key="a.path"
              clickable
              :disable="downloading[a.path]"
              @click="downloadSingleCsv(a)"
            >
              <q-item-section avatar>
                <q-icon
                  :name="downloading[a.path] ? 'hourglass_empty' : 'download'"
                  :color="downloading[a.path] ? 'grey' : 'teal'"
                />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium"> {{ a.name }}.csv </q-item-label>
                <q-item-label caption>
                  <span v-if="a.rows != null">{{ a.rows?.toLocaleString() }} rows</span>
                  <span v-if="a.size_bytes"> · {{ formatBytes(a.size_bytes) }}</span>
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <div class="row items-center q-gutter-xs">
                  <q-spinner-dots v-if="downloading[a.path]" color="grey" size="16px" />
                  <q-chip dense color="green-1" text-color="green" label="CSV" />
                </div>
              </q-item-section>
            </q-item>
          </q-list>

          <!-- ── Storage Backups ── -->
          <div class="text-subtitle2 text-weight-bold q-mt-lg q-mb-sm">
            <q-icon name="storage" class="q-mr-xs" color="blue-grey" />
            Storage Backups
          </div>
          <q-banner rounded class="bg-grey-1 q-mb-sm">
            <template v-slot:avatar><q-icon name="info" color="grey" /></template>
            <div class="text-caption">
              Storage objects are copied inside the <code>backups</code> bucket at:
              <br />
              <code>{{ storagePath }}</code>
              <br /><br />
              Browse at:&nbsp;
              <a :href="storageUrl" target="_blank" class="text-primary"
                >Supabase Storage Dashboard ↗</a
              >
            </div>
          </q-banner>

          <q-list v-if="storageArtifacts.length" bordered separator rounded>
            <q-item v-for="a in storageArtifacts" :key="a.bucket">
              <q-item-section avatar>
                <q-icon name="inventory_2" color="blue-grey" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ a.bucket }}</q-item-label>
                <q-item-label caption>
                  {{ a.objects_copied }} objects copied
                  <span v-if="a.error_count" class="text-negative">
                    · {{ a.error_count }} errors</span
                  >
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-chip dense color="blue-grey-1" text-color="blue-grey" label="Storage" />
              </q-item-section>
            </q-item>
          </q-list>
          <div v-else class="text-caption text-grey q-mt-xs">
            No storage buckets copied this run.
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, reactive, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import JSZip from 'jszip'
import { saveAs } from 'file-saver'
import PageHeader from 'components/common/PageHeader.vue'
import { supabase } from 'src/boot/supabase'

const $q = useQuasar()
const logs = ref([])
const tableLoading = ref(false)
const backupRunning = ref(false)
const activeRunId = ref('')
const artifactsDialog = ref(false)
const selectedLog = ref(null)

// Per-item download loading state  { [key]: bool }
const downloading = reactive({})

// ── Column definitions ─────────────────────────────────────────────────────────
const columns = [
  { name: 'started_at', label: 'Started', align: 'left', field: 'started_at', sortable: true },
  { name: 'mode', label: 'Mode', align: 'left', field: 'mode' },
  { name: 'status', label: 'Status', align: 'left', field: 'status' },
  { name: 'duration_ms', label: 'Duration', align: 'left', field: 'duration_ms' },
  { name: 'actions', label: 'Actions', align: 'left', field: 'actions' },
]

// ── Computed stats ─────────────────────────────────────────────────────────────
const lastRunStatus = computed(() => logs.value[0]?.status ?? null)
const lastRunAt = computed(() => logs.value[0]?.started_at ?? null)
const successRate = computed(() => {
  if (!logs.value.length) return 0
  return Math.round(
    (logs.value.filter((l) => l.status === 'success').length / logs.value.length) * 100,
  )
})
const lastDuration = computed(() => {
  const ms = logs.value[0]?.duration_ms
  return ms ? formatDuration(ms) : '—'
})

const snapshotArtifacts = computed(() =>
  (selectedLog.value?.artifacts ?? []).filter((a) => a.type === 'snapshot'),
)
const storageArtifacts = computed(() =>
  (selectedLog.value?.artifacts ?? []).filter((a) => a.type === 'storage'),
)
const storagePath = computed(() => {
  const log = selectedLog.value
  if (!log) return ''
  return `${log.started_at?.slice(0, 10)}/${log.run_id}/storage/`
})
const storageUrl = `https://supabase.com/dashboard/project/ovdheejmgchtohnjozpn/storage/buckets/backups`

// ── Helpers ────────────────────────────────────────────────────────────────────
function formatDate(iso) {
  if (!iso) return '—'
  return new Intl.DateTimeFormat('en-LK', { dateStyle: 'medium', timeStyle: 'short' }).format(
    new Date(iso),
  )
}

function formatDuration(ms) {
  if (!ms) return '—'
  if (ms < 1000) return `${ms}ms`
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`
  return `${Math.floor(ms / 60000)}m ${Math.round((ms % 60000) / 1000)}s`
}

function formatBytes(bytes) {
  if (!bytes) return '0 B'
  const k = 1024,
    sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`
}

function statusColor(s) {
  return { success: 'positive', failed: 'negative', running: 'blue', skipped: 'grey' }[s] ?? 'grey'
}
function statusIcon(s) {
  return (
    { success: 'check_circle', failed: 'error', running: 'hourglass_empty', skipped: 'skip_next' }[
      s
    ] ?? 'help'
  )
}

function storageErrMsg(err) {
  if (!err) return 'Unknown error'
  if (typeof err === 'string') return err
  return err.message || err.error || JSON.stringify(err)
}

// ── Core: fetch file bytes via signed URL ──────────────────────────────────────
async function fetchFileBytes(storagePath) {
  const { data, error } = await supabase.storage.from('backups').createSignedUrl(storagePath, 120) // 120-second window

  if (error || !data?.signedUrl) {
    throw new Error(storageErrMsg(error) || 'Could not create signed URL')
  }

  const resp = await fetch(data.signedUrl)
  if (!resp.ok) throw new Error(`HTTP ${resp.status} fetching ${storagePath}`)
  return resp.arrayBuffer()
}

// ── Core: trigger browser download of bytes ────────────────────────────────────
function triggerDownload(blob, filename) {
  saveAs(blob, filename)
}

// ── Download metadata.json ─────────────────────────────────────────────────────
async function downloadMetadata(log) {
  if (!log) return
  const key = log.run_id + '_meta'
  downloading[key] = true
  try {
    const path = `${log.started_at?.slice(0, 10)}/${log.run_id}/metadata.json`
    const bytes = await fetchFileBytes(path)
    triggerDownload(new Blob([bytes], { type: 'application/json' }), `metadata-${log.run_id}.json`)
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Download failed: ' + storageErrMsg(err) })
  } finally {
    downloading[key] = false
  }
}

// ── Download single CSV ────────────────────────────────────────────────────────
async function downloadSingleCsv(artifact) {
  const key = artifact.path
  downloading[key] = true
  try {
    const bytes = await fetchFileBytes(artifact.path)
    triggerDownload(new Blob([bytes], { type: 'text/csv' }), `${artifact.name}.csv`)
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Download failed: ' + storageErrMsg(err) })
  } finally {
    downloading[key] = false
  }
}

// ── Download ALL as ZIP ────────────────────────────────────────────────────────
// Bundles: metadata.json + all CSV snapshots → {run_id}.zip
async function downloadAllAsZip(log) {
  if (!log) return
  const key = log.run_id + '_zip'
  downloading[key] = true

  const zipFilename = `backup-${log.started_at?.slice(0, 10)}-${log.run_id}.zip`
  $q.notify({
    type: 'info',
    icon: 'archive',
    message: 'Building ZIP archive...',
    caption: 'Downloading all files, please wait',
    timeout: 0,
    position: 'top-right',
    group: key,
  })

  try {
    const zip = new JSZip()
    const runDate = log.started_at?.slice(0, 10)
    const snapshots = (log.artifacts ?? []).filter((a) => a.type === 'snapshot')

    // 1. Add metadata.json
    try {
      const metaPath = `${runDate}/${log.run_id}/metadata.json`
      const metaBytes = await fetchFileBytes(metaPath)
      zip.file('metadata.json', metaBytes)
    } catch (e) {
      console.warn('[zip] metadata.json skipped:', e.message)
    }

    // 2. Add each CSV snapshot
    const csvFolder = zip.folder('snapshots')
    for (const artifact of snapshots) {
      try {
        const bytes = await fetchFileBytes(artifact.path)
        csvFolder.file(`${artifact.name}.csv`, bytes)
        console.log(`[zip] Added ${artifact.name}.csv`)
      } catch (e) {
        console.warn(`[zip] Skipped ${artifact.name}:`, e.message)
        // Add a placeholder noting the error
        csvFolder.file(`${artifact.name}_ERROR.txt`, `Failed to download: ${e.message}`)
      }
    }

    // 3. Add a README
    const readmeContent = [
      `VisionCore ERP — System Backup`,
      `================================`,
      `Run ID    : ${log.run_id}`,
      `Date      : ${runDate}`,
      `Mode      : ${log.mode}`,
      `Duration  : ${formatDuration(log.duration_ms)}`,
      ``,
      `Contents`,
      `--------`,
      `metadata.json         — Full backup run details`,
      `snapshots/*.csv       — Data table exports`,
      ``,
      `Restore Instructions`,
      `--------------------`,
      `CSV files can be imported into any Postgres database using:`,
      `  COPY table_name FROM '/path/file.csv' CSV HEADER;`,
      ``,
      `For full Postgres point-in-time restore:`,
      `  Supabase Dashboard → Settings → Database → Backups`,
      ``,
      `Generated: ${new Date().toISOString()}`,
    ].join('\n')
    zip.file('README.txt', readmeContent)

    // 4. Generate and download
    const zipBlob = await zip.generateAsync({
      type: 'blob',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 },
    })

    triggerDownload(zipBlob, zipFilename)

    $q.notify({
      type: 'positive',
      icon: 'check_circle',
      message: 'ZIP downloaded successfully!',
      caption: `${snapshots.length} CSV files + metadata.json`,
      position: 'top-right',
      timeout: 5000,
      group: key,
    })
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: 'ZIP creation failed: ' + storageErrMsg(err),
      position: 'top-right',
      group: key,
    })
  } finally {
    downloading[key] = false
  }
}

// ── Load backup logs ───────────────────────────────────────────────────────────
async function loadLogs() {
  tableLoading.value = true
  try {
    const { data, error } = await supabase
      .from('backup_logs')
      .select('*')
      .order('started_at', { ascending: false })
      .limit(30)
    if (error) throw error
    logs.value = data ?? []
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to load backup logs: ' + err.message })
  } finally {
    tableLoading.value = false
  }
}

// ── Trigger manual backup ──────────────────────────────────────────────────────
async function triggerBackup() {
  backupRunning.value = true
  activeRunId.value = ''
  try {
    const {
      data: { session },
    } = await supabase.auth.getSession()
    if (!session) throw new Error('Not authenticated')

    $q.notify({
      type: 'info',
      icon: 'backup',
      message: 'Backup started...',
      caption: 'This may take 1–5 minutes depending on data size',
      timeout: 8000,
      position: 'top-right',
    })

    const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/backup-runner`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${session.access_token}`,
        apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({ mode: 'manual' }),
    })

    const json = await res.json()
    if (!res.ok) throw new Error(json.error ?? `HTTP ${res.status}`)

    activeRunId.value = json.run_id
    $q.notify({
      type: 'positive',
      icon: 'check_circle',
      message: 'Backup completed!',
      caption: `${json.artifacts_count} artifacts · ${formatDuration(json.duration_ms)}`,
      position: 'top-right',
      timeout: 6000,
    })

    await loadLogs()
  } catch (err) {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: 'Backup failed',
      caption: err.message,
      position: 'top-right',
      timeout: 8000,
    })
  } finally {
    backupRunning.value = false
  }
}

// ── View artifacts dialog ──────────────────────────────────────────────────────
function viewArtifacts(log) {
  selectedLog.value = log
  artifactsDialog.value = true
}

// ── Show error ─────────────────────────────────────────────────────────────────
function showError(log) {
  $q.dialog({
    title: 'Backup Error Details',
    message: log.error ?? 'Unknown error',
    dark: $q.dark.isActive,
    ok: { label: 'Close', color: 'negative' },
  })
}

onMounted(loadLogs)
</script>

<style scoped>
.run-now-card {
  border-radius: 16px !important;
  background: linear-gradient(135deg, rgba(79, 70, 229, 0.03) 0%, rgba(139, 92, 246, 0.02) 100%);
}

.stat-mini {
  border-radius: 12px !important;
  transition: all 0.15s ease;
}

.stat-mini:hover {
  transform: translateY(-2px);
}

.backup-page {
  max-width: 1400px;
  margin: 0 auto;
}
</style>

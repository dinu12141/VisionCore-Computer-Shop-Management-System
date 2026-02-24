<template>
  <!-- ╔══════════════════════════════════════════════════╗
       ║  ExportButton — VisionCore ERP                   ║
       ║  Reusable premium export dropdown component      ║
       ╚══════════════════════════════════════════════════╝ -->
  <div class="export-btn-wrapper">
    <q-btn-dropdown
      :loading="exportStore.exporting"
      :disable="disabled || !hasData || exportStore.exporting"
      color="indigo-6"
      icon="file_download"
      label="Export"
      unelevated
      no-caps
      class="export-btn"
      dropdown-icon="expand_more"
      split
      @click="openExportDialog"
    >
      <!-- Dropdown menu -->
      <q-list class="export-menu" padding>
        <!-- Section: Excel -->
        <q-item-label class="export-menu-section-label">
          <q-icon name="table_chart" size="xs" class="q-mr-xs" />
          Spreadsheet
        </q-item-label>

        <q-item
          v-for="excelOpt in resolvedExcelOptions"
          :key="excelOpt.key"
          clickable
          v-close-popup
          class="export-menu-item"
          @click="triggerExport(excelOpt.key, 'xlsx')"
        >
          <q-item-section avatar>
            <q-avatar size="32px" class="export-icon-excel">
              <q-icon name="grid_on" size="18px" />
            </q-avatar>
          </q-item-section>
          <q-item-section>
            <q-item-label class="export-item-label">{{ excelOpt.label }}</q-item-label>
            <q-item-label caption class="export-item-caption">Excel (.xlsx)</q-item-label>
          </q-item-section>
        </q-item>

        <q-separator spaced="sm" v-if="resolvedPdfOptions.length" />

        <!-- Section: PDF -->
        <q-item-label class="export-menu-section-label" v-if="resolvedPdfOptions.length">
          <q-icon name="picture_as_pdf" size="xs" class="q-mr-xs" />
          PDF Document
        </q-item-label>

        <q-item
          v-for="pdfOpt in resolvedPdfOptions"
          :key="pdfOpt.key + '_pdf'"
          clickable
          v-close-popup
          class="export-menu-item"
          @click="triggerExport(pdfOpt.key, 'pdf')"
        >
          <q-item-section avatar>
            <q-avatar size="32px" class="export-icon-pdf">
              <q-icon name="picture_as_pdf" size="18px" />
            </q-avatar>
          </q-item-section>
          <q-item-section>
            <q-item-label class="export-item-label">{{ pdfOpt.label }}</q-item-label>
            <q-item-label caption class="export-item-caption">PDF (.pdf)</q-item-label>
          </q-item-section>
        </q-item>

        <!-- Disabled state notification -->
        <q-item v-if="!hasData" disable>
          <q-item-section>
            <q-item-label caption class="text-amber-7">
              <q-icon name="info" size="xs" class="q-mr-xs" />
              No data to export
            </q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
    </q-btn-dropdown>

    <!-- Tooltip when disabled -->
    <q-tooltip v-if="!hasData" class="bg-grey-9 text-white text-caption">
      Load report data first to enable export
    </q-tooltip>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useQuasar } from 'quasar'
import { useExportStore } from 'src/stores/exportStore'

// ─── Props ────────────────────────────────────────────────────────────────────
const props = defineProps({
  /** The data array to be exported */
  data: {
    type: Array,
    default: () => [],
  },
  /**
   * Report options for Excel export.
   * Array of { key: 'item_sales', label: 'Sales by Product' }
   * key must match a key in REPORT_CONFIGS
   */
  excelOptions: {
    type: Array,
    default: () => [],
  },
  /**
   * Report options for PDF export.
   * Same format as excelOptions.
   * If empty, inherits from excelOptions.
   */
  pdfOptions: {
    type: Array,
    default: null,
  },
  /** Date range for report header */
  dateFrom: { type: String, default: '' },
  dateTo: { type: String, default: '' },
  /** Additional filters to log in audit trail */
  filters: { type: Object, default: () => ({}) },
  /** Disable button regardless of data */
  disabled: { type: Boolean, default: false },
})

// ─── Emits ────────────────────────────────────────────────────────────────────
const emit = defineEmits(['export-start', 'export-success', 'export-error'])

// ─── Setup ────────────────────────────────────────────────────────────────────
const $q = useQuasar()
const exportStore = useExportStore()

const hasData = computed(() => Array.isArray(props.data) && props.data.length > 0)

const resolvedExcelOptions = computed(() => props.excelOptions)
const resolvedPdfOptions = computed(() =>
  props.pdfOptions !== null ? props.pdfOptions : props.excelOptions,
)

// ─── Main export trigger ─────────────────────────────────────────────────────
async function triggerExport(reportKey, format) {
  if (!hasData.value || exportStore.exporting) return

  emit('export-start', { reportKey, format })

  // Capture the dismiss function returned by $q.notify
  const dismiss = $q.notify({
    type: 'ongoing',
    message: `Generating ${format.toUpperCase()} report...`,
    spinner: true,
    timeout: 0,
    position: 'bottom-right',
  })

  let success = false
  try {
    success = await exportStore.exportReport({
      reportKey,
      format,
      data: props.data,
      dateFrom: props.dateFrom,
      dateTo: props.dateTo,
      filters: props.filters,
    })
  } finally {
    // Always dismiss the spinner — even if an error is thrown
    dismiss()
  }

  if (success) {
    $q.notify({
      type: 'positive',
      message: `✅ ${format.toUpperCase()} exported successfully`,
      caption: `${props.data.length} records`,
      position: 'bottom-right',
      timeout: 3000,
      icon: 'check_circle',
    })
    emit('export-success', { reportKey, format })
  } else {
    $q.notify({
      type: 'negative',
      message: `Failed to generate ${format.toUpperCase()} report`,
      caption: exportStore.error || 'Unknown error. Check the console.',
      position: 'bottom-right',
      timeout: 5000,
      icon: 'error',
    })
    emit('export-error', { reportKey, format, error: exportStore.error })
  }
}

// ─── Main button click → default first option ─────────────────────────────────
function openExportDialog() {
  // The split button's left side triggers the first available option
  const firstOpt = props.excelOptions[0]
  if (firstOpt) {
    triggerExport(firstOpt.key, 'xlsx')
  }
}
</script>

<style scoped lang="scss">
.export-btn-wrapper {
  display: inline-flex;
  align-items: center;
}

.export-btn {
  border-radius: 10px;
  font-weight: 600;
  letter-spacing: 0.01em;
  box-shadow: 0 2px 8px rgba(99, 102, 241, 0.25);
  transition: box-shadow 0.2s ease;

  &:hover:not([disabled]) {
    box-shadow: 0 4px 16px rgba(99, 102, 241, 0.4);
  }
}

.export-menu {
  min-width: 240px;
  border-radius: 12px;
}

.export-menu-section-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  padding: 8px 16px 4px;
  opacity: 0.55;
}

.export-menu-item {
  border-radius: 8px;
  margin: 2px 8px;
  padding: 8px 10px;
  transition: background 0.15s ease;

  &:hover {
    background: rgba(99, 102, 241, 0.06);
  }
}

.export-item-label {
  font-size: 13px;
  font-weight: 600;
}

.export-item-caption {
  font-size: 11px;
  margin-top: 1px;
}

.export-icon-excel {
  background: rgba(34, 197, 94, 0.12);
  color: #16a34a;
  border-radius: 8px;
}

.export-icon-pdf {
  background: rgba(239, 68, 68, 0.12);
  color: #dc2626;
  border-radius: 8px;
}
</style>

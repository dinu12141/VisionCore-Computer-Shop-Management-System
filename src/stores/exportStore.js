/**
 * Export Store — VisionCore ERP
 * Manages report export state, audit logging, and permission control.
 */
import { defineStore } from 'pinia'
import { useAuthStore } from './auth'
import { supabase } from 'src/boot/supabase'
import { exportToExcel, exportToPDF, REPORT_CONFIGS } from 'src/services/exportService'

export const useExportStore = defineStore('export', {
  state: () => ({
    exporting: false,
    lastExportType: null,
    lastExportFormat: null,
    error: null,
  }),

  getters: {
    /**
     * Check if current user can export finance reports.
     * Finance reports require admin, manager, or finance role.
     */
    canExportFinance: () => {
      const auth = useAuthStore()
      return auth.roles.some((r) => ['admin', 'manager', 'finance'].includes(r))
    },

    /**
     * Check if current user can export sales reports.
     * Sales reports require admin or manager role.
     */
    canExportSales: () => {
      const auth = useAuthStore()
      return auth.roles.some((r) => ['admin', 'manager'].includes(r))
    },
  },

  actions: {
    /**
     * Log export activity to Supabase audit trail.
     * @private
     */
    async _logAudit({
      reportType,
      reportLabel,
      exportFormat,
      dateFrom,
      dateTo,
      filters = {},
      rowCount = 0,
    }) {
      try {
        const auth = useAuthStore()
        const companyId = auth.currentBranch?.company_id
        const branchId = auth.currentBranch?.id

        await supabase.from('export_audit_log').insert({
          user_id: auth.user?.id,
          user_email: auth.user?.email,
          user_name: auth.profile?.full_name || auth.user?.email,
          report_type: reportType,
          report_label: reportLabel,
          export_format: exportFormat,
          date_from: dateFrom || null,
          date_to: dateTo || null,
          filters: filters,
          row_count: rowCount,
          company_id: companyId || null,
          branch_id: branchId || null,
        })
      } catch (err) {
        // Audit log failure is non-critical — don't block the export
        console.warn('[ExportStore] Audit log failed:', err.message)
      }
    },

    /**
     * Master export dispatcher.
     * Resolves the REPORT_CONFIG, generates the file, and logs to audit.
     *
     * @param {Object} options
     * @param {string} options.reportKey    — Key from REPORT_CONFIGS (e.g. 'item_sales')
     * @param {string} options.format       — 'xlsx' | 'pdf'
     * @param {Array}  options.data         — The data array to export
     * @param {string} options.dateFrom     — Filter start date
     * @param {string} options.dateTo       — Filter end date
     * @param {Object} options.filters      — Any additional filters (for audit log)
     * @param {string} [options.customTitle] — Override title (optional)
     * @param {Array}  [options.customColumns] — Override columns (optional)
     */
    async exportReport({
      reportKey,
      format,
      data,
      dateFrom,
      dateTo,
      filters = {},
      customTitle,
      customColumns,
    }) {
      if (this.exporting) return
      this.exporting = true
      this.error = null

      try {
        const config = REPORT_CONFIGS[reportKey]
        if (!config) throw new Error(`Unknown report key: ${reportKey}`)

        const columns = customColumns || config.columns
        const reportTitle = customTitle || config.label
        const fileName = reportTitle
          .replace(/[/\\:?*[\]|<>"]/g, '') // strip file system forbidden chars
          .replace(/\s+/g, '_') // spaces → underscores
          .trim()
        const summaryStats = config.getSummary ? config.getSummary(data) : []

        let success = false

        if (format === 'xlsx') {
          success = await exportToExcel({
            data,
            columns,
            fileName,
            reportTitle,
            dateFrom,
            dateTo,
            summaryRows: summaryStats.map((s) => [s.label, s.value]),
          })
        } else if (format === 'pdf') {
          success = await exportToPDF({
            data,
            columns,
            fileName,
            reportTitle,
            reportType: config.category,
            dateFrom,
            dateTo,
            summaryStats,
          })
        }

        if (success) {
          this.lastExportType = reportKey
          this.lastExportFormat = format

          // Fire-and-forget audit log
          this._logAudit({
            reportType: reportKey,
            reportLabel: config.label,
            exportFormat: format,
            dateFrom,
            dateTo,
            filters,
            rowCount: data.length,
          })
        }

        return success
      } catch (err) {
        console.error('[ExportStore] Export failed:', err)
        this.error = err.message
        return false
      } finally {
        this.exporting = false
      }
    },
  },
})

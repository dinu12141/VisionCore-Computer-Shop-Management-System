/**
 * ╔══════════════════════════════════════════════════════╗
 * ║         VisionCore ERP — Report Export Service       ║
 * ║  Enterprise-grade Excel & PDF generation engine      ║
 * ╚══════════════════════════════════════════════════════╝
 *
 * Dependencies (already in package.json):
 *   xlsx          → Excel generation
 *   jspdf         → PDF generation
 *   jspdf-autotable → PDF table rendering
 *   file-saver    → Cross-browser download trigger
 */

import * as XLSX from 'xlsx'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'
import fileSaver from 'file-saver'
const { saveAs } = fileSaver

// ─── Company branding ────────────────────────────────────────────────────────
const COMPANY = {
  name: 'VisionCore ERP',
  tagline: 'Enterprise Resource Planning',
  primaryColor: '#6366F1', // indigo-500
  accentColor: '#4F46E5',
  textDark: '#0F172A',
  textMuted: '#64748B',
  borderColor: '#E2E8F0',
  successColor: '#16A34A',
  dangerColor: '#DC2626',
}

// ─── Currency formatter ───────────────────────────────────────────────────────
export const formatCurrency = (val) =>
  'LKR ' +
  (Number(val) || 0).toLocaleString('en-LK', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })

// ─── Date helpers ─────────────────────────────────────────────────────────────
export const formatDate = (val) => {
  if (!val) return ''
  return new Date(val).toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

export const formatDateTime = (val) => {
  if (!val) return ''
  return new Date(val).toLocaleString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

// ─── Type detection ───────────────────────────────────────────────────────────
const isCurrencyField = (field) =>
  /price|cost|total|amount|revenue|profit|balance|cogs|paid|outstanding|received|due/i.test(field)

const isDateField = (field) => /date|created_at|updated_at|issued_at/i.test(field)

// ─── Safe cell value resolver ─────────────────────────────────────────────────
const resolveValue = (row, col) => {
  if (typeof col.field === 'function') return col.field(row)
  return row[col.field] ?? ''
}

// ═══════════════════════════════════════════════════════════════════════════════
//  EXCEL EXPORT
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * exportToExcel — Generates a professional .xlsx file
 *
 * @param {Object} options
 * @param {Array}  options.data         — Row data array
 * @param {Array}  options.columns      — Column definitions [{name, label, field}]
 * @param {string} options.fileName     — Output file name (without extension)
 * @param {string} options.reportTitle  — Report title shown at top
 * @param {string} options.dateFrom     — Filter date from
 * @param {string} options.dateTo       — Filter date to
 * @param {Array}  options.summaryRows  — Optional summary/totals rows
 */
export async function exportToExcel({
  data = [],
  columns = [],
  fileName = 'Report',
  reportTitle = 'Report',
  dateFrom = '',
  dateTo = '',
  summaryRows = [],
}) {
  if (!data.length) return false

  const wb = XLSX.utils.book_new()

  // ── Build worksheet data ──────────────────────────────────────────────────
  const wsData = []

  // Row 1: Company name
  wsData.push([COMPANY.name])
  // Row 2: Report title
  wsData.push([reportTitle])
  // Row 3: Date range
  wsData.push([
    dateFrom && dateTo
      ? `Period: ${formatDate(dateFrom)} — ${formatDate(dateTo)}`
      : `Generated: ${formatDateTime(new Date())}`,
  ])
  // Row 4: Generated timestamp
  wsData.push([`Exported on: ${formatDateTime(new Date())}`])
  // Row 5: blank
  wsData.push([])

  // Row 6: column headers
  const headers = columns.map((c) => c.label)
  wsData.push(headers)

  // Data rows
  data.forEach((row) => {
    wsData.push(
      columns.map((col) => {
        const raw = resolveValue(row, col)
        return raw
      }),
    )
  })

  // Blank row before totals
  if (summaryRows.length) {
    wsData.push([])
    summaryRows.forEach((sr) => wsData.push(sr))
  }

  const ws = XLSX.utils.aoa_to_sheet(wsData)

  // ── Column widths ─────────────────────────────────────────────────────────
  const colWidths = columns.map((col) => {
    const maxLen = Math.max(
      (col.label || '').length,
      ...data.map((row) => String(resolveValue(row, col) ?? '').length),
    )
    return { wch: Math.min(Math.max(maxLen + 4, 12), 50) }
  })
  ws['!cols'] = colWidths

  // ── Merge cells for title rows ────────────────────────────────────────────
  const lastColIndex = columns.length - 1
  ws['!merges'] = [
    { s: { r: 0, c: 0 }, e: { r: 0, c: lastColIndex } }, // Company name
    { s: { r: 1, c: 0 }, e: { r: 1, c: lastColIndex } }, // Report title
    { s: { r: 2, c: 0 }, e: { r: 2, c: lastColIndex } }, // Period
    { s: { r: 3, c: 0 }, e: { r: 3, c: lastColIndex } }, // Export date
  ]

  // ── Freeze header row (row 6 = index 5) ──────────────────────────────────
  ws['!freeze'] = { xSplit: 0, ySplit: 6 }

  // ── Cell styling ─────────────────────────────────────────────────────────
  // Style company name (row 0)
  const cellA1 = XLSX.utils.encode_cell({ r: 0, c: 0 })
  if (!ws[cellA1]) ws[cellA1] = {}
  ws[cellA1].s = {
    font: { bold: true, sz: 16, color: { rgb: '4F46E5' } },
    alignment: { horizontal: 'center' },
  }

  // Style report title (row 1)
  const cellA2 = XLSX.utils.encode_cell({ r: 1, c: 0 })
  if (!ws[cellA2]) ws[cellA2] = {}
  ws[cellA2].s = {
    font: { bold: true, sz: 13 },
    alignment: { horizontal: 'center' },
  }

  // Style header row (row 5)
  const headerRowIdx = 5
  columns.forEach((_, ci) => {
    const cellRef = XLSX.utils.encode_cell({ r: headerRowIdx, c: ci })
    if (!ws[cellRef]) ws[cellRef] = {}
    ws[cellRef].s = {
      font: { bold: true, color: { rgb: 'FFFFFF' } },
      fill: { fgColor: { rgb: '4F46E5' } },
      border: {
        bottom: { style: 'thin', color: { rgb: 'E2E8F0' } },
      },
      alignment: { horizontal: 'center', vertical: 'center', wrapText: true },
    }
  })

  // Style data rows — alternate banding + currency right-align
  data.forEach((row, ri) => {
    const excelRow = headerRowIdx + 1 + ri
    columns.forEach((col, ci) => {
      const cellRef = XLSX.utils.encode_cell({ r: excelRow, c: ci })
      if (!ws[cellRef]) ws[cellRef] = {}
      const isEven = ri % 2 === 0
      ws[cellRef].s = {
        fill: { fgColor: { rgb: isEven ? 'F8FAFC' : 'FFFFFF' } },
        alignment: {
          horizontal: isCurrencyField(col.field || col.name) ? 'right' : 'left',
        },
        border: {
          bottom: { style: 'hair', color: { rgb: 'E2E8F0' } },
        },
      }
    })
  })

  XLSX.utils.book_append_sheet(wb, ws, reportTitle.substring(0, 31))

  // ── Write and download ────────────────────────────────────────────────────
  const wbout = XLSX.write(wb, { bookType: 'xlsx', type: 'array', cellStyles: true })
  const blob = new Blob([wbout], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
  saveAs(blob, `${fileName}_${new Date().toISOString().split('T')[0]}.xlsx`)
  return true
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PDF EXPORT
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * exportToPDF — Generates a professional A4/landscape PDF report
 *
 * @param {Object} options
 * @param {Array}  options.data         — Row data array
 * @param {Array}  options.columns      — Column definitions [{name, label, field}]
 * @param {string} options.fileName     — Output file name (without extension)
 * @param {string} options.reportTitle  — Report title shown at top
 * @param {string} options.reportType   — Category label (e.g. "Sales Report")
 * @param {string} options.dateFrom     — Filter date from
 * @param {string} options.dateTo       — Filter date to
 * @param {Array}  options.summaryStats — [{label, value}] for summary section
 * @param {boolean} options.landscape   — Force landscape for wide reports
 */
export async function exportToPDF({
  data = [],
  columns = [],
  fileName = 'Report',
  reportTitle = 'Report',
  reportType = 'Report',
  dateFrom = '',
  dateTo = '',
  summaryStats = [],
  landscape = false,
}) {
  if (!data.length) return false

  // Auto-detect landscape: >6 columns or wide currency tables
  const autoLandscape = landscape || columns.length > 6

  const doc = new jsPDF({
    orientation: autoLandscape ? 'landscape' : 'portrait',
    unit: 'mm',
    format: 'a4',
  })

  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  const margin = 14

  // ── Header background band ────────────────────────────────────────────────
  doc.setFillColor(79, 70, 229) // indigo-600
  doc.rect(0, 0, pageWidth, 42, 'F')

  // ── Company name ──────────────────────────────────────────────────────────
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(18)
  doc.text(COMPANY.name, margin, 16)

  // ── Report type pill ──────────────────────────────────────────────────────
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  doc.setTextColor(199, 210, 254) // indigo-200
  doc.text(reportType.toUpperCase(), margin, 23)

  // ── Report title ─────────────────────────────────────────────────────────
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(13)
  doc.text(reportTitle, margin, 32)

  // ── Date range (right side of header) ────────────────────────────────────
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  doc.setTextColor(199, 210, 254)
  const dateText =
    dateFrom && dateTo
      ? `Period: ${formatDate(dateFrom)} – ${formatDate(dateTo)}`
      : `Date: ${formatDate(new Date())}`
  const exportText = `Generated: ${formatDateTime(new Date())}`
  doc.text(dateText, pageWidth - margin, 26, { align: 'right' })
  doc.text(exportText, pageWidth - margin, 32, { align: 'right' })

  let currentY = 52

  // ── Summary statistics cards ──────────────────────────────────────────────
  if (summaryStats.length) {
    const cardWidth = (pageWidth - margin * 2 - (summaryStats.length - 1) * 4) / summaryStats.length
    summaryStats.forEach((stat, i) => {
      const x = margin + i * (cardWidth + 4)
      // Card background
      doc.setFillColor(248, 250, 252)
      doc.setDrawColor(226, 232, 240)
      doc.roundedRect(x, currentY, cardWidth, 16, 2, 2, 'FD')
      // Label
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(7)
      doc.setTextColor(100, 116, 139)
      doc.text(stat.label, x + cardWidth / 2, currentY + 6, { align: 'center' })
      // Value
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(9)
      doc.setTextColor(15, 23, 42)
      doc.text(String(stat.value), x + cardWidth / 2, currentY + 13, { align: 'center' })
    })
    currentY += 24
  }

  // ── Build table data ──────────────────────────────────────────────────────
  const tableHead = [columns.map((c) => c.label)]
  const tableBody = data.map((row) =>
    columns.map((col) => {
      const raw = resolveValue(row, col)
      if (isCurrencyField(col.field || col.name) && typeof raw === 'number') {
        return formatCurrency(raw)
      }
      if (isDateField(col.field || col.name) && raw) {
        return formatDate(raw)
      }
      return raw !== undefined && raw !== null ? String(raw) : ''
    }),
  )

  // ── Column styles ─────────────────────────────────────────────────────────
  const columnStyles = {}
  columns.forEach((col, i) => {
    const isCurr = isCurrencyField(col.field || col.name)
    columnStyles[i] = {
      halign: isCurr ? 'right' : col.align === 'center' ? 'center' : 'left',
    }
  })

  // ── Render table ──────────────────────────────────────────────────────────
  autoTable(doc, {
    startY: currentY,
    head: tableHead,
    body: tableBody,
    margin: { left: margin, right: margin },
    styles: {
      fontSize: 8,
      cellPadding: { top: 3, right: 4, bottom: 3, left: 4 },
      lineColor: [226, 232, 240],
      lineWidth: 0.2,
      font: 'helvetica',
      textColor: [15, 23, 42],
    },
    headStyles: {
      fillColor: [79, 70, 229],
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 8,
      halign: 'center',
    },
    alternateRowStyles: {
      fillColor: [248, 250, 252],
    },
    columnStyles,
    // Summary totals are shown in stat cards above the table (see summaryStats).
    // Page footer
    // eslint-disable-next-line no-unused-vars
    didDrawPage: (_pageData) => {
      const pg = doc.internal.getCurrentPageInfo().pageNumber
      const total = doc.internal.getNumberOfPages()

      // Footer divider
      doc.setDrawColor(226, 232, 240)
      doc.setLineWidth(0.3)
      doc.line(margin, pageHeight - 10, pageWidth - margin, pageHeight - 10)

      // Footer text
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(7)
      doc.setTextColor(100, 116, 139)
      doc.text(COMPANY.name + ' — Confidential', margin, pageHeight - 5)
      doc.text(`Page ${pg} of ${total}`, pageWidth - margin, pageHeight - 5, { align: 'right' })
      doc.text(`Exported: ${formatDateTime(new Date())}`, pageWidth / 2, pageHeight - 5, {
        align: 'center',
      })
    },
  })

  // ── Totals summary at end of last page ────────────────────────────────────
  // (summaryStats displayed already in cards above the table)

  // ── Save ──────────────────────────────────────────────────────────────────
  doc.save(`${fileName}_${new Date().toISOString().split('T')[0]}.pdf`)
  return true
}

// ═══════════════════════════════════════════════════════════════════════════════
//  REPORT CONFIGURATIONS
//  Pre-built column/summary extractors for each report type
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * getReportConfig — returns columns + summary builder for a given report type.
 * This keeps export logic decoupled from individual page components.
 */
export const REPORT_CONFIGS = {
  // ── Sales: Item Sales / Profit ───────────────────────────────────────────
  item_sales: {
    label: 'Sales by Product',
    category: 'Sales Report',
    columns: [
      { name: 'item_name', label: 'Item Description', field: 'item_name', align: 'left' },
      { name: 'qty_sold', label: 'Qty Sold', field: 'qty_sold', align: 'right' },
      { name: 'avg_cost', label: 'Cost Price', field: 'avg_unit_cost', align: 'right' },
      { name: 'avg_price', label: 'Sale Price', field: 'avg_unit_price', align: 'right' },
      { name: 'revenue', label: 'Total Sales', field: 'revenue', align: 'right' },
      { name: 'profit', label: 'Net Profit', field: 'profit', align: 'right' },
      { name: 'margin', label: 'Margin %', field: 'profit_pct', align: 'right' },
    ],
    getSummary: (data) => [
      {
        label: 'Total Items',
        value: data.length,
      },
      {
        label: 'Total Revenue',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.revenue || 0), 0)),
      },
      {
        label: 'Total Profit',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.profit || 0), 0)),
      },
      {
        label: 'Avg Margin',
        value:
          (data.reduce((s, r) => s + Number(r.profit_pct || 0), 0) / (data.length || 1)).toFixed(
            1,
          ) + '%',
      },
    ],
  },

  // ── Sales: Customer Sales ────────────────────────────────────────────────
  customer_sales: {
    label: 'Sales by Customer',
    category: 'Sales Report',
    columns: [
      { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
      { name: 'invoice_count', label: 'Invoices', field: 'invoice_count', align: 'right' },
      { name: 'revenue', label: 'Total Sales', field: 'revenue', align: 'right' },
      { name: 'balance_due', label: 'Balance Due', field: 'balance_due', align: 'right' },
    ],
    getSummary: (data) => [
      { label: 'Total Customers', value: data.length },
      {
        label: 'Total Revenue',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.revenue || 0), 0)),
      },
      {
        label: 'Total Outstanding',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.balance_due || 0), 0)),
      },
    ],
  },

  // ── Sales: Invoice Registry ───────────────────────────────────────────────
  invoice_list: {
    label: 'Invoice Registry',
    category: 'Sales Report',
    columns: [
      { name: 'invoice_no', label: 'Invoice #', field: 'invoice_no', align: 'left' },
      { name: 'invoice_date', label: 'Date', field: 'invoice_date', align: 'left' },
      { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
      { name: 'total', label: 'Grand Total', field: 'total', align: 'right' },
      { name: 'paid_amount', label: 'Paid', field: 'paid_amount', align: 'right' },
      { name: 'balance', label: 'Balance', field: 'balance', align: 'right' },
      { name: 'status', label: 'Status', field: 'status', align: 'center' },
      { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'center' },
    ],
    getSummary: (data) => [
      { label: 'Total Invoices', value: data.length },
      {
        label: 'Total Billed',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.total || 0), 0)),
      },
      {
        label: 'Total Collected',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.paid_amount || 0), 0)),
      },
      {
        label: 'Outstanding',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.balance || 0), 0)),
      },
    ],
  },

  // ── Sales: Payment Collections ────────────────────────────────────────────
  payment_summary: {
    label: 'Payment Collection Report',
    category: 'Sales Report',
    columns: [
      { name: 'payment_method', label: 'Payment Method', field: 'payment_method', align: 'left' },
      { name: 'total_received', label: 'Total Received', field: 'total_received', align: 'right' },
    ],
    getSummary: (data) => [
      {
        label: 'Total Collected',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.total_received || 0), 0)),
      },
      { label: 'Payment Methods', value: data.length },
    ],
  },

  // ── Finance: Profit Analysis ──────────────────────────────────────────────
  profit_analysis: {
    label: 'Profit & Loss by Item',
    category: 'Finance Report',
    columns: [
      { name: 'item_name', label: 'Item Description', field: 'item_name', align: 'left' },
      { name: 'qty_sold', label: 'Qty', field: 'qty_sold', align: 'right' },
      { name: 'avg_unit_cost', label: 'Cost Price', field: 'avg_unit_cost', align: 'right' },
      { name: 'avg_unit_price', label: 'Sale Price', field: 'avg_unit_price', align: 'right' },
      { name: 'revenue', label: 'Revenue', field: 'revenue', align: 'right' },
      { name: 'profit', label: 'Net Profit', field: 'profit', align: 'right' },
      { name: 'profit_pct', label: 'Margin %', field: 'profit_pct', align: 'right' },
    ],
    getSummary: (data) => [
      {
        label: 'Total Revenue',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.revenue || 0), 0)),
      },
      {
        label: 'Total Profit',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.profit || 0), 0)),
      },
      {
        label: 'Items',
        value: data.length,
      },
    ],
  },

  // ── Sales: All Invoices Overview ──────────────────────────────────────────
  sales_overview: {
    label: 'Sales Overview Report',
    category: 'Sales Report',
    columns: [
      { name: 'invoice_no', label: 'Invoice #', field: 'invoice_no', align: 'left' },
      {
        name: 'date',
        label: 'Date',
        field: (r) => r.created_at?.slice(0, 10) || '',
        align: 'left',
      },
      {
        name: 'customer',
        label: 'Customer',
        field: (r) => r.customer_snapshot?.name || 'Walk-in',
        align: 'left',
      },
      { name: 'total', label: 'Total (LKR)', field: 'total', align: 'right' },
      { name: 'paid_amount', label: 'Paid (LKR)', field: 'paid_amount', align: 'right' },
      { name: 'balance', label: 'Balance (LKR)', field: 'balance', align: 'right' },
      { name: 'payment_type', label: 'Method', field: 'payment_type', align: 'center' },
      { name: 'payment_status', label: 'Status', field: 'payment_status', align: 'center' },
    ],
    getSummary: (data) => [
      { label: 'Total Invoices', value: data.length },
      {
        label: 'Total Revenue',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.total || 0), 0)),
      },
      {
        label: 'Total Collected',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.paid_amount || 0), 0)),
      },
      {
        label: 'Outstanding',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.balance || 0), 0)),
      },
    ],
  },

  // ── Sales: By Product / Item ──────────────────────────────────────────────
  sales_items: {
    label: 'Sales by Product',
    category: 'Sales Report',
    columns: [
      { name: 'item_name', label: 'Item / Description', field: 'item_name', align: 'left' },
      { name: 'qty_sold', label: 'Qty Sold', field: 'qty_sold', align: 'right' },
      { name: 'revenue', label: 'Revenue (LKR)', field: 'revenue', align: 'right' },
    ],
    getSummary: (data) => [
      { label: 'Total Unique Items', value: data.length },
      { label: 'Total Qty Sold', value: data.reduce((s, r) => s + Number(r.qty_sold || 0), 0) },
      {
        label: 'Total Revenue',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.revenue || 0), 0)),
      },
    ],
  },

  // ── Sales: By Customer ────────────────────────────────────────────────────
  sales_customers: {
    label: 'Sales by Customer',
    category: 'Sales Report',
    columns: [
      { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
      { name: 'invoice_count', label: 'Invoices', field: 'invoice_count', align: 'right' },
      { name: 'revenue', label: 'Revenue (LKR)', field: 'revenue', align: 'right' },
      { name: 'balance', label: 'Outstanding (LKR)', field: 'balance', align: 'right' },
    ],
    getSummary: (data) => [
      { label: 'Total Customers', value: data.length },
      {
        label: 'Total Revenue',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.revenue || 0), 0)),
      },
      {
        label: 'Total Outstanding',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.balance || 0), 0)),
      },
    ],
  },

  // ── Service: Service Sales Report ────────────────────────────────────────
  service_sales: {
    label: 'Service Revenue Report',
    category: 'Service Report',
    columns: [
      { name: 'job_no', label: 'Job #', field: 'job_no', align: 'left' },
      { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
      { name: 'device_type', label: 'Device', field: 'device_type', align: 'left' },
      {
        name: 'brand',
        label: 'Brand/Model',
        field: (r) => `${r.brand || ''} ${r.model || ''}`.trim(),
        align: 'left',
      },
      { name: 'received_date', label: 'Received', field: 'received_date', align: 'left' },
      { name: 'status', label: 'Status', field: 'status', align: 'center' },
      { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'center' },
      {
        name: 'total_final_cost',
        label: 'Final Cost (LKR)',
        field: 'total_final_cost',
        align: 'right',
      },
    ],
    getSummary: (data) => {
      const total = data.reduce((s, r) => s + Number(r.total_final_cost || 0), 0)
      const paid = data
        .filter((r) => r.payment_status === 'paid')
        .reduce((s, r) => s + Number(r.total_final_cost || 0), 0)
      return [
        { label: 'Total Jobs', value: data.length },
        { label: 'Total Revenue', value: formatCurrency(total) },
        { label: 'Collected', value: formatCurrency(paid) },
        { label: 'Outstanding', value: formatCurrency(total - paid) },
      ]
    },
  },
}

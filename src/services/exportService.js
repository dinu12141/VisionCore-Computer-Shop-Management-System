/**
 * â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
 * â•‘         VisionCore ERP â€” Report Export Service       â•‘
 * â•‘  Enterprise-grade Excel & PDF generation engine      â•‘
 * â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
 *
 * Dependencies (already in package.json):
 *   xlsx          â†’ Excel generation
 *   jspdf         â†’ PDF generation
 *   jspdf-autotable â†’ PDF table rendering
 *   file-saver    â†’ Cross-browser download trigger
 */

import * as XLSX from 'xlsx'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'
import fileSaver from 'file-saver'
const { saveAs } = fileSaver

// â”€â”€â”€ Currency formatter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export const formatCurrency = (val) =>
  'LKR ' +
  (Number(val) || 0).toLocaleString('en-LK', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })

// â”€â”€â”€ Date helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€â”€ Type detection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const isCurrencyField = (field) =>
  /price|cost|total|amount|revenue|profit|balance|cogs|paid|outstanding|received|due/i.test(field)

const isDateField = (field) => /date|created_at|updated_at|issued_at/i.test(field)

// â”€â”€â”€ Safe cell value resolver â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const resolveValue = (row, col) => {
  if (typeof col.field === 'function') return col.field(row)
  return row[col.field] ?? ''
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  EXCEL EXPORT
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/**
 * exportToExcel â€” Generates a professional .xlsx file
 *
 * @param {Object} options
 * @param {Array}  options.data         â€” Row data array
 * @param {Array}  options.columns      â€” Column definitions [{name, label, field}]
 * @param {string} options.fileName     â€” Output file name (without extension)
 * @param {string} options.reportTitle  â€” Report title shown at top
 * @param {string} options.dateFrom     â€” Filter date from
 * @param {string} options.dateTo       â€” Filter date to
 * @param {Array}  options.summaryRows  â€” Optional summary/totals rows
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

  // â”€â”€ Build worksheet data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const wsData = []

  // Row 1: Company name
  wsData.push(['Vision Computers'])
  // Row 2: Report title
  wsData.push([reportTitle])
  // Row 3: Date range
  wsData.push([
    dateFrom && dateTo
      ? `Period: ${formatDate(dateFrom)} â€” ${formatDate(dateTo)}`
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

  // â”€â”€ Column widths â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const colWidths = columns.map((col) => {
    const maxLen = Math.max(
      (col.label || '').length,
      ...data.map((row) => String(resolveValue(row, col) ?? '').length),
    )
    return { wch: Math.min(Math.max(maxLen + 4, 12), 50) }
  })
  ws['!cols'] = colWidths

  // â”€â”€ Merge cells for title rows â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const lastColIndex = columns.length - 1
  ws['!merges'] = [
    { s: { r: 0, c: 0 }, e: { r: 0, c: lastColIndex } }, // Company name
    { s: { r: 1, c: 0 }, e: { r: 1, c: lastColIndex } }, // Report title
    { s: { r: 2, c: 0 }, e: { r: 2, c: lastColIndex } }, // Period
    { s: { r: 3, c: 0 }, e: { r: 3, c: lastColIndex } }, // Export date
  ]

  // â”€â”€ Freeze header row (row 6 = index 5) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  ws['!freeze'] = { xSplit: 0, ySplit: 6 }

  // â”€â”€ Cell styling â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // Style data rows â€” alternate banding + currency right-align
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

  // Sanitize sheet name - only allow safe characters (whitelist approach)
  const safeSheetName =
    (reportTitle || 'Report')
      .split('')
      .filter((ch) => ![':', '/', '\\', '?', '*', '[', ']', '|', '"', '<', '>'].includes(ch))
      .join('')
      .replace(/\s+/g, ' ')
      .trim()
      .substring(0, 31) || 'Report'

  XLSX.utils.book_append_sheet(wb, ws, safeSheetName)

  // â”€â”€ Write and download â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const wbout = XLSX.write(wb, { bookType: 'xlsx', type: 'array', cellStyles: true })
  const blob = new Blob([wbout], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
  saveAs(blob, `${fileName}_${new Date().toISOString().split('T')[0]}.xlsx`)
  return true
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  PDF EXPORT
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/**
 * exportToPDF â€” Generates a professional A4/landscape PDF report
 *
 * @param {Object} options
 * @param {Array}  options.data         â€” Row data array
 * @param {Array}  options.columns      â€” Column definitions [{name, label, field}]
 * @param {string} options.fileName     â€” Output file name (without extension)
 * @param {string} options.reportTitle  â€” Report title shown at top
 * @param {string} options.reportType   â€” Category label (e.g. "Sales Report")
 * @param {string} options.dateFrom     â€” Filter date from
 * @param {string} options.dateTo       â€” Filter date to
 * @param {Array}  options.summaryStats â€” [{label, value}] for summary section
 * @param {boolean} options.landscape   â€” Force landscape for wide reports
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

  // â”€â”€ Load logo as base64 (canvas trick â€” works in browser) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  async function loadLogoBase64(src) {
    try {
      return await new Promise((resolve, reject) => {
        const img = new Image()
        img.crossOrigin = 'anonymous'
        img.onload = () => {
          const canvas = document.createElement('canvas')
          canvas.width = img.naturalWidth
          canvas.height = img.naturalHeight
          const ctx = canvas.getContext('2d')
          ctx.drawImage(img, 0, 0)
          resolve(canvas.toDataURL('image/png'))
        }
        img.onerror = () => reject(new Error('Logo load failed'))
        img.src = src
      })
    } catch {
      return null
    }
  }

  const logoBase64 = await loadLogoBase64('/logo.png')

  // Auto-detect landscape: >6 columns
  const autoLandscape = landscape || columns.length > 6

  const doc = new jsPDF({
    orientation: autoLandscape ? 'landscape' : 'portrait',
    unit: 'mm',
    format: 'a4',
  })

  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  const margin = 14

  // Logo dimensions inside header
  const logoH = 32 // height in mm
  const logoW = 32 // width in mm (square logo)
  const logoX = pageWidth - margin - logoW
  const logoY = 5

  // â”€â”€ Header background band â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  doc.setFillColor(79, 70, 229) // indigo-600
  doc.rect(0, 0, pageWidth, 42, 'F')

  // â”€â”€ Logo (top-right) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (logoBase64) {
    doc.addImage(logoBase64, 'PNG', logoX, logoY, logoW, logoH)
  }

  // â”€â”€ Company name â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(18)
  doc.text('Vision Computers', margin, 16)

  // â”€â”€ Report type pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  doc.setTextColor(199, 210, 254) // indigo-200
  doc.text(reportType.toUpperCase(), margin, 23)

  // â”€â”€ Report title â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(13)
  doc.text(reportTitle, margin, 32)

  // â”€â”€ Date range (right side of header â€” shifted left of logo) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  doc.setTextColor(199, 210, 254)
  const dateText =
    dateFrom && dateTo
      ? `Period: ${formatDate(dateFrom)} â€“ ${formatDate(dateTo)}`
      : `Date: ${formatDate(new Date())}`
  const exportText = `Generated: ${formatDateTime(new Date())}`
  const textRightEdge = logoBase64 ? logoX - 3 : pageWidth - margin
  doc.text(dateText, textRightEdge, 26, { align: 'right' })
  doc.text(exportText, textRightEdge, 32, { align: 'right' })

  let currentY = 52

  // â”€â”€ Summary statistics cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (summaryStats.length) {
    const cardWidth = (pageWidth - margin * 2 - (summaryStats.length - 1) * 4) / summaryStats.length
    summaryStats.forEach((stat, i) => {
      const x = margin + i * (cardWidth + 4)
      doc.setFillColor(248, 250, 252)
      doc.setDrawColor(226, 232, 240)
      doc.roundedRect(x, currentY, cardWidth, 16, 2, 2, 'FD')
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(7)
      doc.setTextColor(100, 116, 139)
      doc.text(stat.label, x + cardWidth / 2, currentY + 6, { align: 'center' })
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(9)
      doc.setTextColor(15, 23, 42)
      doc.text(String(stat.value), x + cardWidth / 2, currentY + 13, { align: 'center' })
    })
    currentY += 24
  }

  // â”€â”€ Build table data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Column styles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const columnStyles = {}
  columns.forEach((col, i) => {
    const isCurr = isCurrencyField(col.field || col.name)
    columnStyles[i] = {
      halign: isCurr ? 'right' : col.align === 'center' ? 'center' : 'left',
    }
  })

  // â”€â”€ Render table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    // eslint-disable-next-line no-unused-vars
    didDrawPage: (_pageData) => {
      const pg = doc.internal.getCurrentPageInfo().pageNumber
      const total = doc.internal.getNumberOfPages()

      // Re-draw header band on every page after the first
      if (pg > 1) {
        doc.setFillColor(79, 70, 229)
        doc.rect(0, 0, pageWidth, 42, 'F')
        if (logoBase64) doc.addImage(logoBase64, 'PNG', logoX, logoY, logoW, logoH)
        doc.setTextColor(255, 255, 255)
        doc.setFont('helvetica', 'bold')
        doc.setFontSize(18)
        doc.text('Vision Computers', margin, 16)
        doc.setFont('helvetica', 'normal')
        doc.setFontSize(8)
        doc.setTextColor(199, 210, 254)
        doc.text(reportType.toUpperCase(), margin, 23)
        doc.setTextColor(255, 255, 255)
        doc.setFont('helvetica', 'bold')
        doc.setFontSize(13)
        doc.text(reportTitle, margin, 32)
      }

      // Footer divider
      doc.setDrawColor(226, 232, 240)
      doc.setLineWidth(0.3)
      doc.line(margin, pageHeight - 10, pageWidth - margin, pageHeight - 10)
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(7)
      doc.setTextColor(100, 116, 139)
      doc.text('Vision Computers â€” Confidential', margin, pageHeight - 5)
      doc.text(`Page ${pg} of ${total}`, pageWidth - margin, pageHeight - 5, { align: 'right' })
      doc.text(`Exported: ${formatDateTime(new Date())}`, pageWidth / 2, pageHeight - 5, {
        align: 'center',
      })
    },
  })

  // â”€â”€ Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  doc.save(`${fileName}_${new Date().toISOString().split('T')[0]}.pdf`)
  return true
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  REPORT CONFIGURATIONS
//  Pre-built column/summary extractors for each report type
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/**
 * getReportConfig â€” returns columns + summary builder for a given report type.
 * This keeps export logic decoupled from individual page components.
 */
export const REPORT_CONFIGS = {
  // â”€â”€ Sales: Item Sales / Profit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Sales: Customer Sales â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Sales: Invoice Registry â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Sales: Payment Collections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Finance: Profit Analysis â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Sales: All Invoices Overview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Sales: By Product / Item â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Sales: By Customer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Service: Service Sales Report â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Inventory: Supplier List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // Service: Full Detailed Report
  service_full_report: {
    label: 'Service Full Detail Report',
    category: 'Service Report',
    columns: [
      { name: 'job_no', label: 'Job #', field: 'job_no', align: 'left' },
      { name: 'received_date', label: 'Received Date', field: 'received_date', align: 'left' },
      {
        name: 'completion_date',
        label: 'Completion Date',
        field: 'completion_date',
        align: 'left',
      },
      { name: 'customer_name', label: 'Customer Name', field: 'customer_name', align: 'left' },
      { name: 'customer_phone', label: 'Phone', field: 'customer_phone', align: 'left' },
      { name: 'device_type', label: 'Device Type', field: 'device_type', align: 'left' },
      {
        name: 'brand_model',
        label: 'Brand / Model',
        field: (r) => `${r.brand || ''} ${r.model || ''}`.trim(),
        align: 'left',
      },
      { name: 'serial_no', label: 'Serial No', field: 'serial_no', align: 'left' },
      {
        name: 'issue_reported',
        label: 'Issue Reported',
        field: 'issue_reported_by_customer',
        align: 'left',
      },
      {
        name: 'inspection_notes',
        label: 'Inspection Notes',
        field: 'inspection_notes',
        align: 'left',
      },
      { name: 'technician', label: 'Technician', field: 'technician_name', align: 'left' },
      { name: 'warranty_days', label: 'Warranty (Days)', field: 'warranty_days', align: 'center' },
      { name: 'status', label: 'Job Status', field: 'status', align: 'center' },
      { name: 'payment_status', label: 'Payment Status', field: 'payment_status', align: 'center' },
      {
        name: 'total_estimated_cost',
        label: 'Estimated Cost (LKR)',
        field: 'total_estimated_cost',
        align: 'right',
      },
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
      const completed = data.filter((r) => r.status === 'completed').length
      const pending = data.filter((r) => ['pending', 'in_progress'].includes(r.status)).length
      return [
        { label: 'Total Jobs', value: data.length },
        { label: 'Completed', value: completed },
        { label: 'Pending / In Progress', value: pending },
        { label: 'Total Revenue', value: formatCurrency(total) },
        { label: 'Collected', value: formatCurrency(paid) },
        { label: 'Outstanding', value: formatCurrency(total - paid) },
      ]
    },
  },

  supplier_list: {
    label: 'Supplier Directory',
    category: 'Inventory Report',
    columns: [
      { name: 'code', label: 'Code', field: 'code', align: 'left' },
      { name: 'name', label: 'Supplier Name', field: 'name', align: 'left' },
      { name: 'contact_person', label: 'Contact Person', field: 'contact_person', align: 'left' },
      { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
      { name: 'email', label: 'Email', field: 'email', align: 'left' },
      { name: 'address', label: 'Address', field: 'address', align: 'left' },
      { name: 'tax_id', label: 'Tax ID / VAT', field: 'tax_id', align: 'left' },
      {
        name: 'is_active',
        label: 'Status',
        field: (r) => (r.is_active ? 'Active' : 'Inactive'),
        align: 'center',
      },
    ],
    getSummary: (data) => [
      { label: 'Total Suppliers', value: data.length },
      { label: 'Active', value: data.filter((r) => r.is_active).length },
      { label: 'Inactive', value: data.filter((r) => !r.is_active).length },
    ],
  },

  // â”€â”€ Inventory: Item / Product List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  item_list: {
    label: 'Product / Item Registry',
    category: 'Inventory Report',
    columns: [
      { name: 'code', label: 'Item Code', field: 'code', align: 'left' },
      { name: 'name', label: 'Product Name', field: 'name', align: 'left' },
      { name: 'category_name', label: 'Category', field: 'category_name', align: 'left' },
      { name: 'brand', label: 'Brand', field: 'brand', align: 'left' },
      { name: 'uom_code', label: 'UOM', field: 'uom_code', align: 'center' },
      { name: 'total_qty', label: 'Stock Qty', field: 'total_qty', align: 'right' },
      { name: 'reorder_level', label: 'Reorder Level', field: 'reorder_level', align: 'right' },
      { name: 'cost_price', label: 'Cost Price', field: 'cost_price', align: 'right' },
      { name: 'sale_price', label: 'Sale Price', field: 'sale_price', align: 'right' },
      {
        name: 'is_active',
        label: 'Status',
        field: (r) => (r.is_active ? 'Active' : 'Inactive'),
        align: 'center',
      },
    ],
    getSummary: (data) => [
      { label: 'Total Items', value: data.length },
      { label: 'Active Items', value: data.filter((r) => r.is_active).length },
      {
        label: 'Total Stock Value',
        value: formatCurrency(
          data.reduce((s, r) => s + Number(r.total_qty || 0) * Number(r.cost_price || 0), 0),
        ),
      },
      {
        label: 'Low Stock Items',
        value: data.filter(
          (r) => Number(r.total_qty || 0) <= Number(r.reorder_level || 0) && r.is_active,
        ).length,
      },
    ],
  },

  // â”€â”€ Inventory: Low Stock Items â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  item_list_low_stock: {
    label: 'Low Stock Alert Report',
    category: 'Inventory Report',
    columns: [
      { name: 'code', label: 'Item Code', field: 'code', align: 'left' },
      { name: 'name', label: 'Product Name', field: 'name', align: 'left' },
      { name: 'category_name', label: 'Category', field: 'category_name', align: 'left' },
      { name: 'brand', label: 'Brand', field: 'brand', align: 'left' },
      { name: 'total_qty', label: 'Current Stock', field: 'total_qty', align: 'right' },
      { name: 'reorder_level', label: 'Reorder Level', field: 'reorder_level', align: 'right' },
      {
        name: 'shortage',
        label: 'Shortage',
        field: (r) => Math.max(0, Number(r.reorder_level || 0) - Number(r.total_qty || 0)),
        align: 'right',
      },
      { name: 'supplier_name', label: 'Supplier', field: 'supplier_name', align: 'left' },
    ],
    getSummary: (data) => [
      { label: 'Low Stock Items', value: data.length },
      { label: 'Out of Stock', value: data.filter((r) => Number(r.total_qty || 0) <= 0).length },
    ],
  },

  // â”€â”€ Inventory: Documents Registry â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  inventory_docs: {
    label: 'Inventory Documents Summary',
    category: 'Inventory Report',
    columns: [
      { name: 'doc_type', label: 'Type', field: 'doc_type', align: 'left' },
      { name: 'doc_number', label: 'Doc #', field: 'doc_number', align: 'left' },
      { name: 'doc_date', label: 'Date', field: 'doc_date', align: 'center' },
      { name: 'warehouse_name', label: 'Warehouse', field: 'warehouse_name', align: 'left' },
      {
        name: 'supplier_name',
        label: 'Supplier/Target',
        field: (r) => r.supplier_name || r.target_warehouse_name || '-',
        align: 'left',
      },
      { name: 'total_qty', label: 'Qty', field: 'total_qty', align: 'right' },
      { name: 'total_cost', label: 'Total Cost', field: 'total_cost', align: 'right' },
      { name: 'status', label: 'Status', field: 'status', align: 'center' },
      { name: 'created_by_name', label: 'Created By', field: 'created_by_name', align: 'left' },
    ],
    getSummary: (data) => [
      { label: 'Total Documents', value: data.length },
      { label: 'Posted', value: data.filter((r) => r.status === 'posted').length },
      { label: 'Draft', value: data.filter((r) => r.status === 'draft').length },
      {
        label: 'Total Cost',
        value: formatCurrency(data.reduce((s, r) => s + Number(r.total_cost || 0), 0)),
      },
    ],
  },
}

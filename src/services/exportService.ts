import * as XLSX from 'xlsx'
import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'

/**
 * Export Document to Excel (.xlsx)
 */
export function exportToExcel(document: any, lines: any[]) {
  const data = (lines || []).map((l, index) => ({
    '#': index + 1,
    'Item Description': l.item_name,
    'Item Code': l.item_code,
    Quantity: l.quantity,
    UOM: l.uom_code,
    'Unit Cost': l.unit_cost,
    'Total Value': l.quantity * l.unit_cost,
    Warehouse: document.warehouse_name,
  }))

  const ws = XLSX.utils.json_to_sheet(data)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'InventoryData')

  const fileName = `${document.doc_type}_${document.doc_number}.xlsx`
  XLSX.writeFile(wb, fileName)
}

/**
 * Export Document to PDF
 * Note: Uses jsPDF with autotable
 */
export function exportToPDF(document: any, lines: any[]) {
  try {
    const doc = new jsPDF()

    // Header
    doc.setFontSize(22)
    doc.setTextColor(25, 118, 210) // Quasar Primary Blue
    doc.text('VisionCore ERP Solutions', 14, 22)

    doc.setFontSize(14)
    doc.setTextColor(0)
    doc.text(`${document.doc_type} Document: ${document.doc_number}`, 14, 32)

    doc.setFontSize(10)
    doc.setTextColor(100)
    doc.text(`Date: ${document.doc_date || 'N/A'}`, 14, 40)
    doc.text(`Warehouse: ${document.warehouse_name || 'N/A'}`, 14, 45)
    if (document.supplier_name) doc.text(`Supplier: ${document.supplier_name}`, 14, 50)

    const tableRows = (lines || []).map((l, i) => [
      i + 1,
      l.item_name || 'N/A',
      `${l.quantity} ${l.uom_code || ''}`,
      (l.unit_cost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 }),
      ((l.quantity || 0) * (l.unit_cost || 0)).toLocaleString(undefined, {
        minimumFractionDigits: 2,
      }),
    ])

    autoTable(doc, {
      startY: 60,
      head: [['#', 'Item Description', 'Quantity', 'Unit Cost', 'Total']],
      body: tableRows,
      theme: 'grid',
      headStyles: { fillColor: [25, 118, 210], halign: 'center' },
      columnStyles: {
        2: { halign: 'right' },
        3: { halign: 'right' },
        4: { halign: 'right' },
      },
    })

    const fileName = `${document.doc_type}_${document.doc_number}.pdf`
    doc.save(fileName)
  } catch (err) {
    console.error('Fatal PDF Error:', err)
    throw err
  }
}

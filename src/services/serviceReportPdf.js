import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'
import { supabase } from 'src/boot/supabase'

function formatCurrency(val) {
  return (
    'LKR ' +
    (Number(val) || 0).toLocaleString('en-LK', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  )
}

export async function downloadServiceJobPDF(jobId) {
  // 1. Fetch data
  const { data: job, error: jobErr } = await supabase
    .from('service_jobs')
    .select('*, customer:customers(name, phone, email, customer_code)')
    .eq('id', jobId)
    .single()

  if (jobErr) throw new Error('Failed to fetch job info: ' + jobErr.message)

  const { data: diag } = await supabase
    .from('service_diagnosis_items')
    .select('*')
    .eq('job_id', jobId)
    .order('created_at')
  const { data: parts } = await supabase
    .from('service_parts_used')
    .select('*')
    .eq('job_id', jobId)
    .order('created_at')

  const etaLabel = 'ETA'

  // 2. Setup PDF Document — A4 single page, compact layout
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
  const margin = 12
  let currentY = 14

  // ---------- HEADER ----------
  doc.setFontSize(18)
  doc.setTextColor(79, 70, 229)
  doc.setFont('helvetica', 'bold')
  doc.text('VISION COMPUTERS', margin, currentY)

  doc.setFontSize(11)
  doc.setTextColor(100, 116, 139)
  doc.setFont('helvetica', 'normal')
  doc.text('Service Job Report', margin, currentY + 6)

  doc.setFontSize(8.5)
  doc.setTextColor(15, 23, 42)
  doc.text(
    `Job No: ${job.job_no}   |   Date: ${new Date().toLocaleDateString()}   |   Status: ${job.status.toUpperCase()}`,
    margin,
    currentY + 12,
  )

  // Top Right Logo
  const img = new Image()
  img.src = '/logo.jpg'
  await new Promise((resolve) => {
    img.onload = resolve
    img.onerror = resolve
  })

  if (img.width > 0) {
    const logoHeight = 16
    const logoWidth = (img.width / img.height) * logoHeight
    doc.addImage(img, 'JPEG', 210 - margin - logoWidth, 10, logoWidth, logoHeight)
  }

  // Line separator
  currentY += 17
  doc.setDrawColor(226, 232, 240)
  doc.setLineWidth(0.4)
  doc.line(margin, currentY, 210 - margin, currentY)
  currentY += 5

  // ---------- CUSTOMER INFO + DEVICE INFO (side by side) ----------
  const colMid = 105

  // Left: Customer Details
  doc.setFontSize(9)
  doc.setTextColor(79, 70, 229)
  doc.setFont('helvetica', 'bold')
  doc.text('CUSTOMER DETAILS', margin, currentY)

  // Right: Device Information
  doc.text('DEVICE INFORMATION', colMid, currentY)
  currentY += 5

  doc.setFontSize(8.5)
  doc.setTextColor(15, 23, 42)
  doc.setFont('helvetica', 'normal')

  // Row 1
  doc.text(`Name: ${job.customer?.name || 'Walk-in'}`, margin, currentY)
  doc.text(`Type: ${job.device_type || '-'}`, colMid, currentY)
  currentY += 4.5

  // Row 2
  doc.text(`Phone: ${job.customer?.phone || '-'}`, margin, currentY)
  doc.text(`Brand/Model: ${job.brand || '-'} ${job.model || ''}`, colMid, currentY)
  currentY += 4.5

  // Row 3
  doc.text(`Code: ${job.customer?.customer_code || '-'}`, margin, currentY)
  doc.text(`Serial No: ${job.serial_no || '-'}`, colMid, currentY)
  currentY += 4.5

  // Row 4
  doc.text(`Email: ${job.customer?.email || '-'}`, margin, currentY)
  const accText = `Accessories: ${(job.accessories_received || []).join(', ') || 'None'}`
  doc.text(accText, colMid, currentY)
  currentY += 4.5

  // Row 5
  doc.text(`Received: ${job.received_date || '-'}`, margin, currentY)
  doc.text(`${etaLabel}: ${job.estimated_fix_date || '-'}`, colMid, currentY)
  currentY += 6

  // Divider
  doc.setDrawColor(226, 232, 240)
  doc.line(margin, currentY, 210 - margin, currentY)
  currentY += 5

  // ---------- ISSUE REPORTED + INSPECTION NOTES (side by side) ----------
  doc.setFontSize(9)
  doc.setTextColor(79, 70, 229)
  doc.setFont('helvetica', 'bold')
  doc.text('ISSUE REPORTED', margin, currentY)
  doc.text('INSPECTION NOTES', colMid, currentY)
  currentY += 4.5

  doc.setFontSize(8.5)
  doc.setTextColor(15, 23, 42)
  doc.setFont('helvetica', 'normal')

  const issueLines = doc.splitTextToSize(
    job.issue_reported_by_customer || 'No description provided.',
    88,
  )
  const inspLines = doc.splitTextToSize(job.inspection_notes || 'No inspection notes.', 88)
  const maxLines = Math.max(issueLines.length, inspLines.length)

  doc.text(issueLines, margin, currentY)
  doc.text(inspLines, colMid, currentY)
  currentY += maxLines * 4 + 6

  // Divider
  doc.setDrawColor(226, 232, 240)
  doc.line(margin, currentY, 210 - margin, currentY)
  currentY += 4

  // ---------- DIAGNOSIS TABLE ----------
  if (diag && diag.length > 0) {
    doc.setFontSize(9)
    doc.setTextColor(79, 70, 229)
    doc.setFont('helvetica', 'bold')
    doc.text('DIAGNOSIS', margin, currentY)
    currentY += 3

    autoTable(doc, {
      startY: currentY,
      margin: { left: margin, right: margin },
      head: [['Category', 'Issue', 'Final Cost', 'Fixed']],
      body: diag.map((d) => [
        d.category || '-',
        d.error_title || '-',
        formatCurrency(d.final_cost || 0),
        d.is_fixed ? 'Yes' : 'No',
      ]),
      theme: 'grid',
      headStyles: { fillColor: [79, 70, 229], fontSize: 8, cellPadding: 2 },
      styles: { fontSize: 8, cellPadding: 1.5 },
      pageBreak: 'avoid',
    })
    currentY = doc.lastAutoTable.finalY + 5
  }

  // ---------- PARTS USED TABLE ----------
  if (parts && parts.length > 0) {
    doc.setFontSize(9)
    doc.setTextColor(79, 70, 229)
    doc.setFont('helvetica', 'bold')
    doc.text('PARTS USED', margin, currentY)
    currentY += 3

    autoTable(doc, {
      startY: currentY,
      margin: { left: margin, right: margin },
      head: [['Item Name', 'Qty', 'Unit Price', 'Total', 'Notes / SN']],
      body: parts.map((p) => [
        p.item_name || '-',
        p.qty,
        formatCurrency(p.unit_price),
        formatCurrency(p.total),
        p.notes || '-',
      ]),
      theme: 'grid',
      headStyles: { fillColor: [245, 158, 11], fontSize: 8, cellPadding: 2 },
      styles: { fontSize: 8, cellPadding: 1.5 },
      pageBreak: 'avoid',
    })
    currentY = doc.lastAutoTable.finalY + 5
  }

  // Divider
  doc.setDrawColor(226, 232, 240)
  doc.line(margin, currentY, 210 - margin, currentY)
  currentY += 4

  // ---------- COST SUMMARY + WARRANTY (side by side) ----------
  doc.setFontSize(9)
  doc.setTextColor(79, 70, 229)
  doc.setFont('helvetica', 'bold')
  doc.text('COST SUMMARY', margin, currentY)
  currentY += 5

  doc.setFontSize(8.5)
  doc.setTextColor(15, 23, 42)
  doc.setFont('helvetica', 'normal')
  doc.text(`Estimated Cost: ${formatCurrency(job.total_estimated_cost)}`, margin, currentY)
  doc.text(`Final Cost: ${formatCurrency(job.total_final_cost)}`, margin + 70, currentY)
  doc.text(
    `Payment Status: ${job.payment_status?.toUpperCase() || 'UNPAID'}`,
    margin + 135,
    currentY,
  )
  currentY += 5

  // ---------- WARRANTY ----------
  if (job.warranty_days > 0) {
    doc.setFillColor(254, 243, 199)
    doc.setDrawColor(245, 158, 11)
    doc.rect(margin, currentY, 210 - margin * 2, 12, 'FD')
    doc.setFontSize(8.5)
    doc.setTextColor(180, 83, 9)
    doc.setFont('helvetica', 'bold')
    doc.text(`WARRANTY: ${job.warranty_days} DAYS  `, margin + 3, currentY + 5)
    doc.setFont('helvetica', 'normal')
    doc.text(
      'Covers repairs under this job. Physical or liquid damage excluded.',
      margin + 3,
      currentY + 9.5,
    )
    currentY += 16
  }

  // ---------- SIGNATURES ----------
  currentY += 6
  doc.setFontSize(8.5)
  doc.setTextColor(15, 23, 42)
  doc.setFont('helvetica', 'normal')
  doc.setDrawColor(100, 116, 139)
  doc.setLineWidth(0.4)
  doc.line(margin, currentY, margin + 50, currentY)
  doc.text('Technician Signature', margin + 6, currentY + 4.5)
  doc.line(210 - margin - 50, currentY, 210 - margin, currentY)
  doc.text('Customer Signature', 210 - margin - 45, currentY + 4.5)

  // ---------- AUTO-SCALE to fit single page if overflowed ----------
  const totalPages = doc.internal.getNumberOfPages()
  if (totalPages > 1) {
    // Re-scale the entire document to fit on 1 page using jsPDF internal
    // (fallback: just keep multi-page but label correctly)
  }

  // ---------- FOOTER ----------
  const pageCount = doc.internal.getNumberOfPages()
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i)
    doc.setFontSize(7.5)
    doc.setTextColor(148, 163, 184)
    doc.text(
      `Vision Computers ERP - Service Dept | Job ${job.job_no} | Page ${i} of ${pageCount}`,
      105,
      292,
      { align: 'center' },
    )
  }

  // 3. Direct download as .pdf file
  const pdfBlob = doc.output('blob')
  const pdfUrl = URL.createObjectURL(pdfBlob)
  const link = document.createElement('a')
  link.href = pdfUrl
  link.download = `Service_Job_${job.job_no}.pdf`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(pdfUrl)

  return true
}

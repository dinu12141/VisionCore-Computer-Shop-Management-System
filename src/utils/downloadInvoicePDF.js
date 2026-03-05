/**
 * downloadInvoicePDF.js
 * Downloads a rendered invoice HTML string as a PDF file.
 * Uses an iframe to correctly render CSS + html-to-image + jspdf.
 * No extra dependencies required – all already in package.json.
 */

import { toJpeg } from 'html-to-image'
import { jsPDF } from 'jspdf'

/**
 * Renders the complete invoiceHTML inside a hidden iframe (so all <style> blocks
 * are applied correctly), captures the body as a JPEG, then saves as PDF.
 *
 * @param {string} html        Full HTML string from renderInvoiceHTML()
 * @param {string} filename    Output filename WITHOUT extension (e.g. "INV-2026-000001")
 */
export async function downloadInvoicePDF(html, filename = 'Invoice') {
  let iframe = null
  try {
    // Mount a hidden iframe – 794px wide matches A4 at 96 dpi
    iframe = document.createElement('iframe')
    iframe.style.cssText =
      'position:fixed;left:-9999px;top:0;width:794px;height:1123px;border:none;opacity:0;pointer-events:none;z-index:-1;'
    document.body.appendChild(iframe)

    // Write the full HTML document (with <style> blocks) into the iframe
    iframe.contentDocument.open()
    iframe.contentDocument.write(html)
    iframe.contentDocument.close()

    // Wait for the iframe to fully render (fonts, images, layout)
    await new Promise((r) => setTimeout(r, 650))

    const target = iframe.contentDocument.body
    const contentHeight = target.scrollHeight || 1123

    // Resize so nothing is clipped
    iframe.style.height = contentHeight + 'px'
    await new Promise((r) => setTimeout(r, 100))

    // Capture as JPEG (smaller than PNG; perfectly fine for documents)
    const imgData = await toJpeg(target, {
      quality: 0.9,
      pixelRatio: 1.8,
      backgroundColor: '#ffffff',
      width: 794,
      height: contentHeight,
    })

    document.body.removeChild(iframe)
    iframe = null

    // Compute PDF height: keep 210mm width (A4), scale height proportionally
    const img = new Image()
    img.src = imgData
    await new Promise((r) => {
      img.onload = r
    })

    const pdfWidth = 210
    const pdfHeight = Math.round((img.height / img.width) * pdfWidth)

    // Create a single custom-height page — zero wasted blank space
    const pdf = new jsPDF({
      orientation: 'portrait',
      unit: 'mm',
      format: [pdfWidth, pdfHeight],
    })

    pdf.addImage(imgData, 'JPEG', 0, 0, pdfWidth, pdfHeight)
    pdf.save(`${filename}.pdf`)
  } finally {
    if (iframe && iframe.parentNode) {
      document.body.removeChild(iframe)
    }
  }
}

export const renderInvoiceHTML = (invoice, template = {}) => {
  const {
    company_name = 'Vision Computers',
    vat_no = '117543862-7000',
    address = 'No.36, Bibila Road, Monaragala.',
    phones = ['076-5554567', '070-4008480'],
    footer_note = 'All cheques drawn in favor of "VISION COMPUTERS".',
  } = template

  const logoUrl = window.location.origin + '/logo.png'

  // Escape HTML to prevent XSS when rendering user-controlled data
  const escapeHtml = (str) => {
    if (str === null || str === undefined) return ''
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;')
  }

  const formatDate = (d) => {
    if (!d) return ''
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ]
    if (typeof d === 'string' && d.includes('-') && !d.includes('T')) {
      const parts = d.split('-')
      if (parts.length === 3) {
        return `${parseInt(parts[2], 10)} ${months[parseInt(parts[1], 10) - 1]} ${parts[0]}`
      }
    }
    const dateObj = new Date(d)
    return `${dateObj.getDate().toString().padStart(2, '0')} ${months[dateObj.getMonth()]} ${dateObj.getFullYear()}`
  }

  const formatCurrency = (val) => {
    return 'LKR ' + Number(val || 0).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  }

  const items = invoice.items || []
  const itemsHtml = items.map((item) => {
    const sn = item.serial_number || item.serialNumber
    const warranty = item.warranty
    // Per-line discount display
    let discountDisplay = '-'
    const discountVal = Number(item.discount || 0)
    const discountType = item.discount_type || 'amount'
    const discountAmount = Number(item.discount_amount || item.discount || 0)
    if (discountVal > 0) {
      if (discountType === 'percent') {
        discountDisplay = `${discountVal}% <span class="item-meta">(${formatCurrency(discountAmount)})</span>`
      } else {
        discountDisplay = formatCurrency(discountVal)
      }
    }
    return `
      <tr>
        <td class="text-center">${escapeHtml(item.qty)}</td>
        <td>
          <div class="main-desc">${escapeHtml(item.description)}</div>
          <div class="item-meta">
            ${sn ? `<span>SN: ${escapeHtml(sn)}</span>` : ''}
            ${warranty ? `<span style="margin-left: 10px;">Warranty: ${escapeHtml(warranty)}</span>` : ''}
          </div>
        </td>
        <td class="text-right">${formatCurrency(item.unit_price)}</td>
        <td class="text-right">${discountDisplay}</td>
        <td class="text-right font-bold">${formatCurrency(item.line_total)}</td>
      </tr>`
  }).join('')

  // Optional empty rows to push totals down slightly if there are very few items
  const emptyRowsCount = Math.max(0, 5 - items.length)
  const emptyRowsHtml = Array(emptyRowsCount).fill(0).map(() => `
    <tr class="empty-row">
      <td></td><td></td><td></td><td></td><td></td>
    </tr>
  `).join('')

  // Totals calculations
  const isVat = !!invoice.is_vat_invoice
  const invoiceTitle = isVat ? 'TAX INVOICE' : 'INVOICE'

  // Calculate items subtotal (sum of line_totals which already have per-line discounts applied)
  const itemsSubtotal = items.reduce((sum, i) => sum + Number(i.line_total || 0), 0)
  const globalDiscount = Number(invoice.discount || 0)
  const hasGlobalDiscount = globalDiscount > 0

  let totalsHtml = ''
  if (isVat) {
    totalsHtml = `
      <div class="total-line">
        <span class="total-label">Subtotal</span>
        <span class="total-val">${formatCurrency(itemsSubtotal)}</span>
      </div>
      ${hasGlobalDiscount ? `
      <div class="total-line text-red">
        <span class="total-label">Discount</span>
        <span class="total-val">- ${formatCurrency(globalDiscount)}</span>
      </div>` : ''}
      <div class="total-line">
        <span class="total-label">Net Amount</span>
        <span class="total-val">${formatCurrency(invoice.total_before_vat || 0)}</span>
      </div>
      <div class="total-line text-red">
        <span class="total-label">VAT (18%)</span>
        <span class="total-val">${formatCurrency(invoice.vat_amount || invoice.tax || 0)}</span>
      </div>
      <div class="total-line grand-total">
        <span class="total-label">TOTAL</span>
        <span class="total-val">${formatCurrency(invoice.total || 0)}</span>
      </div>`
  } else {
    totalsHtml = `
      <div class="total-line">
        <span class="total-label">Subtotal</span>
        <span class="total-val">${formatCurrency(itemsSubtotal)}</span>
      </div>
      ${hasGlobalDiscount ? `
      <div class="total-line text-red">
        <span class="total-label">Discount</span>
        <span class="total-val">- ${formatCurrency(globalDiscount)}</span>
      </div>` : ''}
      <div class="total-line grand-total">
        <span class="total-label">TOTAL</span>
        <span class="total-val">${formatCurrency(invoice.total)}</span>
      </div>`
  }

  return `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Invoice - ${invoice.invoice_no}</title>
      <style>
        @page {
          size: A4;
          margin: 0;
        }

        body {
          font-family: 'Segoe UI', Arial, sans-serif;
          color: #1a1a1a;
          margin: 0;
          padding: 0;
          background: #fff;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }

        /*
         * Force all colors explicitly so dark mode (Quasar) cannot
         * cascade white text into the invoice when rendered via v-html.
         */
        .page, .page * {
          color: #1a1a1a !important;
          -webkit-text-fill-color: #1a1a1a !important;
        }
        /* Preserve specific color overrides */
        .page .text-red,
        .page .text-red * {
          color: #ed1c24 !important;
          -webkit-text-fill-color: #ed1c24 !important;
        }
        .page .title-bar {
          color: #ed1c24 !important;
          -webkit-text-fill-color: #ed1c24 !important;
        }
        .page table.items th,
        .page table.items th * {
          color: #ffffff !important;
          -webkit-text-fill-color: #ffffff !important;
        }
        .page .item-meta,
        .page .item-meta * {
          color: #555 !important;
          -webkit-text-fill-color: #555 !important;
        }
        .page .bill-to-label {
          color: #666 !important;
          -webkit-text-fill-color: #666 !important;
        }
        .page .meta-label {
          color: #555 !important;
          -webkit-text-fill-color: #555 !important;
        }
        .page .remarks-label {
          color: #333 !important;
          -webkit-text-fill-color: #333 !important;
        }
        .page .remarks-text {
          color: #555 !important;
          -webkit-text-fill-color: #555 !important;
        }
        .page tr.empty-row td,
        .page tr.empty-row td * {
          color: transparent !important;
          -webkit-text-fill-color: transparent !important;
        }

        .page {
          width: 210mm;
          min-height: 296mm; /* Almost full A4 height to force 1 page usually */
          margin: 0 auto;
          padding: 15mm 20mm;
          box-sizing: border-box;
          display: flex;
          flex-direction: column;
          background: #fff !important;
        }

        /* Helpers */
        .text-center { text-align: center; }
        .text-right { text-align: right; }
        .font-bold { font-weight: 700; }
        .text-red { color: #ed1c24 !important; }

        /* Header section */
        .title-bar {
          font-size: 36px;
          font-weight: 900;
          color: #ed1c24;
          letter-spacing: 2px;
          margin-bottom: 20px;
          text-transform: uppercase;
        }

        .header-grid {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 30px;
        }

        .company-info {
          font-size: 13px;
          line-height: 1.5;
          padding-left: 15px;
          border-left: 4px solid #ed1c24;
        }

        .company-info .c-name {
          font-size: 20px;
          font-weight: 800;
          color: #000;
          margin-bottom: 4px;
        }

        .logo-container {
          text-align: right;
        }
        .logo-container img {
          max-height: 80px;
          max-width: 160px;
          object-fit: contain;
        }

        /* Meta and Customer Grid */
        .info-grid {
          display: flex;
          justify-content: space-between;
          margin-bottom: 30px;
          font-size: 14px;
          line-height: 1.6;
        }

        .customer-card {
          width: 50%;
        }
        .bill-to-label {
          font-size: 12px;
          color: #666;
          text-transform: uppercase;
          font-weight: 700;
          margin-bottom: 4px;
        }
        .customer-name {
          font-size: 16px;
          font-weight: 800;
        }

        .meta-card {
          width: 40%;
          border: 1px solid #ddd;
          background: #fafafa;
          border-radius: 6px;
          padding: 10px 15px;
        }
        .meta-row {
          display: flex;
          justify-content: space-between;
          margin-bottom: 4px;
        }
        .meta-row:last-child {
          margin-bottom: 0;
        }
        .meta-label {
          color: #555;
          font-weight: 600;
        }
        .meta-value {
          font-weight: 700;
          text-align: right;
        }

        /* Items Table */
        .table-container {
          margin-bottom: 25px;
        }
        table.items {
          width: 100%;
          border-collapse: collapse;
          border: 1px solid #000;
        }
        table.items th {
          background-color: #ed1c24 !important;
          color: #ffffff !important;
          padding: 12px 10px;
          font-size: 14px;
          text-transform: uppercase;
          border: 1px solid #000;
        }
        table.items td {
          padding: 12px 10px;
          font-size: 13px;
          border: 1px solid #000;
          vertical-align: top;
        }
        table.items tr.empty-row td {
          color: transparent;
          border-bottom: 1px solid #eee; /* Light inner borders for empty rows */
          border-left: 1px solid #000;
          border-right: 1px solid #000;
          height: 35px;
        }
        
        /* Keep outer borders strong for empty rows */
        table.items tr:last-child td {
          border-bottom: 1px solid #000;
        }

        .main-desc { font-weight: 700; font-size: 14px; margin-bottom: 4px; }
        .item-meta { font-size: 11px; color: #555; }

        /* Column widths */
        th:nth-child(1) { width: 7%; }
        th:nth-child(2) { width: 42%; text-align: left; }
        th:nth-child(3) { width: 18%; text-align: right; }
        th:nth-child(4) { width: 14%; text-align: right; }
        th:nth-child(5) { width: 19%; text-align: right; }

        /* Summary / Totals block */
        .summary-wrapper {
          display: flex;
          justify-content: flex-end;
          margin-bottom: 40px;
        }
        .totals-box {
          width: 40%;
          border: 1px solid #000;
          border-radius: 4px;
          padding: 10px 15px;
          background-color: #fcfcfc;
        }
        .total-line {
          display: flex;
          justify-content: space-between;
          padding: 6px 0;
          font-size: 14px;
          font-weight: 700;
        }
        .grand-total {
          border-top: 2px solid #000;
          margin-top: 4px;
          padding-top: 8px;
          font-size: 16px;
        }
        .balance-line {
          background-color: #f0f0f0;
          margin: 5px -15px -10px -15px;
          padding: 10px 15px;
          border-top: 1px solid #ccc;
          border-bottom-left-radius: 4px;
          border-bottom-right-radius: 4px;
        }

        /* Remarks */
        .remarks-section {
          margin-top: 15px;
          margin-bottom: 20px;
          padding: 10px 14px;
          border: 1px dashed #999;
          border-radius: 4px;
          background-color: #fffde7;
          font-size: 13px;
          line-height: 1.5;
        }
        .remarks-label {
          font-weight: 700;
          color: #333;
          margin-right: 6px;
        }
        .remarks-text {
          color: #555;
        }

        /* Spacer pushes footer to bottom when content is short */
        .footer-spacer {
          flex: 1;
        }

        /* Footer */
        .footer {
          border-top: 1px solid #000;
          padding-top: 15px;
          font-size: 12px;
          font-weight: 600;
        }
        .footer-note { margin-bottom: 5px; }

        @media screen {
          body { background: #e0e0e0; padding: 20px 0; }
          .page { background: #fff; box-shadow: 0 0 15px rgba(0,0,0,0.15); margin-bottom: 20px; }
        }
      </style>
    </head>
    <body>
      <div class="page">
        <!-- TOP: Title -->
        <div class="title-bar">${invoiceTitle}</div>

        <!-- HEADER: Company & Logo -->
        <div class="header-grid">
          <div class="company-info">
            <div class="c-name">${company_name}</div>
            <div>VAT NO: ${vat_no}</div>
            <div>${address}</div>
            ${phones.map(p => `<div>${p}</div>`).join('')}
          </div>
          <div class="logo-container">
             <img src="${logoUrl}" alt="Company Logo" onerror="this.style.display='none'">
          </div>
        </div>

        <!-- META: Customer & Invoice Details -->
        <div class="info-grid">
          <div class="customer-card">
            <div class="bill-to-label">Billed To:</div>
            ${invoice.customer_snapshot?.tax_number ? `<div class="font-bold text-red">TAX NO: ${escapeHtml(invoice.customer_snapshot.tax_number)}</div>` : ''}
            <div class="customer-name">${invoice.customer_snapshot?.name ? (invoice.customer_snapshot.name.toLowerCase() === 'walk-in' || invoice.customer_snapshot.name.toLowerCase() === 'walk in' ? escapeHtml(invoice.customer_snapshot.name) : (invoice.customer_snapshot.title ? escapeHtml(invoice.customer_snapshot.title) + ' ' : '') + escapeHtml(invoice.customer_snapshot.name)) : 'Walk-in Customer'}</div>
            <div>${escapeHtml(invoice.customer_snapshot?.address || '')}</div>
            <div>${escapeHtml(invoice.customer_snapshot?.phone || '')}</div>
          </div>
          
          <div class="meta-card">
            <div class="meta-row">
              <span class="meta-label">Invoice No:</span>
              <span class="meta-value">${escapeHtml(invoice.invoice_no || '-')}</span>
            </div>
            <div class="meta-row">
              <span class="meta-label">Date:</span>
              <span class="meta-value">${formatDate(invoice.invoice_date || invoice.created_at || new Date())}</span>
            </div>
            ${invoice.customer_po_no ? `
            <div class="meta-row">
              <span class="meta-label">Cust. PO:</span>
              <span class="meta-value">${escapeHtml(invoice.customer_po_no)}</span>
            </div>` : ''}
          </div>
        </div>

        <!-- TABLE -->
        <div class="table-container">
          <table class="items">
            <thead>
              <tr>
                <th>Qty</th>
                <th>Description / Serial & Warranty</th>
                <th>Unit Price</th>
                <th>Discount</th>
                <th>Total</th>
              </tr>
            </thead>
            <tbody>
              ${itemsHtml}
              ${emptyRowsHtml}
            </tbody>
          </table>
        </div>

        <!-- TOTALS -->
        <div class="summary-wrapper">
          <div class="totals-box">
            ${totalsHtml}
            <div class="total-line" style="margin-top: 5px;">
              <span class="total-label">PAID AMOUNT</span>
              <span class="total-val">${formatCurrency(invoice.paid_amount || invoice.paid_total || 0)}</span>
            </div>
            <div class="total-line balance-line">
              <span class="total-label">BALANCE DUE</span>
              <span class="total-val text-red">${formatCurrency(invoice.balance || 0)}</span>
            </div>
          </div>
        </div>

        ${invoice.notes ? `
        <!-- REMARKS -->
        <div class="remarks-section">
          <span class="remarks-label">Remarks:</span>
          <span class="remarks-text">${escapeHtml(invoice.notes)}</span>
        </div>
        ` : ''}

        <!-- SPACER: pushes footer to bottom -->
        <div class="footer-spacer"></div>

        <!-- FOOTER -->
        <div class="footer">
          <div class="footer-note">${footer_note}</div>
          <div class="thank-you">Thank You for your Business!</div>
        </div>
      </div>
    </body>
    </html>
  `
}

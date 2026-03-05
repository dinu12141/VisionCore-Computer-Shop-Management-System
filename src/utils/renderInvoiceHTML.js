export const renderInvoiceHTML = (invoice, template = {}) => {
  const {
    company_name = 'Vison Computers',
    vat_no = '117543862-7000',
    address = 'No.36, Bibila Road, Monaragala.',
    phones = ['076-5554567', '070-4008480'],
    footer_note = 'All cheques drawn in favor of "VISION COMPUTERS".',
  } = template

  const logoUrl = window.location.origin + '/logo.png'

  const formatDate = (d) => {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ]
    const dateObj = new Date(d)
    return `${dateObj.getDate()} ${months[dateObj.getMonth()]} ${dateObj.getFullYear()}`
  }

  const formatCurrency = (val) => {
    return (
      'LKR ' +
      Number(val || 0).toLocaleString(undefined, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      })
    )
  }

  const items = invoice.items || []
  const itemsHtml = items
    .map((item, index) => {
      const sn = item.serial_number || item.serialNumber
      const warranty = item.warranty
      let rowHtml = `
      <tr class="${index % 2 === 1 ? 'zebra' : ''}">
        <td class="col-qty text-center">${item.qty}</td>
        <td class="col-desc">
          <div class="main-desc">${item.description}</div>
          <div class="item-meta">
            ${sn ? `<span>SN: ${sn}</span>` : ''}
            ${warranty ? `<span style="margin-left: 12px;">Warranty: ${warranty}</span>` : ''}
          </div>
        </td>
        <td class="col-uprice text-right">${formatCurrency(item.unit_price)}</td>
        <td class="col-total text-right">${formatCurrency(item.line_total)}</td>
      </tr>`
      return rowHtml
    })
    .join('')

  // Reduced empty rows to 12 to guarantee space for footer and totals on a single page
  // Adjusted empty rows count based on content length
  const emptyRowsCount = Math.max(0, 15 - items.length)
  const emptyRowsHtml = Array(emptyRowsCount)
    .fill(0)
    .map(
      (_, i) => `
    <tr class="${(i + items.length) % 2 === 1 ? 'zebra' : ''}">
      <td class="col-qty"></td>
      <td class="col-desc"></td>
      <td class="col-uprice"></td>
      <td class="col-total"></td>
    </tr>
  `,
    )
    .join('')

  // --- VAT Invoice: build totals HTML ---
  const isVat = !!invoice.is_vat_invoice
  const invoiceTitle = isVat ? 'TAX INVOICE' : 'INVOICE'

  let totalsHtml = ''
  if (isVat) {
    // VAT Invoice: show 3 new lines BEFORE the existing PAID AMOUNT / BALANCE
    const totalBeforeVat = Number(invoice.total_before_vat || 0)
    const vatAmount = Number(invoice.vat_amount || invoice.tax || 0)
    const totalWithVat = Number(invoice.total || 0)

    totalsHtml = `
          <div class="total-line">
            <span class="total-label">TOTAL (WITHOUT VAT)</span>
            <span class="total-val">${formatCurrency(totalBeforeVat)}</span>
          </div>
          <div class="total-line" style="color: #ed1c24;">
            <span class="total-label">VAT (18%)</span>
            <span class="total-val">${formatCurrency(vatAmount)}</span>
          </div>
          <div class="total-line" style="border-top: 2px solid #000; padding-top: 4px; margin-top: 2px;">
            <span class="total-label">TOTAL (WITH VAT)</span>
            <span class="total-val">${formatCurrency(totalWithVat)}</span>
          </div>`
  } else {
    // Normal Invoice: original TOTAL line exactly as before
    totalsHtml = `
          <div class="total-line">
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
          margin: 0 !important;
        }

        * { box-sizing: border-box; }

        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          color: #000;
          margin: 0;
          padding: 0;
          background: #fff;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }

        .page {
          width: 210mm;
          height: 297mm;
          margin: 0 auto;
          background: #fff;
          padding: 12mm 15mm;
          display: flex;
          flex-direction: column;
          position: relative;
          color: #000 !important;
        }

        @media screen {
          body { background: #e0e0e0; padding: 20px 0; }
          .page { box-shadow: 0 0 10px rgba(0,0,0,0.2); }
        }

        .header-top { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; }
        .invoice-box { border: 2.5px solid #ed1c24; padding: 6px 20px; margin-top: 10px; }
        .invoice-box h1 { color: #ed1c24 !important; font-size: 32px; margin: 0; font-weight: 800; letter-spacing: 2px; line-height: 1; }

        .logo-box { text-align: center; width: 140px; }
        .logo-box img { width: 100%; height: auto; }

        .company-info-row { display: flex; justify-content: space-between; margin-bottom: 20px; font-size: 14px; line-height: 1.3; }
        .company-name { font-size: 19px; font-weight: bold; margin-bottom: 4px; }
        .red-accent-bar { border-left: 5px solid #ed1c24; padding-left: 12px; }

        .meta-info-table { width: auto; align-self: flex-start; }
        .meta-item { display: flex; justify-content: flex-end; margin-bottom: 5px; font-size: 15px; }
        .meta-label { font-weight: bold; width: 110px; text-align: left; }
        .meta-val { width: 150px; text-align: left; font-weight: 500; }

        .customer-section { margin-bottom: 20px; font-size: 15.5px; line-height: 1.4; font-weight: 600; padding-left: 2px; }

        .table-container { border: 1.5px solid #000; border-bottom: none; }
        table { width: 100%; border-collapse: collapse; table-layout: fixed; border-bottom: 1.5px solid #000; }
        th { background-color: #ed1c24 !important; color: #fff !important; text-align: center; padding: 10px 5px; font-size: 15px; border: 1px solid #000; }
        td { padding: 10px 10px; font-size: 14px; border-left: 1.5px solid #000; border-right: 1.5px solid #000; vertical-align: middle; min-height: 42px; }
        tr.zebra { background-color: #f9f9f9 !important; }

        .col-qty { width: 50px; }
        .col-desc { text-align: left; }
        .main-desc { font-weight: 700; font-size: 15px; }
        .item-meta { font-size: 12px; color: #333; margin-top: 3px; font-weight: 600; }
        .col-uprice { width: 140px; text-align: right; }
        .col-total { width: 150px; text-align: right; }

        .totals-container { margin-top: 10px; width: 330px; align-self: flex-end; }
        .total-line { display: flex; justify-content: flex-end; padding: 2px 0; font-weight: bold; font-size: 16px; }
        .total-label { text-align: right; margin-right: 25px; flex: 1; }
        .total-val { width: 130px; text-align: right; }

        .footer { margin-top: auto; padding-top: 20px; font-size: 14.5px; font-weight: bold; width: 100%; }
        .thank-you { margin-top: 12px; }

        .text-center { text-align: center; }
        .text-right { text-align: right; }
      </style>
    </head>
    <body >
      <div class="page">
        <div class="header-top">
          <div class="invoice-box"><h1>${invoiceTitle}</h1></div>
          <div class="logo-box">
             <img src="${logoUrl}" alt="Logo">
          </div>
        </div>

        <div class="company-info-row">
          <div class="red-accent-bar">
            <div class="company-name">${company_name}</div>
            <div>VAT NO- ${vat_no}</div>
            <div>${address}</div>
            ${phones.map((p) => `<div>${p}</div>`).join('')}
          </div>
          <div class="meta-info-table">
            <div class="meta-item"><span class="meta-label">Date:</span> <span class="meta-val">${formatDate(invoice.invoice_date || new Date())}</span></div>
            <div class="meta-item"><span class="meta-label">Invoice No.:</span> <span class="meta-val">${invoice.invoice_no || ''}</span></div>
          </div>
        </div>

        <div class="customer-section">
          ${isVat && invoice.customer_snapshot?.tax_number ? `<div>TAX NO: ${invoice.customer_snapshot.tax_number}</div>` : ''}
          <div>Mr. ${invoice.customer_snapshot?.name || 'Walk-in Customer'}</div>
          <div>${invoice.customer_snapshot?.address || ''}</div>
          <div>${invoice.customer_snapshot?.phone || ''}</div>
        </div>

        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th class="col-qty">Qty</th>
                <th>Description / Serial & Warranty</th>
                <th class="col-uprice">Unit Price</th>
                <th class="col-total">TOTAL</th>
              </tr>
            </thead>
            <tbody>
              ${itemsHtml}
              ${emptyRowsHtml}
            </tbody>
          </table>
        </div>

        <div class="totals-container">
          ${totalsHtml}
          <div class="total-line">
            <span class="total-label">PAID AMOUNT</span>
            <span class="total-val">${formatCurrency(invoice.paid_amount || invoice.paid_total)}</span>
          </div>
          <div class="total-line">
            <span class="total-label">BALANCE (DUE)</span>
            <span class="total-val">${formatCurrency(invoice.balance)}</span>
          </div>
        </div>

        <div class="footer">
          <div>${footer_note}</div>
          <div class="thank-you">Thank you</div>
        </div>
      </div>
    </body>
    </html>
  `
}

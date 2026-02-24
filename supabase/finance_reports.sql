-- =====================================================
-- FINANCE & PROFIT ANALYTICS MIGRATION
-- =====================================================

-- 1. UPDATE INVENTORY ITEMS
-- Adding fields required for finance tracking if they don't exist
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS cost_price NUMERIC(14,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS selling_price NUMERIC(14,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS sku TEXT,
ADD COLUMN IF NOT EXISTS barcode TEXT;

-- 2. UPDATE INVOICE ITEMS
-- Add price snapshots and generated columns for profit calculation
-- We use NUMERIC(14,2) for currency fields
ALTER TABLE invoice_items
ADD COLUMN IF NOT EXISTS cost_unit_price_snapshot NUMERIC(14,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS selling_unit_price_snapshot NUMERIC(14,2) NOT NULL DEFAULT 0;

-- Drop generated columns if they exist to recreate them with snapshots
ALTER TABLE invoice_items DROP COLUMN IF EXISTS line_revenue;
ALTER TABLE invoice_items DROP COLUMN IF EXISTS line_cogs;
ALTER TABLE invoice_items DROP COLUMN IF EXISTS line_profit;

ALTER TABLE invoice_items
ADD COLUMN line_revenue NUMERIC(14,2) GENERATED ALWAYS AS (qty * selling_unit_price_snapshot - discount) STORED,
ADD COLUMN line_cogs NUMERIC(14,2) GENERATED ALWAYS AS (qty * cost_unit_price_snapshot) STORED,
ADD COLUMN line_profit NUMERIC(14,2) GENERATED ALWAYS AS ((qty * selling_unit_price_snapshot - discount) - (qty * cost_unit_price_snapshot)) STORED;

-- 3. INDEXES FOR REPORTING PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_invoice_items_reporting_cid ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoices_reporting_date ON invoices(company_id, invoice_date, status);
CREATE INDEX IF NOT EXISTS idx_payments_reporting_date ON payments(created_at, status);

-- 4. REPORTING RPC FUNCTIONS

-- A) Sales Summary Grouped by Period
CREATE OR REPLACE FUNCTION report_sales_summary(
    p_company_id UUID,
    p_from_date DATE,
    p_to_date DATE,
    p_group_by TEXT DEFAULT 'day'
)
RETURNS TABLE (
    period_start DATE,
    revenue NUMERIC,
    cogs NUMERIC,
    profit NUMERIC,
    margin_pct NUMERIC
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        date_trunc(p_group_by, i.invoice_date)::DATE as p_start,
        COALESCE(SUM(ii.line_revenue), 0) as rev,
        COALESCE(SUM(ii.line_cogs), 0) as c,
        COALESCE(SUM(ii.line_profit), 0) as p,
        CASE 
            WHEN COALESCE(SUM(ii.line_revenue), 0) > 0 
            THEN ROUND((SUM(ii.line_profit) / SUM(ii.line_revenue)) * 100, 2)
            ELSE 0 
        END as margin
    FROM invoices i
    JOIN invoice_items ii ON i.id = ii.invoice_id
    WHERE i.company_id = p_company_id
      AND i.invoice_date BETWEEN p_from_date AND p_to_date
      AND i.status != 'cancelled'
    GROUP BY p_start
    ORDER BY p_start ASC;
END;
$$ LANGUAGE plpgsql;

-- B) Sales by Item
CREATE OR REPLACE FUNCTION report_sales_by_item(
    p_company_id UUID,
    p_from_date DATE,
    p_to_date DATE,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    product_id UUID,
    item_name TEXT,
    qty_sold NUMERIC,
    revenue NUMERIC,
    cogs NUMERIC,
    profit NUMERIC,
    profit_pct NUMERIC
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ii.product_id,
        ii.description as i_name,
        SUM(ii.qty) as q,
        SUM(ii.line_revenue) as rev,
        SUM(ii.line_cogs) as c,
        SUM(ii.line_profit) as p,
        CASE 
            WHEN SUM(ii.line_revenue) > 0 
            THEN ROUND((SUM(ii.line_profit) / SUM(ii.line_revenue)) * 100, 2)
            ELSE 0 
        END as p_pct
    FROM invoices i
    JOIN invoice_items ii ON i.id = ii.invoice_id
    WHERE i.company_id = p_company_id
      AND i.invoice_date BETWEEN p_from_date AND p_to_date
      AND i.status != 'cancelled'
    GROUP BY ii.product_id, ii.description
    ORDER BY rev DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- C) Sales by Customer
CREATE OR REPLACE FUNCTION report_sales_by_customer(
    p_company_id UUID,
    p_from_date DATE,
    p_to_date DATE,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    customer_id UUID,
    customer_name TEXT,
    invoice_count BIGINT,
    revenue NUMERIC,
    paid_total NUMERIC,
    balance_due NUMERIC
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.customer_id,
        COALESCE(c.name, 'One-time Customer') as c_name,
        COUNT(i.id) as inv_count,
        SUM(i.total) as rev,
        SUM(i.paid_amount) as paid,
        SUM(i.balance) as bal
    FROM invoices i
    LEFT JOIN customers c ON i.customer_id = c.id
    WHERE i.company_id = p_company_id
      AND i.invoice_date BETWEEN p_from_date AND p_to_date
      AND i.status != 'cancelled'
    GROUP BY i.customer_id, c.name
    ORDER BY rev DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- D) Invoice List Report
CREATE OR REPLACE FUNCTION report_invoice_list(
    p_company_id UUID,
    p_from_date DATE,
    p_to_date DATE,
    p_status TEXT DEFAULT NULL,
    p_payment_status TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    invoice_no TEXT,
    invoice_date DATE,
    customer_name TEXT,
    total NUMERIC,
    paid_amount NUMERIC,
    balance NUMERIC,
    status TEXT,
    payment_type TEXT
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.invoice_no,
        i.invoice_date,
        COALESCE(c.name, 'One-time Customer') as c_name,
        i.total,
        i.paid_amount,
        i.balance,
        i.status,
        i.payment_type
    FROM invoices i
    LEFT JOIN customers c ON i.customer_id = c.id
    WHERE i.company_id = p_company_id
      AND i.invoice_date BETWEEN p_from_date AND p_to_date
      AND (p_status IS NULL OR i.status = p_status)
      AND (p_payment_status IS NULL OR (
          CASE 
              WHEN i.balance <= 0 THEN 'paid'
              WHEN i.paid_amount > 0 THEN 'partial'
              ELSE 'unpaid'
          END = p_payment_status
      ))
    ORDER BY i.invoice_date DESC, i.invoice_no DESC;
END;
$$ LANGUAGE plpgsql;

-- E) Payment Summary
CREATE OR REPLACE FUNCTION report_payment_summary(
    p_company_id UUID,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS TABLE (
    payment_method TEXT,
    total_received NUMERIC
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.method as p_method,
        COALESCE(SUM(p.amount), 0) as total
    FROM invoice_payments p
    JOIN invoices i ON p.invoice_id = i.id
    WHERE i.company_id = p_company_id
      AND p.paid_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY p.method
    ORDER BY total DESC;
END;
$$ LANGUAGE plpgsql;

-- F) Finance Overview Dashboard
CREATE OR REPLACE FUNCTION get_finance_overview(
    p_company_id UUID,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS TABLE (
    total_revenue NUMERIC,
    total_cogs NUMERIC,
    total_profit NUMERIC,
    avg_margin_pct NUMERIC,
    total_received NUMERIC,
    outstanding_balance NUMERIC
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    WITH sales_metrics AS (
        SELECT 
            SUM(ii.line_revenue) as rev,
            SUM(ii.line_cogs) as c,
            SUM(ii.line_profit) as p
        FROM invoices i
        JOIN invoice_items ii ON i.id = ii.invoice_id
        WHERE i.company_id = p_company_id
          AND i.invoice_date BETWEEN p_from_date AND p_to_date
          AND i.status != 'cancelled'
    ),
    payment_metrics AS (
        SELECT SUM(amount) as received
        FROM invoice_payments p
        JOIN invoices i ON p.invoice_id = i.id
        WHERE i.company_id = p_company_id
          AND p.paid_at::DATE BETWEEN p_from_date AND p_to_date
    ),
    ar_metrics AS (
        SELECT SUM(balance) as remaining
        FROM invoices
        WHERE company_id = p_company_id
          AND status != 'cancelled'
          AND balance > 0
    )
    SELECT 
        COALESCE(sm.rev, 0),
        COALESCE(sm.c, 0),
        COALESCE(sm.p, 0),
        CASE WHEN COALESCE(sm.rev, 0) > 0 THEN ROUND((sm.p / sm.rev) * 100, 2) ELSE 0 END,
        COALESCE(pm.received, 0),
        COALESCE(am.remaining, 0)
    FROM sales_metrics sm, payment_metrics pm, ar_metrics am;
END;
$$ LANGUAGE plpgsql;

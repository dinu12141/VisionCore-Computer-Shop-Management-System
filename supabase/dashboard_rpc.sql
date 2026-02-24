-- ============================================================================
-- ERP MODULE: DASHBOARD RPC FUNCTIONS
-- Optimized for single-round trip performance and multi-tenant RLS compatibility.
-- ============================================================================

-- A) dashboard_kpis(from_date, to_date)
-- Returns a single JSON object for the KPI cards
CREATE OR REPLACE FUNCTION dashboard_kpis(p_company_id UUID, p_from_date DATE, p_to_date DATE)
RETURNS JSON AS $$
DECLARE
    result JSON;
    v_days INTEGER;
    v_prev_from DATE;
    v_prev_to DATE;
BEGIN
    v_days := p_to_date - p_from_date + 1;
    v_prev_from := p_from_date - v_days;
    v_prev_to := p_from_date - 1;

    WITH current_period AS (
        SELECT 
            COALESCE(SUM(total), 0) as revenue,
            COALESCE(SUM(paid_amount), 0) as payments_received,
            COALESCE(SUM(balance), 0) as outstanding_balance,
            COUNT(*) as invoices_count,
            COALESCE(SUM((SELECT SUM(line_cogs) FROM invoice_items WHERE invoice_id = invoices.id)), 0) as cogs
        FROM invoices 
        WHERE company_id = p_company_id 
          AND invoice_date BETWEEN p_from_date AND p_to_date
          AND status != 'cancelled'
    ),
    previous_period AS (
        SELECT 
            COALESCE(SUM(total), 0) as revenue,
            COALESCE(SUM(paid_amount), 0) as payments_received,
            COALESCE(SUM((SELECT SUM(line_cogs) FROM invoice_items WHERE invoice_id = invoices.id)), 0) as cogs
        FROM invoices 
        WHERE company_id = p_company_id 
          AND invoice_date BETWEEN v_prev_from AND v_prev_to
          AND status != 'cancelled'
    ),
    stock_stats AS (
        SELECT 
            COUNT(*) FILTER (WHERE qty_on_hand <= reorder_level) as low_stock_count
        FROM stock_on_hand 
        JOIN items ON items.id = stock_on_hand.item_id
        WHERE items.company_id = p_company_id
    ),
    overdue_stats AS (
        SELECT 
            COUNT(*) as overdue_collections_count
        FROM invoices 
        WHERE company_id = p_company_id 
          AND balance > 0 
          AND collection_date < CURRENT_DATE
          AND status != 'cancelled'
    )
    SELECT json_build_object(
        'revenue', cp.revenue,
        'cogs', cp.cogs,
        'profit', cp.revenue - cp.cogs,
        'margin_pct', CASE WHEN cp.revenue > 0 THEN ((cp.revenue - cp.cogs) / cp.revenue) * 100 ELSE 0 END,
        'payments_received', cp.payments_received,
        'outstanding_balance', cp.outstanding_balance,
        'invoices_count', cp.invoices_count,
        'overdue_collections_count', os.overdue_collections_count,
        'low_stock_count', ss.low_stock_count,
        'deltas', json_build_object(
            'revenue', CASE WHEN pp.revenue > 0 THEN ((cp.revenue - pp.revenue) / pp.revenue) * 100 ELSE NULL END,
            'profit', CASE WHEN (pp.revenue - pp.cogs) != 0 THEN (((cp.revenue - cp.cogs) - (pp.revenue - pp.cogs)) / ABS(pp.revenue - pp.cogs)) * 100 ELSE NULL END
        )
    ) INTO result
    FROM current_period cp, previous_period pp, stock_stats ss, overdue_stats os;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- B) dashboard_trends(from_date, to_date, group_by)
DROP FUNCTION IF EXISTS dashboard_trends(UUID, DATE, DATE, TEXT);
CREATE OR REPLACE FUNCTION dashboard_trends(p_company_id UUID, p_from_date DATE, p_to_date DATE, p_group_by TEXT)
RETURNS TABLE (
    period_start DATE,
    revenue NUMERIC,
    profit NUMERIC,
    payments_received NUMERIC
) AS $$
BEGIN
    IF p_group_by = 'day' THEN
        RETURN QUERY
        SELECT 
            d.day::DATE as period_start,
            COALESCE(SUM(i.total), 0) as revenue,
            COALESCE(SUM(i.total - (SELECT COALESCE(SUM(line_cogs),0) FROM invoice_items WHERE invoice_id = i.id)), 0) as profit,
            COALESCE((SELECT SUM(amount) FROM invoice_payments WHERE company_id = p_company_id AND paid_at::DATE = d.day::DATE), 0) as payments_received
        FROM generate_series(p_from_date::TIMESTAMP, p_to_date::TIMESTAMP, '1 day') d(day)
        LEFT JOIN invoices i ON i.company_id = p_company_id AND i.invoice_date = d.day::DATE AND i.status != 'cancelled'
        GROUP BY d.day
        ORDER BY d.day;
    ELSIF p_group_by = 'week' THEN
        RETURN QUERY
        SELECT 
            date_trunc('week', d.day)::DATE as period_start,
            COALESCE(SUM(i.total), 0) as revenue,
            COALESCE(SUM(i.total - (SELECT COALESCE(SUM(line_cogs),0) FROM invoice_items WHERE invoice_id = i.id)), 0) as profit,
            COALESCE((SELECT SUM(amount) FROM invoice_payments WHERE company_id = p_company_id AND date_trunc('week', paid_at)::DATE = date_trunc('week', d.day)::DATE), 0) as payments_received
        FROM generate_series(p_from_date::TIMESTAMP, p_to_date::TIMESTAMP, '1 week') d(day)
        LEFT JOIN invoices i ON i.company_id = p_company_id AND date_trunc('week', i.invoice_date) = date_trunc('week', d.day) AND i.status != 'cancelled'
        GROUP BY 1
        ORDER BY 1;
    ELSE
        RETURN QUERY
        SELECT 
            date_trunc('month', d.day)::DATE as period_start,
            COALESCE(SUM(i.total), 0) as revenue,
            COALESCE(SUM(i.total - (SELECT COALESCE(SUM(line_cogs),0) FROM invoice_items WHERE invoice_id = i.id)), 0) as profit,
            COALESCE((SELECT SUM(amount) FROM invoice_payments WHERE company_id = p_company_id AND date_trunc('month', paid_at)::DATE = date_trunc('month', d.day)::DATE), 0) as payments_received
        FROM generate_series(p_from_date::TIMESTAMP, p_to_date::TIMESTAMP, '1 month') d(day)
        LEFT JOIN invoices i ON i.company_id = p_company_id AND date_trunc('month', i.invoice_date) = date_trunc('month', d.day) AND i.status != 'cancelled'
        GROUP BY 1
        ORDER BY 1;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- C) dashboard_collections_due(from_date, to_date, limit)
DROP FUNCTION IF EXISTS dashboard_collections_due(UUID, INTEGER);
CREATE OR REPLACE FUNCTION dashboard_collections_due(p_company_id UUID, p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
    invoice_id UUID,
    invoice_no TEXT,
    customer_name TEXT,
    collection_date DATE,
    balance NUMERIC,
    payment_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id as invoice_id,
        i.invoice_no,
        c.name as customer_name,
        i.collection_date,
        i.balance,
        i.payment_status
    FROM invoices i
    LEFT JOIN customers c ON i.customer_id = c.id
    WHERE i.company_id = p_company_id 
      AND i.balance > 0 
      AND i.status != 'cancelled'
    ORDER BY i.collection_date ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- D) dashboard_top_items(from_date, to_date, metric)
DROP FUNCTION IF EXISTS dashboard_top_items(UUID, DATE, DATE, TEXT, INTEGER);
CREATE OR REPLACE FUNCTION dashboard_top_items(p_company_id UUID, p_from_date DATE, p_to_date DATE, p_metric TEXT, p_limit INTEGER DEFAULT 5)
RETURNS TABLE (
    name TEXT,
    value NUMERIC,
    qty NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(it.name, ii.description) as name,
        CASE 
            WHEN p_metric = 'profit' THEN SUM(ii.line_profit)
            WHEN p_metric = 'revenue' THEN SUM(ii.line_revenue)
            ELSE SUM(ii.qty)
        END as value,
        SUM(ii.qty) as qty
    FROM invoice_items ii
    JOIN invoices i ON ii.invoice_id = i.id
    LEFT JOIN items it ON ii.product_id = it.id
    WHERE i.company_id = p_company_id 
      AND i.invoice_date BETWEEN p_from_date AND p_to_date
      AND i.status != 'cancelled'
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- E) dashboard_top_customers(from_date, to_date, metric)
DROP FUNCTION IF EXISTS dashboard_top_customers(UUID, DATE, DATE, TEXT, INTEGER);
CREATE OR REPLACE FUNCTION dashboard_top_customers(p_company_id UUID, p_from_date DATE, p_to_date DATE, p_metric TEXT, p_limit INTEGER DEFAULT 5)
RETURNS TABLE (
    name TEXT,
    value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name,
        CASE 
            WHEN p_metric = 'revenue' THEN SUM(i.total)
            ELSE MAX(c_balance.total_balance)
        END as value
    FROM invoices i
    JOIN customers c ON i.customer_id = c.id
    LEFT JOIN LATERAL (
        SELECT SUM(balance) as total_balance 
        FROM invoices 
        WHERE customer_id = c.id AND status != 'cancelled'
    ) c_balance ON TRUE
    WHERE i.company_id = p_company_id 
      AND (p_metric = 'outstanding' OR i.invoice_date BETWEEN p_from_date AND p_to_date)
      AND i.status != 'cancelled'
    GROUP BY c.id, c.name
    ORDER BY 2 DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- F) dashboard_payment_methods(from_date, to_date)
DROP FUNCTION IF EXISTS dashboard_payment_methods(UUID, DATE, DATE);
CREATE OR REPLACE FUNCTION dashboard_payment_methods(p_company_id UUID, p_from_date DATE, p_to_date DATE)
RETURNS TABLE (
    method TEXT,
    value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(ip.method, 'Other') as method,
        SUM(ip.amount) as value
    FROM invoice_payments ip
    WHERE ip.company_id = p_company_id 
      AND ip.paid_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY 1
    ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

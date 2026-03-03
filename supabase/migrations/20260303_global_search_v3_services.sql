-- ============================================================================
-- GLOBAL SEARCH V3: Add Service Jobs to unified search
-- ============================================================================

-- Indexes for service jobs search
CREATE INDEX IF NOT EXISTS idx_service_jobs_no_trgm ON service_jobs USING gin (job_no gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_service_jobs_serial_trgm ON service_jobs USING gin (serial_no gin_trgm_ops);

-- Drop and recreate to update the function body
-- Drop and recreate to update the function body
DROP FUNCTION IF EXISTS global_search(UUID, TEXT, INT);

CREATE OR REPLACE FUNCTION global_search(
    p_company_id UUID,
    q TEXT,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    entity_type TEXT,
    entity_id UUID,
    title TEXT,
    subtitle TEXT,
    extra JSONB,
    rank INT
) AS $$
DECLARE
    v_query TEXT;
BEGIN
    v_query := trim(q);

    IF v_query IS NULL OR length(v_query) < 2 THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH all_results AS (
        -- 1. ITEMS (Includes category search)
        (SELECT
            'item'::TEXT as entity_type,
            i.id as entity_id,
            i.name as title,
            'SKU: ' || i.code || COALESCE(' | Barcode: ' || i.barcode, '') || COALESCE(' | Cat: ' || ic.name, '') as subtitle,
            jsonb_build_object('code', i.code, 'url', '/inventory/items/' || i.id, 'category', ic.name) as extra,
            CASE
                WHEN i.code = v_query OR i.barcode = v_query THEN 100
                WHEN i.name ILIKE v_query THEN 90
                WHEN i.name ILIKE v_query || '%' THEN 80
                WHEN i.code ILIKE v_query || '%' THEN 75
                WHEN ic.name ILIKE '%' || v_query || '%' THEN 70
                ELSE 50
            END as rank,
            i.updated_at
        FROM items i
        LEFT JOIN item_categories ic ON i.category_id = ic.id
        WHERE i.company_id = p_company_id
          AND (
            i.name ILIKE '%' || v_query || '%' OR
            i.code ILIKE '%' || v_query || '%' OR
            i.barcode ILIKE '%' || v_query || '%' OR
            ic.name ILIKE '%' || v_query || '%'
          )
        ORDER BY 6 DESC, 7 DESC
        LIMIT p_limit)

        UNION ALL

        -- 2. INVOICES
        (SELECT
            'invoice'::TEXT,
            inv.id,
            inv.invoice_number,
            'Date: ' || inv.invoice_date::TEXT || ' | Total: ' || inv.total::TEXT,
            jsonb_build_object('status', inv.status, 'url', '/billing/invoices/' || inv.id),
            CASE
                WHEN inv.invoice_number = v_query THEN 100
                WHEN inv.invoice_number ILIKE v_query || '%' THEN 85
                ELSE 50
            END,
            inv.updated_at
        FROM invoices inv
        WHERE inv.company_id = p_company_id
          AND inv.invoice_number ILIKE '%' || v_query || '%'
        ORDER BY 6 DESC, 7 DESC
        LIMIT p_limit)

        UNION ALL

        -- 3. CUSTOMERS
        (SELECT
            'customer'::TEXT,
            c.id,
            c.name,
            'Code: ' || c.customer_code || ' | Phone: ' || COALESCE(c.phone, 'N/A'),
            jsonb_build_object('phone', c.phone, 'code', c.customer_code, 'url', '/customers/' || c.id),
            CASE
                WHEN c.name ILIKE v_query THEN 100
                WHEN c.customer_code = v_query OR c.phone = v_query THEN 95
                WHEN c.name ILIKE v_query || '%' THEN 85
                WHEN c.customer_code ILIKE v_query || '%' THEN 80
                WHEN c.phone ILIKE v_query || '%' THEN 75
                ELSE 50
            END,
            c.updated_at
        FROM customers c
        WHERE c.company_id = p_company_id
          AND (
            c.name ILIKE '%' || v_query || '%' OR
            c.phone ILIKE '%' || v_query || '%' OR
            c.customer_code ILIKE '%' || v_query || '%'
          )
        ORDER BY 6 DESC, 7 DESC
        LIMIT p_limit)

        UNION ALL

        -- 4. SERVICE JOBS
        (SELECT
            'service_job'::TEXT,
            sj.id,
            sj.job_no,
            COALESCE(sj.brand, '') || ' ' || COALESCE(sj.model, '') || ' | S/N: ' || COALESCE(sj.serial_no, 'N/A') || ' | ' || sj.status,
            jsonb_build_object(
                'status', sj.status,
                'device_type', sj.device_type,
                'serial_no', sj.serial_no,
                'url', '/services/jobs/' || sj.id
            ),
            CASE
                WHEN sj.job_no = v_query THEN 100
                WHEN sj.serial_no = v_query THEN 95
                WHEN sj.job_no ILIKE v_query || '%' THEN 85
                WHEN sj.serial_no ILIKE v_query || '%' THEN 80
                WHEN sj.brand ILIKE v_query || '%' THEN 70
                WHEN sj.model ILIKE '%' || v_query || '%' THEN 65
                ELSE 50
            END,
            sj.updated_at
        FROM service_jobs sj
        WHERE sj.company_id = p_company_id
          AND (
            sj.job_no ILIKE '%' || v_query || '%' OR
            sj.serial_no ILIKE '%' || v_query || '%' OR
            sj.brand ILIKE '%' || v_query || '%' OR
            sj.model ILIKE '%' || v_query || '%' OR
            sj.device_type ILIKE '%' || v_query || '%'
          )
        ORDER BY 6 DESC, 7 DESC
        LIMIT p_limit)
    )
    SELECT
        ar.entity_type,
        ar.entity_id,
        ar.title,
        ar.subtitle,
        ar.extra,
        ar.rank
    FROM all_results ar
    ORDER BY ar.rank DESC, ar.updated_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

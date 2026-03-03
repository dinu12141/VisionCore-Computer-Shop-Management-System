-- ============================================================================
-- GLOBAL SEARCH SYSTEM - PERFORMANCE OPTIMIZED
-- ============================================================================

-- 1. Ensure Extension and Indices
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Re-create indices for high speed searching
-- Trigram indices for fuzzy matching
CREATE INDEX IF NOT EXISTS idx_items_name_trgm ON items USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_customers_name_trgm ON customers USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_invoices_no_trgm ON invoices USING gin (invoice_no gin_trgm_ops);

-- Standard indices for prefix matching (extremely fast)
CREATE INDEX IF NOT EXISTS idx_items_code_prefix ON items(code text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_customers_code_prefix ON customers(customer_code text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_customers_phone_prefix ON customers(phone text_pattern_ops);

-- 2. UNIFIED SEARCH FUNCTION (V2 - Optimized)
-- Drop old function first (return type changed, so CREATE OR REPLACE won't work)
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
    -- Normalize search query (trim and handle empty)
    v_query := trim(q);
    
    IF v_query IS NULL OR length(v_query) < 2 THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH all_results AS (
        -- 1. ITEMS (Inventory)
        (SELECT 
            'item'::TEXT as entity_type,
            id as entity_id,
            name as title,
            'SKU: ' || code || COALESCE(' | Barcode: ' || barcode, '') as subtitle,
            jsonb_build_object('code', code, 'url', '/inventory/items/' || id) as extra,
            CASE 
                WHEN code = v_query OR barcode = v_query THEN 100
                WHEN name ILIKE v_query THEN 90
                WHEN name ILIKE v_query || '%' THEN 80
                WHEN code ILIKE v_query || '%' THEN 75
                ELSE 50
            END as rank,
            updated_at
        FROM items
        WHERE company_id = p_company_id
          AND (
            name ILIKE '%' || v_query || '%' OR 
            code ILIKE v_query || '%' OR 
            barcode ILIKE v_query || '%'
          )
        ORDER BY rank DESC, updated_at DESC
        LIMIT p_limit)

        UNION ALL

        -- 2. INVOICES (Billing)
        (SELECT 
            'invoice'::TEXT as entity_type,
            id as entity_id,
            invoice_no as title,
            'Date: ' || invoice_date::TEXT || ' | Total: ' || total::TEXT as subtitle,
            jsonb_build_object('status', status, 'url', '/billing/invoices/' || id) as extra,
            CASE 
                WHEN invoice_no = v_query THEN 100
                WHEN invoice_no ILIKE v_query || '%' THEN 85
                ELSE 50
            END as rank,
            updated_at
        FROM invoices
        WHERE company_id = p_company_id
          AND invoice_no ILIKE '%' || v_query || '%'
        ORDER BY rank DESC, updated_at DESC
        LIMIT p_limit)

        UNION ALL

        -- 3. CUSTOMERS (CRM)
        (SELECT 
            'customer'::TEXT as entity_type,
            id as entity_id,
            name as title,
            'Code: ' || customer_code || ' | Phone: ' || COALESCE(phone, 'N/A') as subtitle,
            jsonb_build_object('phone', phone, 'code', customer_code, 'url', '/customers/' || id) as extra,
            CASE 
                WHEN name ILIKE v_query THEN 100
                WHEN customer_code = v_query OR phone = v_query THEN 95
                WHEN name ILIKE v_query || '%' THEN 85
                WHEN customer_code ILIKE v_query || '%' THEN 80
                WHEN phone ILIKE v_query || '%' THEN 75
                ELSE 50
            END as rank,
            updated_at
        FROM customers
        WHERE company_id = p_company_id
          AND (
            name ILIKE '%' || v_query || '%' OR 
            phone ILIKE v_query || '%' OR 
            customer_code ILIKE v_query || '%'
          )
        ORDER BY rank DESC, updated_at DESC
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

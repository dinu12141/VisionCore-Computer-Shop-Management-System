-- ============================================================================
-- GLOBAL SEARCH SYSTEM
-- ============================================================================

-- 1. EXTENSIONS & SCHEMA PREPARATION
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Ensure items has barcode column
ALTER TABLE items ADD COLUMN IF NOT EXISTS barcode TEXT;

-- 2. SEARCH OPTIMIZED INDEXES
-- Trigram indexes for fast partial matching (fuzzier search)
CREATE INDEX IF NOT EXISTS idx_items_name_trgm ON items USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_items_code_trgm ON items USING gin (code gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_items_barcode_trgm ON items USING gin (barcode gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_name_trgm ON customers USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_customers_phone_trgm ON customers USING gin (phone gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_customers_code_trgm ON customers USING gin (customer_code gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_invoices_no_trgm ON invoices USING gin (invoice_no gin_trgm_ops);

-- 3. UNIFIED SEARCH FUNCTION
-- SECURITY INVOKER ensures RLS policies on tables are respected
CREATE OR REPLACE FUNCTION global_search(
    p_company_id UUID,
    q TEXT,
    p_limit INT DEFAULT 8
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
    -- Normalize search query
    v_query := trim(q);
    
    IF length(v_query) < 2 THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH search_results AS (
        -- 1. ITEMS
        SELECT 
            'item'::TEXT as entity_type,
            id as entity_id,
            name as title,
            'SKU: ' || code || COALESCE(' | Barcode: ' || barcode, '') as subtitle,
            jsonb_build_object(
                'code', code,
                'category', (SELECT name FROM item_categories WHERE id = items.category_id),
                'url', '/inventory/items/' || id
            ) as extra,
            CASE 
                WHEN code = v_query OR barcode = v_query THEN 100
                WHEN name ILIKE v_query THEN 80
                WHEN code ILIKE v_query || '%' OR barcode ILIKE v_query || '%' THEN 70
                WHEN name ILIKE '%' || v_query || '%' THEN 50
                ELSE 10
            END as rank,
            updated_at
        FROM items
        WHERE company_id = p_company_id
          AND (
            name ILIKE '%' || v_query || '%' OR 
            code ILIKE '%' || v_query || '%' OR 
            barcode ILIKE '%' || v_query || '%'
          )
          AND is_active = true

        UNION ALL

        -- 2. INVOICES
        SELECT 
            'invoice'::TEXT as entity_type,
            id as entity_id,
            invoice_no as title,
            'Date: ' || invoice_date::TEXT || ' | Total: ' || total::TEXT as subtitle,
            jsonb_build_object(
                'status', status,
                'total', total,
                'url', '/billing/invoices/' || id
            ) as extra,
            CASE 
                WHEN invoice_no = v_query THEN 100
                WHEN invoice_no ILIKE v_query || '%' THEN 80
                ELSE 50
            END as rank,
            updated_at
        FROM invoices
        WHERE company_id = p_company_id
          AND invoice_no ILIKE '%' || v_query || '%'

        UNION ALL

        -- 3. CUSTOMERS
        SELECT 
            'customer'::TEXT as entity_type,
            id as entity_id,
            name as title,
            'Code: ' || customer_code || ' | Phone: ' || COALESCE(phone, 'N/A') as subtitle,
            jsonb_build_object(
                'phone', phone,
                'code', customer_code,
                'url', '/customers/' || id
            ) as extra,
            CASE 
                WHEN customer_code = v_query OR phone = v_query THEN 100
                WHEN name ILIKE v_query THEN 80
                WHEN customer_code ILIKE v_query || '%' THEN 70
                WHEN name ILIKE '%' || v_query || '%' THEN 50
                ELSE 10
            END as rank,
            updated_at
        FROM customers
        WHERE company_id = p_company_id
          AND (
            name ILIKE '%' || v_query || '%' OR 
            phone ILIKE '%' || v_query || '%' OR 
            customer_code ILIKE '%' || v_query || '%'
          )
          AND status = 'active'
    )
    SELECT 
        sr.entity_type,
        sr.entity_id,
        sr.title,
        sr.subtitle,
        sr.extra,
        sr.rank
    FROM search_results sr
    ORDER BY sr.rank DESC, sr.updated_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

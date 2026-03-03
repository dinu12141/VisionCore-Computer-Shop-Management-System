-- ============================================================================
-- RUN THIS IN THE SUPABASE DASHBOARD SQL EDITOR
-- Project: ovdheejmgchtohnjozpn
-- Fixes:
--   1. global_search  — correct column names
--   2. get_upcoming_reminders — new function for payment collection alerts
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- 1. GLOBAL SEARCH (customers + invoices + items + service jobs)
-- ────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS global_search(UUID, TEXT, INT);
DROP FUNCTION IF EXISTS global_search(uuid, text, integer);

CREATE OR REPLACE FUNCTION global_search(
    p_company_id UUID,
    q            TEXT,
    p_limit      INT DEFAULT 12
)
RETURNS TABLE (
    entity_type  TEXT,
    entity_id    UUID,
    title        TEXT,
    subtitle     TEXT,
    extra        JSONB,
    score        INT
) AS $$
DECLARE
    v_query TEXT;
BEGIN
    v_query := trim(q);
    IF v_query IS NULL OR length(v_query) < 2 THEN RETURN; END IF;

    RETURN QUERY
    WITH all_results AS (

        -- ── CUSTOMERS ────────────────────────────────────────────────────────
        (SELECT
            'customer'::TEXT                                               AS entity_type,
            c.id                                                           AS entity_id,
            c.name                                                         AS title,
            'Phone: ' || COALESCE(c.phone, 'N/A')
              || COALESCE(' | Code: ' || c.customer_code, '')             AS subtitle,
            jsonb_build_object('phone', c.phone, 'code', c.customer_code) AS extra,
            CASE
                WHEN lower(c.name) = lower(v_query)        THEN 100
                WHEN c.phone = v_query                      THEN 95
                WHEN c.customer_code = v_query              THEN 95
                WHEN c.name ILIKE v_query || '%'            THEN 85
                WHEN c.phone ILIKE v_query || '%'           THEN 80
                ELSE 50
            END::INT AS score,
            c.updated_at
        FROM customers c
        WHERE c.company_id = p_company_id
          AND (
              c.name          ILIKE '%' || v_query || '%' OR
              c.phone         ILIKE '%' || v_query || '%' OR
              c.customer_code ILIKE '%' || v_query || '%' OR
              c.email         ILIKE '%' || v_query || '%'
          )
        ORDER BY score DESC, c.updated_at DESC
        LIMIT p_limit)

        UNION ALL

        -- ── INVOICES ─────────────────────────────────────────────────────────
        (SELECT
            'invoice'::TEXT                                                 AS entity_type,
            inv.id                                                          AS entity_id,
            inv.invoice_no                                                  AS title,
            'Customer: ' || COALESCE(inv.customer_snapshot->>'name','Walk-in')
              || ' | ' || COALESCE(inv.payment_status,'')
              || ' | LKR ' || inv.total::NUMERIC(12,2)::TEXT               AS subtitle,
            jsonb_build_object(
                'status',   inv.payment_status,
                'total',    inv.total,
                'customer', inv.customer_snapshot->>'name'
            )                                                               AS extra,
            CASE
                WHEN inv.invoice_no = v_query                              THEN 100
                WHEN inv.invoice_no ILIKE v_query || '%'                   THEN 85
                WHEN inv.customer_snapshot->>'name'  ILIKE '%'||v_query||'%' THEN 70
                WHEN inv.customer_snapshot->>'phone' ILIKE '%'||v_query||'%' THEN 70
                ELSE 50
            END::INT AS score,
            inv.updated_at
        FROM invoices inv
        WHERE inv.company_id = p_company_id
          AND (
              inv.invoice_no ILIKE '%' || v_query || '%' OR
              inv.customer_snapshot->>'name'  ILIKE '%' || v_query || '%' OR
              inv.customer_snapshot->>'phone' ILIKE '%' || v_query || '%'
          )
        ORDER BY score DESC, inv.updated_at DESC
        LIMIT p_limit)

        UNION ALL

        -- ── ITEMS ────────────────────────────────────────────────────────────
        (SELECT
            'item'::TEXT                                                    AS entity_type,
            i.id                                                            AS entity_id,
            i.name                                                          AS title,
            'Code: ' || COALESCE(i.code,'N/A')
              || COALESCE(' | Cat: ' || ic.name, '')                       AS subtitle,
            jsonb_build_object('code', i.code, 'category', ic.name)       AS extra,
            CASE
                WHEN i.code = v_query                     THEN 100
                WHEN lower(i.name) = lower(v_query)       THEN 90
                WHEN i.name ILIKE v_query || '%'          THEN 80
                WHEN i.code ILIKE v_query || '%'          THEN 75
                WHEN ic.name ILIKE '%' || v_query || '%'  THEN 65
                ELSE 50
            END::INT AS score,
            i.updated_at
        FROM items i
        LEFT JOIN item_categories ic ON i.category_id = ic.id
        WHERE i.company_id = p_company_id
          AND (
              i.name ILIKE '%' || v_query || '%' OR
              i.code ILIKE '%' || v_query || '%' OR
              ic.name ILIKE '%' || v_query || '%'
          )
        ORDER BY score DESC, i.updated_at DESC
        LIMIT p_limit)

        UNION ALL

        -- ── SERVICE JOBS ──────────────────────────────────────────────────────
        (SELECT
            'service_job'::TEXT                                             AS entity_type,
            sj.id                                                           AS entity_id,
            sj.job_no || ' — ' || COALESCE(c2.name, 'Walk-in')            AS title,
            COALESCE(sj.device_type,'') || ' ' || COALESCE(sj.brand,'')
              || ' | ' || COALESCE(sj.status,'')                           AS subtitle,
            jsonb_build_object(
                'status',  sj.status,
                'device',  sj.device_type,
                'customer',c2.name
            )                                                               AS extra,
            CASE
                WHEN sj.job_no = v_query                       THEN 100
                WHEN sj.job_no ILIKE v_query || '%'            THEN 90
                WHEN c2.name   ILIKE '%' || v_query || '%'     THEN 75
                WHEN sj.device_type ILIKE '%'||v_query||'%'   THEN 65
                WHEN sj.brand       ILIKE '%'||v_query||'%'   THEN 60
                ELSE 50
            END::INT AS score,
            sj.updated_at
        FROM service_jobs sj
        LEFT JOIN customers c2 ON sj.customer_id = c2.id
        WHERE sj.company_id = p_company_id
          AND (
              sj.job_no      ILIKE '%' || v_query || '%' OR
              c2.name        ILIKE '%' || v_query || '%' OR
              c2.phone       ILIKE '%' || v_query || '%' OR
              sj.device_type ILIKE '%' || v_query || '%' OR
              sj.brand       ILIKE '%' || v_query || '%'
          )
        ORDER BY score DESC, sj.updated_at DESC
        LIMIT p_limit)
    )
    SELECT
        ar.entity_type,
        ar.entity_id,
        ar.title,
        ar.subtitle,
        ar.extra,
        ar.score
    FROM all_results ar
    ORDER BY ar.score DESC, ar.updated_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. GET UPCOMING REMINDERS — for payment collection alert notifications
--    Returns invoices whose collection_date is within the next p_days days
--    AND still have an outstanding balance (payment_status != 'paid')
-- ────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_upcoming_reminders(UUID, INT);

CREATE OR REPLACE FUNCTION get_upcoming_reminders(
    p_company_id UUID,
    p_days       INT DEFAULT 3
)
RETURNS TABLE (
    id              UUID,
    invoice_no      TEXT,
    customer_name   TEXT,
    customer_phone  TEXT,
    collection_date DATE,
    balance         NUMERIC,
    days_remaining  INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        inv.id,
        inv.invoice_no,
        COALESCE(inv.customer_snapshot->>'name',  'Walk-in')::TEXT  AS customer_name,
        COALESCE(inv.customer_snapshot->>'phone', '')::TEXT          AS customer_phone,
        inv.collection_date::DATE,
        inv.balance::NUMERIC,
        (inv.collection_date::DATE - CURRENT_DATE)::INT             AS days_remaining
    FROM invoices inv
    WHERE inv.company_id    = p_company_id
      AND inv.collection_date IS NOT NULL
      AND inv.collection_date::DATE >= CURRENT_DATE
      AND inv.collection_date::DATE <= CURRENT_DATE + p_days
      AND inv.payment_status IN ('partial', 'unpaid', 'outstanding')
      AND inv.balance > 0
    ORDER BY inv.collection_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Notify PostgREST to reload
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- SECURITY FIX: Add SET search_path = public to all SECURITY DEFINER functions
-- Date: 2026-06-25
-- Auditor: Riley (QA/Security)
-- Lead sign-off: Alex
--
-- HIGH-002: SECURITY DEFINER functions without a fixed search_path are
-- vulnerable to search_path injection. A user who can CREATE SCHEMA could
-- shadow system functions by placing their own versions in a schema that
-- appears earlier in the caller's search_path, causing the DEFINER function
-- to execute malicious code with elevated privileges.
--
-- Fix: ALTER FUNCTION ... SET search_path = public
-- Using ALTER FUNCTION is safer than recreating (no logic changes, no risk
-- of accidentally breaking the function body).
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- finance_reports.sql — 6 SECURITY DEFINER functions, all missing search_path
-- ─────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.report_sales_summary(UUID, DATE, DATE, TEXT)
    SET search_path = public;

ALTER FUNCTION public.report_sales_by_item(UUID, DATE, DATE, INT)
    SET search_path = public;

ALTER FUNCTION public.report_sales_by_customer(UUID, DATE, DATE, INT)
    SET search_path = public;

ALTER FUNCTION public.report_invoice_list(UUID, DATE, DATE, TEXT, TEXT)
    SET search_path = public;

ALTER FUNCTION public.report_payment_summary(UUID, DATE, DATE)
    SET search_path = public;

ALTER FUNCTION public.get_finance_overview(UUID, DATE, DATE)
    SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- inventory_module_functions.sql — no SECURITY DEFINER but add path for safety
-- These run as the calling user (SECURITY INVOKER by default) but pinning the
-- search_path prevents confusion if the DB ever has non-public schemas.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
    fn TEXT;
BEGIN
    FOR fn IN SELECT unnest(ARRAY[
        'generate_inv_doc_number(uuid,text)',
        'generate_item_code(uuid)',
        'generate_supplier_code(uuid)',
        'update_stock_on_hand(uuid,uuid,uuid,numeric,numeric)',
        'validate_sufficient_stock(uuid,uuid,numeric)',
        'validate_warehouse_exists(uuid)',
        'validate_item_exists(uuid)',
        'validate_document_lines(uuid)',
        'validate_not_already_posted(uuid)',
        'block_posted_doc_edit()',
        'block_line_edit_on_posted()',
        'post_inventory_document()'
    ])
    LOOP
        BEGIN
            EXECUTE format('ALTER FUNCTION public.%s SET search_path = public', fn);
        EXCEPTION WHEN undefined_function THEN
            RAISE NOTICE 'Function public.% not found, skipping', fn;
        END;
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- dashboard_rpc.sql — add search_path (SECURITY INVOKER, best practice)
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
    fn TEXT;
BEGIN
    FOR fn IN SELECT unnest(ARRAY[
        'dashboard_kpis(uuid,date,date)',
        'dashboard_trends(uuid,date,date,text)',
        'dashboard_collections_due(uuid,integer)',
        'dashboard_top_items(uuid,date,date,text,integer)',
        'dashboard_top_customers(uuid,date,date,text,integer)',
        'dashboard_payment_methods(uuid,date,date)'
    ])
    LOOP
        BEGIN
            EXECUTE format('ALTER FUNCTION public.%s SET search_path = public', fn);
        EXCEPTION WHEN undefined_function THEN
            RAISE NOTICE 'Function public.% not found, skipping', fn;
        END;
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- global_search — add search_path
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
    BEGIN
        ALTER FUNCTION public.global_search(UUID, TEXT, INT) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN
        RAISE NOTICE 'global_search not found, skipping';
    END;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify (run manually to confirm):
-- SELECT proname, proconfig FROM pg_proc
-- WHERE pronamespace = 'public'::regnamespace
--   AND prosecdef = true
--   AND (proconfig IS NULL OR NOT proconfig @> ARRAY['search_path=public'])
-- ORDER BY proname;
-- ─────────────────────────────────────────────────────────────────────────────

COMMIT;

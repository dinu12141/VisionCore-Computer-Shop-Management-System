-- ============================================================================
-- MIGRATION: Fix Remaining Security Advisor Errors & Warnings
-- Date: 2026-03-05
-- Description:
-- 1. Enables RLS on the last 8 dangling tables identified in Supabase.
-- 2. Secures functions by adding SET search_path = public (fixes 46 warnings).
-- Run securely in Supabase SQL Editor.
-- ============================================================================

DO $MAIN$
DECLARE
  tbl TEXT;
  has_company BOOLEAN;
  r RECORD;
BEGIN

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. RLS FOR THE REMAINING 8 ERRORS
-- ─────────────────────────────────────────────────────────────────────────────
FOREACH tbl IN ARRAY ARRAY[
  'stores', 
  'service_device_types', 
  'item_serials', 
  'invoice_payments',
  'reminder_settings', 
  'reminder_logs', 
  'kot_print_logs', 
  'order_acceptance'
]
LOOP
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = tbl
  ) THEN
    -- Enable RLS
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
    
    -- Check if it has a company_id column to scope properly
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema='public' AND table_name=tbl AND column_name='company_id'
    ) INTO has_company;

    IF has_company THEN
      EXECUTE format('DROP POLICY IF EXISTS "%s_company" ON %I', tbl, tbl);
      EXECUTE format($p$
        CREATE POLICY "%s_company" ON %I FOR ALL TO authenticated
        USING (company_id = get_my_company_id()) 
        WITH CHECK (company_id = get_my_company_id())
      $p$, tbl, tbl);
      RAISE NOTICE 'RLS scoped to company: %', tbl;
    ELSE
      -- Fallback to authenticated users if no company_id is found
      EXECUTE format('DROP POLICY IF EXISTS "%s_auth" ON %I', tbl, tbl);
      EXECUTE format($p$
        CREATE POLICY "%s_auth" ON %I FOR ALL TO authenticated USING (true) WITH CHECK (true)
      $p$, tbl, tbl);
      RAISE NOTICE 'RLS set to authenticated: %', tbl;
    END IF;

  END IF;
END LOOP;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. FIX FUNCTION SEARCH PATH MUTABILITY WARNINGS
-- ─────────────────────────────────────────────────────────────────────────────
-- Supabase Security Advisor recommends functions have securely set search_paths
-- Loop through all functions in public schema and safely set search_path
FOR r IN 
    SELECT p.proname AS func_name, 
           pg_get_function_identity_arguments(p.oid) AS func_args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.prokind IN ('f', 'p') -- functions and procedures
      AND p.proname NOT LIKE 'pg_%'
LOOP
    BEGIN
      -- We attempt to apply search_path = public to secure the functions
      EXECUTE format('ALTER FUNCTION public.%I(%s) SET search_path = public', r.func_name, r.func_args);
    EXCEPTION WHEN OTHERS THEN
      -- Ignore errors for extensions or incompatible procedures
      RAISE NOTICE 'Skipping function: %', r.func_name;
    END;
END LOOP;

END $MAIN$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RESULT CHECKS
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
  'Functions fixed' AS checklist_item, 
  count(*) AS total 
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND proconfig IS NOT NULL;

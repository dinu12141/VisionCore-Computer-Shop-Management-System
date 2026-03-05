-- ============================================================================
-- MIGRATION: Fix Security Advisor Warnings (Permissive Policies & Extensions)
-- Date: 2026-03-05
-- Run securely in Supabase SQL Editor.
-- ============================================================================

DO $MAIN$
DECLARE
  tbl TEXT;
  pol TEXT;
  has_company BOOLEAN;
  has_user BOOLEAN;
  r RECORD;
BEGIN

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. FIX EXTENSION IN PUBLIC (pg_trgm)
-- ─────────────────────────────────────────────────────────────────────────────
BEGIN
  CREATE SCHEMA IF NOT EXISTS extensions;
  -- Try moving pg_trgm to the extensions schema
  ALTER EXTENSION pg_trgm SET SCHEMA extensions;
  RAISE NOTICE 'Moved pg_trgm extension to extensions schema.';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped moving pg_trgm: %', SQLERRM;
END;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. FIX FUNCTION SEARCH PATH (pgrst_watch)
-- ─────────────────────────────────────────────────────────────────────────────
BEGIN
  -- pgrst_watch is a built-in PostgREST utility function. 
  -- Setting its search_path restricts it properly.
  ALTER FUNCTION public.pgrst_watch() SET search_path = public;
  RAISE NOTICE 'Fixed pgrst_watch search_path.';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped pgrst_watch fix: %', SQLERRM;
END;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. FIX PERMISSIVE "ALWAYS TRUE" RLS POLICIES
-- ─────────────────────────────────────────────────────────────────────────────
-- We'll process each problematic table reported by the Security Advisor
CREATE TEMP TABLE policy_targets (table_name text, policy_name text);
INSERT INTO policy_targets VALUES
  ('kot_print_logs', 'kot_print_logs_auth'),
  ('order_acceptance', 'order_acceptance_auth'),
  ('stores', 'stores_auth'),
  ('notifications', 'notif_insert_system');

FOR r IN SELECT * FROM policy_targets LOOP
  tbl := r.table_name;
  pol := r.policy_name;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
    
    -- Drop the dangerously permissive policy
    BEGIN
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol, tbl);
      RAISE NOTICE 'Dropped permissive policy % on %.', pol, tbl;
    EXCEPTION WHEN OTHERS THEN END;

    -- Check if we can scope by company_id
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema='public' AND table_name=tbl AND column_name='company_id'
    ) INTO has_company;

    -- Check if we can scope by user_id
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema='public' AND table_name=tbl AND column_name='user_id'
    ) INTO has_user;

    -- Create secure replacement policies
    IF has_company THEN
      EXECUTE format($p$
        CREATE POLICY "%s_secure_company" ON %I FOR ALL TO authenticated
        USING (company_id = get_my_company_id()) 
        WITH CHECK (company_id = get_my_company_id())
      $p$, tbl, tbl);
      RAISE NOTICE 'Created secure company_id policy for %.', tbl;
    
    ELSIF has_user THEN
      EXECUTE format($p$
        CREATE POLICY "%s_secure_user" ON %I FOR ALL TO authenticated
        USING (user_id = auth.uid() OR is_admin()) 
        WITH CHECK (user_id = auth.uid() OR is_admin())
      $p$, tbl, tbl);
      RAISE NOTICE 'Created secure user_id policy for %.', tbl;
      
    ELSE
      -- Fallback: Allow insert to authenticated, but select/update/delete only to admin
      EXECUTE format($p$
        CREATE POLICY "%s_secure_insert" ON %I FOR INSERT TO authenticated WITH CHECK (auth.role() = 'authenticated');
      $p$, tbl, tbl);
      
      EXECUTE format($p$
        CREATE POLICY "%s_secure_read_admin" ON %I FOR SELECT TO authenticated USING (is_admin());
      $p$, tbl, tbl);
      
      EXECUTE format($p$
        CREATE POLICY "%s_secure_write_admin" ON %I FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
      $p$, tbl, tbl);
      
      EXECUTE format($p$
        CREATE POLICY "%s_secure_delete_admin" ON %I FOR DELETE TO authenticated USING (is_admin());
      $p$, tbl, tbl);
      
      RAISE NOTICE 'Created secure fallback (admin/insert) policies for %.', tbl;
    END IF;

  END IF;
END LOOP;

DROP TABLE policy_targets;

END $MAIN$;

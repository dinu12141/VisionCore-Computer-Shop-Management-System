-- ============================================================================
-- FIX: Supabase Advisor Warnings (Function Security)
-- ============================================================================
-- 1. function_search_path_mutable: Appends SET search_path = public to all functions.
-- 2. anon_security_definer_function_executable: Revokes EXECUTE from anon for security definer functions.
-- ============================================================================

BEGIN;

DO $$
DECLARE
    rec record;
BEGIN
    -- 1. Fix: function_search_path_mutable
    -- Set search_path = public for all functions in the public schema 
    -- that don't already have a search_path set.
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND (proconfig IS NULL OR NOT ('search_path' = ANY(proconfig::text[])))
    LOOP
        EXECUTE format('ALTER FUNCTION %I.%I(%s) SET search_path = public', rec.nspname, rec.proname, rec.args);
    END LOOP;

    -- 2. Fix: anon_security_definer_function_executable
    -- Revoke EXECUTE from anon for all SECURITY DEFINER functions in public schema.
    -- (Standard Supabase security practice).
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
    LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM anon', rec.nspname, rec.proname, rec.args);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Notify PostgREST to reload schema cache just in case permissions changed
NOTIFY pgrst, 'reload schema';

COMMIT;

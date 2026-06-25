-- ============================================================================
-- FIX: Invoice Creation 400 Error (Search Path Issue)
-- ============================================================================
-- The previous migration aggressively set search_path = public on ALL functions.
-- This caused triggers that insert into tables with uuid_generate_v4() defaults
-- to fail, because uuid_generate_v4 is in the extensions schema.
-- This migration reverts search_path for normal functions and includes extensions
-- for SECURITY DEFINER functions.

BEGIN;

DO $$
DECLARE
    rec record;
BEGIN
    -- 1. Reset search_path for all NON-security definer functions in public
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = false
    LOOP
        EXECUTE format('ALTER FUNCTION %I.%I(%s) RESET search_path', rec.nspname, rec.proname, rec.args);
    END LOOP;

    -- 2. Set search_path = 'public, extensions' for all SECURITY DEFINER functions
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
    LOOP
        EXECUTE format('ALTER FUNCTION %I.%I(%s) SET search_path = public, extensions', rec.nspname, rec.proname, rec.args);
    END LOOP;
END;
$$;

COMMIT;

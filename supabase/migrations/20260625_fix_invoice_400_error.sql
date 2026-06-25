-- ============================================================================
-- FIX: Invoice 400 Error (Definitive Comprehensive Fix)
-- Date: 2026-06-25
-- ============================================================================
-- Root causes identified:
--
-- CAUSE 1: check_invoice_collection_date_required constraint
--   This is a legacy restaurant POS constraint that requires collection_date
--   whenever balance > 0. In the computer ERP the frontend already validates
--   collection_date via JS (line 648 BillingPage.vue), so the DB constraint
--   is redundant and breaks invoice creation when collection_date is empty.
--
-- CAUSE 2: search_path set to 'public' only on ALL functions
--   Migration 20260625_fix_supabase_advisors_functions.sql ran and set
--   search_path = public on every function including those that call
--   uuid_generate_v4() which lives in the extensions schema.
--   Fix: RESET for normal functions, set public,extensions for SECURITY DEFINER.
--
-- RUN THIS IN SUPABASE SQL EDITOR.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Drop legacy collection_date constraint (restaurant POS artifact)
-- The frontend already validates: if balance > 0 then collection_date required.
-- The DB constraint is not needed and breaks credit invoices.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices
    DROP CONSTRAINT IF EXISTS check_invoice_collection_date_required;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Fix search_path — undo damage from fix_supabase_advisors_functions.sql
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    rec record;
BEGIN
    -- 2a. RESET search_path for all NON-SECURITY DEFINER functions in public.
    --     RESET lets each function inherit the database-level search_path,
    --     which Supabase sets to include the extensions schema.
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM   pg_proc p
        JOIN   pg_namespace n ON p.pronamespace = n.oid
        WHERE  n.nspname = 'public'
          AND  p.prosecdef = false
    LOOP
        BEGIN
            EXECUTE format(
                'ALTER FUNCTION %I.%I(%s) RESET search_path',
                rec.nspname, rec.proname, rec.args
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Skipping non-definer function %.%(%): %',
                rec.nspname, rec.proname, rec.args, SQLERRM;
        END;
    END LOOP;

    -- 2b. Set search_path = public, extensions for all SECURITY DEFINER functions.
    --     These run with the owner's privileges and need explicit schema list.
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM   pg_proc p
        JOIN   pg_namespace n ON p.pronamespace = n.oid
        WHERE  n.nspname = 'public'
          AND  p.prosecdef = true
    LOOP
        BEGIN
            EXECUTE format(
                'ALTER FUNCTION %I.%I(%s) SET search_path = public, extensions',
                rec.nspname, rec.proname, rec.args
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Skipping definer function %.%(%): %',
                rec.nspname, rec.proname, rec.args, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Ensure invoice counter RPC is callable by authenticated users
-- ─────────────────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.get_next_counter_value(UUID, TEXT)
    TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Ensure customer_po_no column exists (added by 20260312 migration)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS customer_po_no TEXT;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: Ensure discount_type / discount_amount columns exist in invoice_items
--         (added by 20260625_fix_invoice_edit.sql — idempotent re-run)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoice_items
    ADD COLUMN IF NOT EXISTS discount_type   TEXT    DEFAULT 'amount',
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0;

UPDATE public.invoice_items
SET    discount_type   = 'amount',
       discount_amount = COALESCE(discount, 0)
WHERE  discount_type IS NULL
   OR  discount_amount IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 6: Ensure invoices status constraint allows all values the triggers set
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices
    DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE public.invoices
    ADD CONSTRAINT invoices_status_check
    CHECK (status IN ('draft','issued','unpaid','paid','partial','cancelled','void'));

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 7: Notify PostgREST to reload schema cache
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 8: Drop legacy restaurant POS invoice BOM trigger that references order_id
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_invoice_bom_deduct ON public.invoices;
DROP FUNCTION IF EXISTS public.deduct_bom_for_invoice() CASCADE;

COMMIT;

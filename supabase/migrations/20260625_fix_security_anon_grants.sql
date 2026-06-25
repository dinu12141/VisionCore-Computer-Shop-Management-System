-- ============================================================================
-- SECURITY FIX: Revoke dangerous anon grants
-- Date: 2026-06-25
-- Auditor: Riley (QA/Security)
-- Lead sign-off: Alex
--
-- CRIT-001: create_invoice_v2 and update_invoice_v2 are SECURITY DEFINER
--   functions that bypass RLS. Granting EXECUTE to `anon` means anyone with
--   the public anon key (embedded in the JS bundle) can create/modify invoices
--   and trigger stock movements without authentication.
--
-- CRIT-002: v_items_registry granted to anon. While security_invoker=true
--   makes it "safe by accident" (RLS returns 0 rows for anon), the explicit
--   grant should be revoked — relying on "safe by accident" is not acceptable.
--
-- HIGH-001: global_search RPC callable by anon. An unauthenticated caller
--   can supply any company_id UUID and enumerate items, customers, invoices.
--
-- HIGH-003 (additional): search_outstanding_invoices, search_collection_history,
--   get_upcoming_reminders all granted to anon. Financial data functions must
--   be authenticated-only.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- CRIT-001: Invoice RPCs — revoke anon, keep authenticated + service_role
-- ─────────────────────────────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB)
    FROM anon;

REVOKE EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB)
    FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- CRIT-002: v_items_registry — revoke anon SELECT
-- ─────────────────────────────────────────────────────────────────────────────

REVOKE SELECT ON public.v_items_registry FROM anon;

-- Also revoke from other inventory views that should be authenticated-only
REVOKE SELECT ON public.v_stock_on_hand     FROM anon;
REVOKE SELECT ON public.v_inventory_ledger  FROM anon;
REVOKE SELECT ON public.v_low_stock_alerts  FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- HIGH-001: global_search — revoke anon
-- Authenticated users are already scoped by company_id inside the function.
-- ─────────────────────────────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.global_search(UUID, TEXT, INT) FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- HIGH-003 (additional): Financial / collections RPCs — revoke anon
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
    -- search_outstanding_invoices has two overloads
    BEGIN
        REVOKE EXECUTE ON FUNCTION public.search_outstanding_invoices(UUID, TEXT, DATE, DATE, UUID, BOOLEAN) FROM anon;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;

    BEGIN
        REVOKE EXECUTE ON FUNCTION public.search_outstanding_invoices(TEXT, DATE, DATE, UUID, BOOLEAN) FROM anon;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;

    BEGIN
        REVOKE EXECUTE ON FUNCTION public.search_collection_history(UUID, TEXT, DATE, DATE, UUID) FROM anon;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;

    BEGIN
        REVOKE EXECUTE ON FUNCTION public.get_upcoming_reminders(UUID, INTEGER) FROM anon;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- HIGH-002: Add auth.uid() guard inside invoice RPCs as defence-in-depth.
--   Even if anon somehow calls them, the function itself should reject.
--   We patch create_invoice_v2 and update_invoice_v2 by adding an early exit.
--   Full function rewrites are in their respective migration files — here we
--   only add the null-uid guard via a wrapper check using DO block to verify
--   the pattern works, then note it must be applied to the full function bodies.
-- NOTE: Full fix requires recreating both RPCs with the guard at the top.
--   This migration covers the GRANT revocation (immediate protection).
--   See HIGH-002-PENDING comment below for the remaining remediation.
-- ─────────────────────────────────────────────────────────────────────────────
-- HIGH-002-PENDING: Recreate create_invoice_v2 and update_invoice_v2 with:
--   IF auth.uid() IS NULL THEN
--       RAISE EXCEPTION 'UNAUTHORIZED: authentication required.';
--   END IF;
-- at the top of each function body. This is a defence-in-depth measure.
-- The anon REVOKE above is the primary fix; this is belt-and-suspenders.
-- ─────────────────────────────────────────────────────────────────────────────

COMMIT;

-- Verification queries (run manually to confirm):
-- SELECT has_function_privilege('anon', 'public.create_invoice_v2(jsonb,jsonb,jsonb)', 'execute'); -- should return false
-- SELECT has_function_privilege('anon', 'public.update_invoice_v2(uuid,jsonb,jsonb)', 'execute');  -- should return false
-- SELECT has_table_privilege('anon', 'public.v_items_registry', 'select');                         -- should return false

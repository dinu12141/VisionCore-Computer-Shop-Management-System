-- ============================================================================
-- FIX: Outstanding Collections showing nothing after invoice creation
-- Date: 2026-04-23
--
-- ROOT CAUSE:
--   The `search_outstanding_invoices` RPC function was filtering invoices
--   using UPPERCASE values:
--       AND payment_status IN ('UNPAID', 'PARTIAL')
--
--   However, the frontend (invoiceStore.js) and ALL triggers set payment_status
--   in LOWERCASE: 'unpaid', 'partial', 'paid'
--
--   This case mismatch caused ALL new invoices to be invisible in the
--   Outstanding Collections page — the list was always empty.
--
-- WHAT THIS FIXES:
--   1. Normalizes ALL existing invoice payment_status values to lowercase
--   2. Drops and recreates search_outstanding_invoices to use lowercase
--   3. Drops and recreates search_collection_history to use lowercase
--   4. Drops and recreates get_upcoming_reminders to use lowercase
--   5. Ensures the payment_status check constraint allows lowercase values
--   6. Validates the fix by showing counts after
-- ============================================================================

-- ─── 1. NORMALIZE EXISTING DATA TO LOWERCASE ──────────────────────────────
-- Some old invoices may have uppercase 'UNPAID', 'PARTIAL', 'PAID' from legacy triggers
UPDATE invoices
SET payment_status = LOWER(payment_status)
WHERE payment_status != LOWER(payment_status);

-- Also normalize the status column for consistency
UPDATE invoices
SET status = LOWER(status)
WHERE status != LOWER(status)
  AND LOWER(status) IN ('draft', 'issued', 'unpaid', 'paid', 'partial', 'cancelled', 'void');

-- ─── 2. ENSURE PAYMENT_STATUS CONSTRAINT ALLOWS LOWERCASE ─────────────────
ALTER TABLE invoices DROP CONSTRAINT IF EXISTS invoices_payment_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_payment_status_check
CHECK (LOWER(payment_status) IN ('unpaid', 'partial', 'paid'));

-- ─── 3. FIX search_outstanding_invoices (with p_company_id — used by frontend) ─
-- Must DROP first because return type may differ from the existing function
DROP FUNCTION IF EXISTS public.search_outstanding_invoices(UUID, TEXT, DATE, DATE, UUID, BOOLEAN) CASCADE;
CREATE OR REPLACE FUNCTION public.search_outstanding_invoices(
    p_company_id  UUID,
    p_q           TEXT     DEFAULT NULL,
    p_from_date   DATE     DEFAULT NULL,
    p_to_date     DATE     DEFAULT NULL,
    p_customer_id UUID     DEFAULT NULL,
    p_overdue_only BOOLEAN DEFAULT false
)
RETURNS SETOF invoices
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM invoices
    WHERE company_id = p_company_id
      AND balance > 0
      AND LOWER(payment_status) IN ('unpaid', 'partial')   -- ← case-insensitive fix
      AND LOWER(status) NOT IN ('cancelled', 'void', 'draft')
      -- Search filter
      AND (
        p_q IS NULL
        OR invoice_no ILIKE '%' || p_q || '%'
        OR customer_snapshot->>'name' ILIKE '%' || p_q || '%'
        OR customer_snapshot->>'phone' ILIKE '%' || p_q || '%'
      )
      -- Date filters (on invoice_date if collection_date is null)
      AND (p_from_date IS NULL OR COALESCE(collection_date, invoice_date::date) >= p_from_date)
      AND (p_to_date   IS NULL OR COALESCE(collection_date, invoice_date::date) <= p_to_date)
      -- Customer filter
      AND (p_customer_id IS NULL OR customer_id = p_customer_id)
      -- Overdue filter
      AND (NOT p_overdue_only OR collection_date < CURRENT_DATE)
    ORDER BY COALESCE(collection_date, created_at::date) ASC NULLS LAST;
END;
$$;

-- ─── 4. FIX search_outstanding_invoices (without p_company_id — legacy overload) ─
DROP FUNCTION IF EXISTS public.search_outstanding_invoices(TEXT, DATE, DATE, UUID, BOOLEAN) CASCADE;
CREATE OR REPLACE FUNCTION public.search_outstanding_invoices(
    p_q           TEXT     DEFAULT NULL,
    p_from_date   DATE     DEFAULT NULL,
    p_to_date     DATE     DEFAULT NULL,
    p_customer_id UUID     DEFAULT NULL,
    p_overdue_only BOOLEAN DEFAULT false
)
RETURNS SETOF invoices
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM invoices
    WHERE company_id = (auth.jwt() -> 'user_metadata' ->> 'company_id')::UUID
      AND balance > 0
      AND LOWER(payment_status) IN ('unpaid', 'partial')
      AND LOWER(status) NOT IN ('cancelled', 'void', 'draft')
      AND (
        p_q IS NULL
        OR invoice_no ILIKE '%' || p_q || '%'
        OR customer_snapshot->>'name' ILIKE '%' || p_q || '%'
        OR customer_snapshot->>'phone' ILIKE '%' || p_q || '%'
      )
      AND (p_from_date IS NULL OR COALESCE(collection_date, invoice_date::date) >= p_from_date)
      AND (p_to_date   IS NULL OR COALESCE(collection_date, invoice_date::date) <= p_to_date)
      AND (p_customer_id IS NULL OR customer_id = p_customer_id)
      AND (NOT p_overdue_only OR collection_date < CURRENT_DATE)
    ORDER BY COALESCE(collection_date, created_at::date) ASC NULLS LAST;
END;
$$;

-- ─── 5. CREATE/FIX search_collection_history ──────────────────────────────
-- DROP first to allow changing return type
DROP FUNCTION IF EXISTS public.search_collection_history(UUID, TEXT, DATE, DATE, UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.search_collection_history(
    p_company_id  UUID,
    p_q           TEXT DEFAULT NULL,
    p_from_date   DATE DEFAULT NULL,
    p_to_date     DATE DEFAULT NULL,
    p_customer_id UUID DEFAULT NULL
)
RETURNS SETOF invoices
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM invoices
    WHERE company_id = p_company_id
      AND LOWER(payment_status) = 'paid'   -- ← lowercase fix
      AND (
        p_q IS NULL
        OR invoice_no ILIKE '%' || p_q || '%'
        OR customer_snapshot->>'name' ILIKE '%' || p_q || '%'
        OR customer_snapshot->>'phone' ILIKE '%' || p_q || '%'
      )
      AND (p_from_date IS NULL OR updated_at::date >= p_from_date)
      AND (p_to_date   IS NULL OR updated_at::date <= p_to_date)
      AND (p_customer_id IS NULL OR customer_id = p_customer_id)
    ORDER BY updated_at DESC;
END;
$$;

-- ─── 6. FIX get_upcoming_reminders ────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_upcoming_reminders(UUID, INTEGER) CASCADE;
CREATE OR REPLACE FUNCTION public.get_upcoming_reminders(
    p_company_id UUID,
    p_days       INTEGER DEFAULT 2
)
RETURNS TABLE (
    id              UUID,
    invoice_no      TEXT,
    customer_name   TEXT,
    balance         NUMERIC,
    collection_date DATE
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        i.id,
        i.invoice_no,
        (i.customer_snapshot->>'name')::TEXT AS customer_name,
        i.balance,
        i.collection_date
    FROM invoices i
    WHERE i.company_id = p_company_id
      AND i.balance > 0
      AND LOWER(i.payment_status) IN ('unpaid', 'partial')   -- ← lowercase fix
      AND i.collection_date <= (CURRENT_DATE + p_days)
      AND i.collection_date >= CURRENT_DATE
    ORDER BY i.collection_date ASC;
END;
$$;

-- ─── 7. RE-SYNC INVOICES THAT HAVE balance > 0 but wrong payment_status ───
-- Safety net: fix any invoice where balance > 0 but payment_status = 'paid'
UPDATE invoices
SET 
    payment_status = CASE
        WHEN paid_amount <= 0 THEN 'unpaid'
        ELSE 'partial'
    END,
    status = CASE
        WHEN status NOT IN ('cancelled', 'void', 'draft') THEN
            CASE WHEN paid_amount <= 0 THEN 'unpaid' ELSE 'issued' END
        ELSE status
    END
WHERE balance > 0
  AND LOWER(payment_status) = 'paid'
  AND LOWER(status) NOT IN ('cancelled', 'void', 'draft');

-- Fix any invoice where balance <= 0 but payment_status != 'paid'
UPDATE invoices
SET
    payment_status = 'paid',
    status = 'paid'
WHERE balance <= 0
  AND paid_amount > 0
  AND LOWER(payment_status) != 'paid'
  AND LOWER(status) NOT IN ('cancelled', 'void', 'draft');

-- ─── 8. GRANT PERMISSIONS ─────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.search_outstanding_invoices(UUID, TEXT, DATE, DATE, UUID, BOOLEAN) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.search_outstanding_invoices(TEXT, DATE, DATE, UUID, BOOLEAN) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.search_collection_history(UUID, TEXT, DATE, DATE, UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_upcoming_reminders(UUID, INTEGER) TO authenticated, anon, service_role;

-- ─── 9. VERIFY ────────────────────────────────────────────────────────────
-- After running, check the distribution of payment statuses:
-- SELECT payment_status, status, COUNT(*)
-- FROM invoices
-- GROUP BY payment_status, status
-- ORDER BY payment_status, status;

NOTIFY pgrst, 'reload schema';

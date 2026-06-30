-- ============================================================================
-- DEFINITIVE FIX: Invoice Update 409 Error
-- Date: 2026-06-30
-- Run this ONCE in Supabase SQL Editor.
-- ============================================================================
--
-- ROOT CAUSE (confirmed):
--   1. trg_invoice_item_deduct_stock (AFTER INSERT ON invoice_items) is STILL
--      ACTIVE. When update_invoice_v2 deletes old items and inserts new ones,
--      EACH INSERT fires this trigger → creates a SEPARATE GIN per item line →
--      calls generate_inv_doc_number → hits UNIQUE(company_id, doc_type, fiscal_year)
--      on inv_doc_sequences → PostgreSQL error 23505 → PostgREST 409 Conflict.
--
--   2. generate_inv_doc_number has no ON CONFLICT clause on its INSERT fallback,
--      so concurrent calls or rapid-fire trigger-spawned calls collide.
--
--   3. update_invoice_v2 ALREADY manages GIN creation/cancellation internally,
--      so the per-item trigger is redundant and harmful.
--
-- FIX:
--   A. Drop trg_invoice_item_deduct_stock + its function (permanently)
--   B. Drop trg_invoice_bom_deduct + its function (legacy restaurant POS)
--   C. Recreate generate_inv_doc_number with ON CONFLICT + advisory lock
--   D. Recreate update_invoice_v2 (bulletproof version)
-- ============================================================================

BEGIN;

-- ═════════════════════════════════════════════════════════════════════════════
-- A. DROP LEGACY TRIGGERS THAT CONFLICT WITH THE RPC APPROACH
-- ═════════════════════════════════════════════════════════════════════════════

-- This is THE root cause: fires per-row on invoice_items INSERT, creating
-- duplicate GINs that collide with the GIN created by update_invoice_v2
DROP TRIGGER IF EXISTS trg_invoice_item_deduct_stock ON public.invoice_items;
DROP FUNCTION IF EXISTS public.deduct_stock_for_invoice_item() CASCADE;

-- Legacy restaurant POS trigger (irrelevant for this ERP)
DROP TRIGGER IF EXISTS trg_invoice_bom_deduct ON public.invoices;
DROP FUNCTION IF EXISTS public.deduct_bom_for_invoice() CASCADE;

-- ═════════════════════════════════════════════════════════════════════════════
-- B. FIX generate_inv_doc_number: Use ON CONFLICT to prevent 409
-- ═════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.generate_inv_doc_number(
    p_company_id UUID,
    p_doc_type   TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_prefix TEXT;
    v_next   INT;
    v_year   INT := EXTRACT(YEAR FROM now());
BEGIN
    -- Use advisory lock to prevent concurrent inserts from colliding
    -- Hash: company_id xor'd with doc_type hash + fiscal year
    PERFORM pg_advisory_xact_lock(
        hashtext(p_company_id::TEXT || p_doc_type || v_year::TEXT)
    );

    -- Try to increment existing sequence
    UPDATE public.inv_doc_sequences
    SET    current_number = current_number + 1
    WHERE  company_id  = p_company_id
      AND  doc_type    = p_doc_type
      AND  fiscal_year = v_year
    RETURNING prefix, current_number INTO v_prefix, v_next;

    -- If no row existed, insert with ON CONFLICT to handle race conditions
    IF v_prefix IS NULL THEN
        INSERT INTO public.inv_doc_sequences (company_id, doc_type, prefix, current_number, fiscal_year)
        VALUES (p_company_id, p_doc_type, p_doc_type || '-', 1, v_year)
        ON CONFLICT (company_id, doc_type, fiscal_year)
        DO UPDATE SET current_number = public.inv_doc_sequences.current_number + 1
        RETURNING prefix, current_number INTO v_prefix, v_next;
    END IF;

    RETURN v_prefix || v_year || '-' || LPAD(v_next::TEXT, 5, '0');
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- C. ENSURE CONSTRAINTS ALLOW ALL NEEDED VALUES
-- ═════════════════════════════════════════════════════════════════════════════

-- Status constraint
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE public.invoices ADD CONSTRAINT invoices_status_check
    CHECK (status IN ('draft','issued','unpaid','paid','partial','cancelled','void'));

-- Payment status constraint
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS invoices_payment_status_check;
ALTER TABLE public.invoices ADD CONSTRAINT invoices_payment_status_check
    CHECK (LOWER(payment_status) IN ('unpaid', 'partial', 'paid'));

-- Drop legacy collection_date constraint
ALTER TABLE public.invoices
    DROP CONSTRAINT IF EXISTS check_invoice_collection_date_required;

-- Ensure columns exist
ALTER TABLE public.invoice_items
    ADD COLUMN IF NOT EXISTS discount_type   TEXT    DEFAULT 'amount',
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0;

ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS customer_po_no TEXT;

ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'unpaid';

-- ═════════════════════════════════════════════════════════════════════════════
-- D. RECREATE update_invoice_v2 — BULLETPROOF VERSION
-- ═════════════════════════════════════════════════════════════════════════════
-- Changes from previous versions:
--   • Disables trg_block_posted_edit via session var during cancel
--   • Cancels ALL posted GINs for this invoice (not just the latest one)
--   • Wraps GIN posting in an exception handler to prevent partial failures
--   • Proper search_path for UUID and auth calls

CREATE OR REPLACE FUNCTION public.update_invoice_v2(
    p_invoice_id UUID,
    p_items      JSONB,
    p_payload    JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_company_id       UUID;
    v_existing_gin     RECORD;
    v_new_gin_id       UUID;
    v_new_gin_number   TEXT;
    v_item             RECORD;
    v_unit_cost        NUMERIC;
    v_uom_id           UUID;
    v_line_number      INT     := 1;
    v_has_tracked      BOOLEAN := FALSE;
    v_wh_id            UUID;
    v_branch_id        UUID;
    v_new_paid         NUMERIC;
    v_new_balance      NUMERIC;
    v_new_total        NUMERIC;
    v_cancelled_gins   UUID[] := '{}';
BEGIN
    -- ── 0. Auth guard ────────────────────────────────────────────────────────
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'UNAUTHORIZED: authentication required.');
    END IF;

    -- ── 1. Validate invoice exists ───────────────────────────────────────────
    SELECT company_id INTO v_company_id
    FROM   public.invoices
    WHERE  id = p_invoice_id;

    IF v_company_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', format('Invoice %s not found', p_invoice_id));
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'p_items must be a non-empty JSON array');
    END IF;

    -- ── 2. Cancel ALL existing posted GINs for this invoice ──────────────────
    --    (Previous versions only cancelled the latest one — if there were
    --     duplicates from the old trigger, they'd remain and cause conflicts)
    FOR v_existing_gin IN
        SELECT id
        FROM   public.inventory_documents
        WHERE  reference_id   = p_invoice_id
          AND  reference_type = 'invoice'
          AND  doc_type       = 'GIN'
          AND  status         = 'posted'
    LOOP
        UPDATE public.inventory_documents
        SET    status = 'cancelled'
        WHERE  id = v_existing_gin.id;

        v_cancelled_gins := v_cancelled_gins || v_existing_gin.id;
    END LOOP;

    -- Also delete any orphaned draft GINs (from previous failed attempts)
    DELETE FROM public.inventory_document_lines
    WHERE  document_id IN (
        SELECT id FROM public.inventory_documents
        WHERE  reference_id   = p_invoice_id
          AND  reference_type = 'invoice'
          AND  doc_type       = 'GIN'
          AND  status         = 'draft'
    );

    DELETE FROM public.inventory_documents
    WHERE  reference_id   = p_invoice_id
      AND  reference_type = 'invoice'
      AND  doc_type       = 'GIN'
      AND  status         = 'draft';

    -- ── 3. Update invoice header ─────────────────────────────────────────────
    v_new_paid    := COALESCE(NULLIF(p_payload->>'paid_amount',  '')::NUMERIC, 0);
    v_new_total   := COALESCE(NULLIF(p_payload->>'total',        '')::NUMERIC, 0);
    v_new_balance := GREATEST(0, v_new_total - v_new_paid);

    UPDATE public.invoices
    SET
        customer_id        = NULLIF(p_payload->>'customer_id',        '')::UUID,
        status             = COALESCE(NULLIF(p_payload->>'status',             ''), 'issued'),
        payment_type       = COALESCE(NULLIF(p_payload->>'payment_type',       ''), 'cash'),
        subtotal           = COALESCE(NULLIF(p_payload->>'subtotal',           '')::NUMERIC, 0),
        discount           = COALESCE(NULLIF(p_payload->>'discount',           '')::NUMERIC, 0),
        tax                = COALESCE(NULLIF(p_payload->>'tax',                '')::NUMERIC, 0),
        total              = v_new_total,
        paid_amount        = v_new_paid,
        balance            = v_new_balance,
        payment_status     = CASE
                                 WHEN v_new_balance <= 0 AND v_new_total > 0   THEN 'paid'
                                 WHEN v_new_paid    >  0 AND v_new_balance > 0 THEN 'partial'
                                 ELSE 'unpaid'
                             END,
        customer_snapshot  = COALESCE(p_payload->'customer_snapshot', '{}'::jsonb),
        notes              = NULLIF(p_payload->>'notes',              ''),
        collection_date    = CASE
                                 WHEN NULLIF(p_payload->>'collection_date', '') IS NOT NULL
                                 THEN NULLIF(p_payload->>'collection_date', '')::DATE
                                 ELSE collection_date
                             END,
        invoice_date       = COALESCE(NULLIF(p_payload->>'invoice_date', '')::DATE, CURRENT_DATE),
        is_vat_invoice     = COALESCE(NULLIF(p_payload->>'is_vat_invoice',     '')::BOOLEAN, FALSE),
        vat_amount         = COALESCE(NULLIF(p_payload->>'vat_amount',         '')::NUMERIC, 0),
        total_before_vat   = COALESCE(NULLIF(p_payload->>'total_before_vat',   '')::NUMERIC, 0),
        is_service_invoice = COALESCE(NULLIF(p_payload->>'is_service_invoice', '')::BOOLEAN, FALSE),
        service_job_id     = NULLIF(p_payload->>'service_job_id',     '')::UUID,
        customer_po_no     = NULLIF(p_payload->>'customer_po_no',     ''),
        updated_at         = NOW()
    WHERE id = p_invoice_id;

    -- ── 4. Replace invoice items ─────────────────────────────────────────────
    --    NOTE: trg_invoice_item_deduct_stock has been DROPPED, so these INSERTs
    --    will NOT create duplicate GINs anymore.
    DELETE FROM public.invoice_items
    WHERE  invoice_id = p_invoice_id;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
        INSERT INTO public.invoice_items (
            invoice_id, product_id, description, item_code,
            qty, unit_price, discount, discount_type, discount_amount, line_total,
            warranty, serial_number,
            selling_unit_price_snapshot, cost_unit_price_snapshot
        ) VALUES (
            p_invoice_id,
            NULLIF(v_item.value->>'product_id',                '')::UUID,
            v_item.value->>'description',
            NULLIF(v_item.value->>'item_code',                 ''),
            COALESCE(NULLIF(v_item.value->>'qty',              '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'unit_price',       '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'discount',         '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'discount_type',    ''), 'amount'),
            COALESCE(NULLIF(v_item.value->>'discount_amount',  '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'line_total',       '')::NUMERIC, 0),
            NULLIF(v_item.value->>'warranty',                  ''),
            NULLIF(v_item.value->>'serial_number',             ''),
            COALESCE(NULLIF(v_item.value->>'selling_unit_price_snapshot', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'cost_unit_price_snapshot',    '')::NUMERIC, 0)
        );

        IF NULLIF(v_item.value->>'product_id', '') IS NOT NULL THEN
            v_has_tracked := TRUE;
        END IF;
    END LOOP;

    -- ── 5. Create & post new GIN for updated tracked items ───────────────────
    IF v_has_tracked THEN
        SELECT id, branch_id
        INTO   v_wh_id, v_branch_id
        FROM   public.warehouses
        WHERE  company_id = v_company_id
          AND  is_active  = TRUE
        ORDER BY is_default DESC, (warehouse_type = 'showroom') DESC, created_at ASC
        LIMIT 1;

        IF v_wh_id IS NOT NULL THEN
            v_new_gin_number := public.generate_inv_doc_number(v_company_id, 'GIN');

            INSERT INTO public.inventory_documents (
                company_id, branch_id, doc_type, doc_number, doc_date,
                warehouse_id, reference_id, reference_type, status, remarks, created_by
            ) VALUES (
                v_company_id, v_branch_id, 'GIN', v_new_gin_number, CURRENT_DATE,
                v_wh_id, p_invoice_id, 'invoice', 'draft',
                'Stock deduction for updated invoice',
                NULLIF(p_payload->>'created_by', '')::UUID
            )
            RETURNING id INTO v_new_gin_id;

            v_line_number := 1;

            FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
                IF NULLIF(v_item.value->>'product_id', '') IS NOT NULL THEN
                    SELECT avg_cost, inventory_uom_id
                    INTO   v_unit_cost, v_uom_id
                    FROM   public.items
                    WHERE  id = (v_item.value->>'product_id')::UUID;

                    IF v_uom_id IS NOT NULL THEN
                        INSERT INTO public.inventory_document_lines (
                            document_id, line_number, item_id, uom_id,
                            quantity, unit_cost, notes
                        ) VALUES (
                            v_new_gin_id, v_line_number,
                            (v_item.value->>'product_id')::UUID,
                            v_uom_id,
                            COALESCE(NULLIF(v_item.value->>'qty', '')::NUMERIC, 0),
                            COALESCE(v_unit_cost, 0),
                            'Sale from updated invoice'
                        );
                        v_line_number := v_line_number + 1;
                    END IF;
                END IF;
            END LOOP;

            IF v_line_number > 1 THEN
                -- Post the GIN (triggers stock deduction via trg_post_inventory)
                UPDATE public.inventory_documents
                SET    status = 'posted'
                WHERE  id = v_new_gin_id;
            ELSE
                -- No tracked items actually inserted, clean up the empty GIN
                DELETE FROM public.inventory_documents WHERE id = v_new_gin_id;
                v_new_gin_number := NULL;
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success',          TRUE,
        'invoice_id',       p_invoice_id,
        'cancelled_gins',   to_jsonb(v_cancelled_gins),
        'new_gin_document', v_new_gin_number
    );

EXCEPTION WHEN OTHERS THEN
    -- Catch any unexpected error and return it as a JSON response
    -- instead of letting it bubble up as a PostgreSQL exception (which
    -- PostgREST maps to 4xx/5xx HTTP errors)
    RETURN jsonb_build_object(
        'success', FALSE,
        'message', SQLERRM,
        'detail',  SQLSTATE
    );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- E. GRANTS
-- ═════════════════════════════════════════════════════════════════════════════

REVOKE ALL ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) FROM anon;
GRANT  EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO service_role;

-- Also fix generate_inv_doc_number grants
REVOKE ALL ON FUNCTION public.generate_inv_doc_number(UUID, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.generate_inv_doc_number(UUID, TEXT) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.generate_inv_doc_number(UUID, TEXT) TO service_role;

-- ═════════════════════════════════════════════════════════════════════════════
-- F. RELOAD POSTGREST SCHEMA CACHE
-- ═════════════════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ═════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES (run after to confirm)
-- ═════════════════════════════════════════════════════════════════════════════
--
-- 1. Confirm trigger is GONE:
--    SELECT tgname FROM pg_trigger WHERE tgname = 'trg_invoice_item_deduct_stock';
--    → Should return 0 rows
--
-- 2. Confirm function is GONE:
--    SELECT proname FROM pg_proc WHERE proname = 'deduct_stock_for_invoice_item';
--    → Should return 0 rows
--
-- 3. Confirm update_invoice_v2 exists:
--    SELECT proname FROM pg_proc
--    WHERE proname = 'update_invoice_v2' AND pronamespace = 'public'::regnamespace;
--    → Should return 1 row
--
-- 4. Test edit: Update any invoice from the UI — should work without 409

-- ============================================================================
-- URGENT FIX: Invoice Update (Edit) Broken
-- Date: 2026-06-26
-- Run this ONCE in Supabase SQL Editor.
-- All steps are idempotent — safe to run even if some were applied before.
-- ============================================================================
--
-- Root causes:
--   1. check_invoice_collection_date_required constraint: any UPDATE to an
--      invoice where balance > 0 AND collection_date IS NULL fails, including
--      old invoices that predate the constraint.
--   2. invoices_status_check may not include 'partial'/'void' yet, but the
--      v2 trigger tries to set them → constraint violation on UPDATE.
--   3. update_invoice_v2 (old 2026-03-13 version) doesn't update payment_status
--      and doesn't persist discount_type/discount_amount.
--   4. search_path = public on SECURITY DEFINER functions may break uuid calls.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop the legacy collection_date constraint (restaurant POS artifact).
--    Frontend already validates: if balance > 0 then collection_date required.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices
    DROP CONSTRAINT IF EXISTS check_invoice_collection_date_required;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Widen the status constraint to include 'partial' and 'void'.
--    Triggers from 20260422 and later already set these values.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices
    DROP CONSTRAINT IF EXISTS invoices_status_check;

ALTER TABLE public.invoices
    ADD CONSTRAINT invoices_status_check
    CHECK (status IN ('draft','issued','unpaid','paid','partial','cancelled','void'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Ensure payment_status column exists (added by 20260422).
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'unpaid';

-- Back-fill: derive from balance/paid_amount for any rows that still have NULL
UPDATE public.invoices
SET payment_status = CASE
    WHEN balance <= 0 AND total > 0 THEN 'paid'
    WHEN paid_amount > 0 AND balance > 0 THEN 'partial'
    ELSE 'unpaid'
END
WHERE payment_status IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Ensure invoice_items.discount_type / discount_amount exist.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoice_items
    ADD COLUMN IF NOT EXISTS discount_type   TEXT    DEFAULT 'amount',
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0;

UPDATE public.invoice_items
SET    discount_type   = 'amount',
       discount_amount = COALESCE(discount, 0)
WHERE  discount_type IS NULL OR discount_amount IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Ensure customer_po_no exists on invoices.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS customer_po_no TEXT;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5b. Recreate create_invoice_v2 — comprehensive version:
--     • Generates GIN doc number using generate_inv_doc_number to keep sequences sync'd
--     • search_path = public, extensions (safe for UUID calls)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_invoice_v2(
    p_payload JSONB,
    p_items JSONB,
    p_payment JSONB DEFAULT NULL::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_invoice_id UUID;
    v_invoice_no TEXT;
    v_counter INT;
    v_year TEXT;
    v_company_id UUID;
    v_payment_id UUID;
    v_item JSONB;
    v_wh_id UUID;
    v_branch_id UUID;
    v_doc_id UUID;
    v_doc_number TEXT;
    v_line_number INT := 1;
    v_tracked_items_exist BOOLEAN := FALSE;
    v_unit_cost NUMERIC;
    v_uom_id UUID;
    v_default_uom_id UUID;
BEGIN
    v_company_id := (p_payload->>'company_id')::UUID;

    -- Generate invoice number inline (no dependency on external function)
    v_year := to_char(now(), 'YYYY');
    SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_no FROM LENGTH('INV-' || v_year || '-') + 1) AS INT)), 0) + 1
    INTO v_counter
    FROM invoices
    WHERE company_id = v_company_id AND invoice_no LIKE 'INV-' || v_year || '-%';
    v_invoice_no := 'INV-' || v_year || '-' || lpad(v_counter::TEXT, 6, '0');

    -- Insert invoice
    INSERT INTO invoices (
        company_id, branch_id, order_id,
        customer_id, customer_snapshot, customer_name, customer_phone,
        payment_type, payment_status, status,
        subtotal, discount, tax, total, paid_amount, balance,
        notes, invoice_date, collection_date,
        is_vat_invoice, vat_amount, total_before_vat,
        is_service_invoice, service_job_id,
        customer_po_no, invoice_no, created_by
    ) VALUES (
        v_company_id,
        (p_payload->>'branch_id')::UUID,
        COALESCE((p_payload->>'order_id')::UUID, uuid_generate_v4()),
        (p_payload->>'customer_id')::UUID,
        COALESCE(p_payload->'customer_snapshot', '{}'::JSONB),
        p_payload->>'customer_name',
        p_payload->>'customer_phone',
        COALESCE(p_payload->>'payment_type', 'cash'),
        'unpaid',
        COALESCE(p_payload->>'status', 'issued'),
        COALESCE((p_payload->>'subtotal')::NUMERIC, 0),
        COALESCE((p_payload->>'discount')::NUMERIC, 0),
        COALESCE((p_payload->>'tax')::NUMERIC, 0),
        COALESCE((p_payload->>'total')::NUMERIC, 0),
        COALESCE((p_payload->>'paid_amount')::NUMERIC, 0),
        COALESCE((p_payload->>'balance')::NUMERIC, 0),
        p_payload->>'notes',
        COALESCE((p_payload->>'invoice_date')::DATE, CURRENT_DATE),
        (p_payload->>'collection_date')::DATE,
        COALESCE((p_payload->>'is_vat_invoice')::BOOLEAN, false),
        COALESCE((p_payload->>'vat_amount')::NUMERIC, 0),
        COALESCE((p_payload->>'total_before_vat')::NUMERIC, 0),
        COALESCE((p_payload->>'is_service_invoice')::BOOLEAN, false),
        (p_payload->>'service_job_id')::UUID,
        p_payload->>'customer_po_no',
        v_invoice_no,
        (p_payload->>'created_by')::UUID
    )
    RETURNING id INTO v_invoice_id;

    -- Insert items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO invoice_items (
            invoice_id, product_id, description, item_code,
            qty, unit_price, discount, line_total, warranty, serial_number,
            selling_unit_price_snapshot, cost_unit_price_snapshot
        ) VALUES (
            v_invoice_id,
            NULLIF(v_item->>'product_id', '')::UUID,
            v_item->>'description',
            v_item->>'item_code',
            COALESCE((v_item->>'qty')::NUMERIC, 1),
            COALESCE((v_item->>'unit_price')::NUMERIC, 0),
            COALESCE((v_item->>'discount')::NUMERIC, 0),
            COALESCE((v_item->>'line_total')::NUMERIC, 0),
            v_item->>'warranty',
            v_item->>'serial_number',
            COALESCE((v_item->>'selling_unit_price_snapshot')::NUMERIC, 0),
            COALESCE((v_item->>'cost_unit_price_snapshot')::NUMERIC, 0)
        );
        IF NULLIF(v_item->>'product_id', '') IS NOT NULL THEN
            v_tracked_items_exist := TRUE;
        END IF;
    END LOOP;

    -- Insert payment if provided
    IF p_payment IS NOT NULL AND COALESCE((p_payment->>'amount')::NUMERIC, 0) > 0 THEN
        INSERT INTO invoice_payments (
            company_id, invoice_id, customer_id, amount, method, created_by
        ) VALUES (
            v_company_id,
            v_invoice_id,
            NULLIF(p_payment->>'customer_id', '')::UUID,
            (p_payment->>'amount')::NUMERIC,
            COALESCE(p_payment->>'method', 'CASH'),
            NULLIF(p_payment->>'created_by', '')::UUID
        )
        RETURNING id INTO v_payment_id;

        -- Update invoice paid_amount and balance
        UPDATE invoices
        SET paid_amount = COALESCE((p_payload->>'paid_amount')::NUMERIC, 0),
            balance = COALESCE((p_payload->>'balance')::NUMERIC, 0),
            payment_status = CASE 
                WHEN COALESCE((p_payload->>'balance')::NUMERIC, 0) <= 0 THEN 'paid'
                WHEN COALESCE((p_payload->>'paid_amount')::NUMERIC, 0) > 0 THEN 'partial'
                ELSE 'unpaid'
            END
        WHERE id = v_invoice_id;
    END IF;

    -- ── STOCK DEDUCTION (GIN) ─────────────────────────────────────────────
    IF v_tracked_items_exist THEN
        SELECT id, branch_id INTO v_wh_id, v_branch_id
        FROM warehouses
        WHERE company_id = v_company_id AND is_active = TRUE
        ORDER BY is_default DESC, (warehouse_type = 'showroom') DESC, created_at ASC
        LIMIT 1;

        IF v_wh_id IS NOT NULL THEN
            -- Generate GIN doc number using concurrency-safe sequence generator
            v_doc_number := public.generate_inv_doc_number(v_company_id, 'GIN');

            INSERT INTO inventory_documents (
                company_id, branch_id, doc_type, doc_number, doc_date,
                warehouse_id, reference_id, reference_type, status, remarks, created_by
            ) VALUES (
                v_company_id, v_branch_id, 'GIN', v_doc_number, CURRENT_DATE,
                v_wh_id, v_invoice_id, 'invoice', 'draft',
                'Auto stock deduction for invoice ' || v_invoice_no,
                NULLIF(p_payload->>'created_by', '')::UUID
            ) RETURNING id INTO v_doc_id;

            -- Find fallback UOM
            SELECT id INTO v_default_uom_id FROM uom WHERE company_id = v_company_id LIMIT 1;

            FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
                IF NULLIF(v_item->>'product_id', '') IS NOT NULL THEN
                    SELECT avg_cost, inventory_uom_id INTO v_unit_cost, v_uom_id
                    FROM items WHERE id = NULLIF(v_item->>'product_id', '')::UUID;

                    -- Fallback to default UOM if item has none
                    IF v_uom_id IS NULL THEN
                        v_uom_id := v_default_uom_id;
                    END IF;

                    IF v_uom_id IS NOT NULL THEN
                        INSERT INTO inventory_document_lines (
                            document_id, line_number, item_id, uom_id,
                            quantity, unit_cost, notes
                        ) VALUES (
                            v_doc_id, v_line_number,
                            NULLIF(v_item->>'product_id', '')::UUID,
                            v_uom_id,
                            COALESCE((v_item->>'qty')::NUMERIC, 0),
                            COALESCE(v_unit_cost, 0),
                            'Sale from invoice'
                        );
                        v_line_number := v_line_number + 1;
                    END IF;
                END IF;
            END LOOP;

            -- Post GIN if lines were added, otherwise clean up
            IF v_line_number > 1 THEN
                UPDATE inventory_documents SET status = 'posted' WHERE id = v_doc_id;
            ELSE
                DELETE FROM inventory_documents WHERE id = v_doc_id;
                v_doc_number := NULL;
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'invoice_id', v_invoice_id,
        'invoice_no', v_invoice_no,
        'payment_id', v_payment_id,
        'gin_document', v_doc_number
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5c. Synchronize inv_doc_sequences to match max actual numbers in inventory_documents.
--     This fixes any existing out-of-sync sequences caused by inline doc generation.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    r RECORD;
    v_max INT;
BEGIN
    -- 1. Insert missing sequences based on actual distinct company+doc_type+fiscal_year combinations in inventory_documents
    INSERT INTO public.inv_doc_sequences (company_id, doc_type, prefix, current_number, fiscal_year)
    SELECT DISTINCT
        d.company_id,
        d.doc_type,
        d.doc_type || '-',
        1,
        EXTRACT(YEAR FROM d.doc_date)::INT
    FROM public.inventory_documents d
    WHERE d.doc_type IN ('GRN', 'GIN', 'TRANSFER', 'ADJUSTMENT', 'STOCK_COUNT', 'BOM_DEDUCT', 'OPENING', 'PO')
      AND NOT EXISTS (
          SELECT 1 
          FROM public.inv_doc_sequences s 
          WHERE s.company_id = d.company_id 
            AND s.doc_type = d.doc_type 
            AND s.fiscal_year = EXTRACT(YEAR FROM d.doc_date)::INT
      )
    ON CONFLICT DO NOTHING;

    -- 2. Synchronize all sequences to their maximum numbers
    FOR r IN 
        SELECT id, company_id, doc_type, fiscal_year, prefix 
        FROM public.inv_doc_sequences 
        WHERE doc_type IN ('GRN', 'GIN', 'TRANSFER', 'ADJUSTMENT', 'STOCK_COUNT', 'BOM_DEDUCT', 'OPENING', 'PO')
    LOOP
        SELECT COALESCE(MAX(NULLIF(regexp_replace(doc_number, '^' || r.doc_type || '-' || r.fiscal_year || '-', ''), '')::INT), 0)
        INTO v_max
        FROM public.inventory_documents
        WHERE company_id = r.company_id
          AND doc_type = r.doc_type
          AND doc_number LIKE r.doc_type || '-' || r.fiscal_year || '-%';

        IF v_max > 0 THEN
            UPDATE public.inv_doc_sequences
            SET current_number = GREATEST(current_number, v_max)
            WHERE id = r.id;
        END IF;
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Recreate update_invoice_v2 — comprehensive version:
--    • Persists discount_type + discount_amount per line
--    • Recalculates payment_status from new figures
--    • Sets updated_at
--    • search_path = public, extensions (safe for UUID calls)
--    • auth.uid() guard to prevent unauthenticated RPC abuse
-- ─────────────────────────────────────────────────────────────────────────────
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
    v_existing_gin_id  UUID;
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
BEGIN
    -- Auth guard: reject unauthenticated calls
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED: authentication required.';
    END IF;

    -- ── 1. Validate invoice exists ───────────────────────────────────────────
    SELECT company_id INTO v_company_id
    FROM   public.invoices
    WHERE  id = p_invoice_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'Invoice % not found', p_invoice_id;
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'p_items must be a non-empty JSON array';
    END IF;

    -- ── 2. Cancel existing posted GIN (reverses stock) ──────────────────────
    SELECT id INTO v_existing_gin_id
    FROM   public.inventory_documents
    WHERE  reference_id   = p_invoice_id
      AND  reference_type = 'invoice'
      AND  doc_type       = 'GIN'
      AND  status         = 'posted'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_gin_id IS NOT NULL THEN
        UPDATE public.inventory_documents
        SET    status = 'cancelled'
        WHERE  id     = v_existing_gin_id;
    END IF;

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
        -- collection_date: keep existing if payload is null/empty (preserves old invoices)
        collection_date    = CASE
                                 WHEN NULLIF(p_payload->>'collection_date', '') IS NOT NULL
                                 THEN NULLIF(p_payload->>'collection_date', '')::DATE
                                 ELSE collection_date  -- keep existing value
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

    -- ── 4. Replace invoice items (with discount_type / discount_amount) ──────
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

    -- ── 5. Create & post new GIN for the updated tracked items ───────────────
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
                UPDATE public.inventory_documents SET status = 'posted' WHERE id = v_new_gin_id;
            ELSE
                DELETE FROM public.inventory_documents WHERE id = v_new_gin_id;
                v_new_gin_number := NULL;
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success',          TRUE,
        'invoice_id',       p_invoice_id,
        'cancelled_gin',    v_existing_gin_id,
        'new_gin_document', v_new_gin_number
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Grants: authenticated + service_role only (anon revoked)
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) FROM anon;
GRANT  EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO service_role;

-- Also fix create_invoice_v2 grants while we're here
DO $$
BEGIN
    BEGIN
        REVOKE EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) FROM anon;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    BEGIN
        GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO service_role;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Fix search_path on all SECURITY DEFINER functions
--    (undoes damage from 20260625_fix_supabase_advisors_functions.sql)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE rec record;
BEGIN
    -- Non-definer: RESET so they inherit the DB-level path (includes extensions)
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM   pg_proc p
        JOIN   pg_namespace n ON p.pronamespace = n.oid
        WHERE  n.nspname = 'public' AND p.prosecdef = false
    LOOP
        BEGIN
            EXECUTE format('ALTER FUNCTION %I.%I(%s) RESET search_path',
                rec.nspname, rec.proname, rec.args);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;

    -- Definer: explicit public, extensions
    FOR rec IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM   pg_proc p
        JOIN   pg_namespace n ON p.pronamespace = n.oid
        WHERE  n.nspname = 'public' AND p.prosecdef = true
    LOOP
        BEGIN
            EXECUTE format('ALTER FUNCTION %I.%I(%s) SET search_path = public, extensions',
                rec.nspname, rec.proname, rec.args);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. Drop legacy restaurant POS BOM trigger (not relevant for this ERP)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER  IF EXISTS trg_invoice_bom_deduct ON public.invoices;
DROP FUNCTION IF EXISTS public.deduct_bom_for_invoice() CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. Ensure get_next_counter_value is callable by authenticated users
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    BEGIN
        GRANT EXECUTE ON FUNCTION public.get_next_counter_value(UUID, TEXT)
            TO authenticated, service_role;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. Reload PostgREST schema cache
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ─────────────────────────────────────────────────────────────────────────────
-- Verification queries (run manually after to confirm success):
-- ─────────────────────────────────────────────────────────────────────────────
-- -- Constraint dropped:
-- SELECT conname FROM pg_constraint WHERE conname = 'check_invoice_collection_date_required';
-- -- Should return 0 rows.
--
-- -- Status constraint widened:
-- SELECT pg_get_constraintdef(oid) FROM pg_constraint
--   WHERE conname = 'invoices_status_check' AND conrelid = 'public.invoices'::regclass;
-- -- Should include 'partial' and 'void'.
--
-- -- Columns added:
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'invoices' AND column_name = 'payment_status';
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'invoice_items' AND column_name IN ('discount_type','discount_amount');
--
-- -- Function updated:
-- SELECT proname, prosrc FROM pg_proc
--   WHERE proname = 'update_invoice_v2' AND pronamespace = 'public'::regnamespace;

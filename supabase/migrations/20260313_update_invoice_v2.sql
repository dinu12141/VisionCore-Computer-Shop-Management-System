-- ============================================================================
-- FIX: update_invoice_v2 RPC — safe invoice editing with inventory reversal
-- Date: 2026-03-13
-- Bugs fixed: BUG-2 (updateInvoice leaves inventory in incorrect state)
--
-- Strategy:
--   1. Cancel the existing posted GIN tied to this invoice
--      → triggers post_inventory_document() BEFORE UPDATE trigger
--      → which appends reversal entries to inventory_ledger
--      → and adds stock back to stock_on_hand
--   2. Update invoice header
--   3. Replace invoice_items (delete old, insert new)
--   4. Create & post a new GIN for the updated line items
--
-- All steps run inside a single transaction (plpgsql implicit txn).
-- If any step fails the entire edit is rolled back.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_invoice_v2(
    p_invoice_id UUID,
    p_items      JSONB,
    p_payload    JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id       UUID;
    v_existing_gin_id  UUID;
    v_new_gin_id       UUID;
    v_new_gin_number   TEXT;
    v_item             RECORD;
    v_unit_cost        NUMERIC;
    v_uom_id           UUID;
    v_line_number      INT  := 1;
    v_has_tracked      BOOLEAN := FALSE;
    v_wh_id            UUID;
    v_branch_id        UUID;
BEGIN
    -- ── 1. Validate invoice exists ───────────────────────────────────────────
    SELECT company_id INTO v_company_id
    FROM public.invoices
    WHERE id = p_invoice_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'Invoice % not found', p_invoice_id;
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'p_items must be a non-empty JSON array';
    END IF;

    -- ── 2. Cancel existing posted GIN for this invoice ──────────────────────
    -- Cancellation fires the BEFORE UPDATE trigger on inventory_documents
    -- which reverses all ledger entries and adds stock back.
    SELECT id INTO v_existing_gin_id
    FROM public.inventory_documents
    WHERE reference_id   = p_invoice_id
      AND reference_type = 'invoice'
      AND doc_type       = 'GIN'
      AND status         = 'posted'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_gin_id IS NOT NULL THEN
        UPDATE public.inventory_documents
        SET    status = 'cancelled'
        WHERE  id = v_existing_gin_id;
    END IF;

    -- ── 3. Update invoice header ─────────────────────────────────────────────
    UPDATE public.invoices
    SET
        customer_id        = NULLIF(p_payload->>'customer_id',        '')::UUID,
        status             = COALESCE(NULLIF(p_payload->>'status',             ''), 'issued'),
        payment_type       = NULLIF(p_payload->>'payment_type',       ''),
        subtotal           = COALESCE(NULLIF(p_payload->>'subtotal',           '')::NUMERIC, 0),
        discount           = COALESCE(NULLIF(p_payload->>'discount',           '')::NUMERIC, 0),
        tax                = COALESCE(NULLIF(p_payload->>'tax',                '')::NUMERIC, 0),
        total              = COALESCE(NULLIF(p_payload->>'total',              '')::NUMERIC, 0),
        paid_amount        = COALESCE(NULLIF(p_payload->>'paid_amount',        '')::NUMERIC, 0),
        balance            = COALESCE(NULLIF(p_payload->>'balance',            '')::NUMERIC, 0),
        customer_snapshot  = COALESCE(p_payload->'customer_snapshot',  '{}'::jsonb),
        notes              = NULLIF(p_payload->>'notes',              ''),
        collection_date    = NULLIF(p_payload->>'collection_date',    '')::DATE,
        invoice_date       = COALESCE(NULLIF(p_payload->>'invoice_date', '')::DATE, CURRENT_DATE),
        is_vat_invoice     = COALESCE(NULLIF(p_payload->>'is_vat_invoice',     '')::BOOLEAN, FALSE),
        vat_amount         = COALESCE(NULLIF(p_payload->>'vat_amount',         '')::NUMERIC, 0),
        total_before_vat   = COALESCE(NULLIF(p_payload->>'total_before_vat',   '')::NUMERIC, 0),
        is_service_invoice = COALESCE(NULLIF(p_payload->>'is_service_invoice', '')::BOOLEAN, FALSE),
        service_job_id     = NULLIF(p_payload->>'service_job_id',     '')::UUID,
        customer_po_no     = NULLIF(p_payload->>'customer_po_no',     '')
    WHERE id = p_invoice_id;

    -- ── 4. Replace invoice items ─────────────────────────────────────────────
    DELETE FROM public.invoice_items
    WHERE invoice_id = p_invoice_id;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
        INSERT INTO public.invoice_items (
            invoice_id, product_id, description, item_code,
            qty, unit_price, discount, line_total,
            warranty, serial_number,
            selling_unit_price_snapshot, cost_unit_price_snapshot
        ) VALUES (
            p_invoice_id,
            NULLIF(v_item.value->>'product_id',                '')::UUID,
            v_item.value->>'description',
            v_item.value->>'item_code',
            COALESCE(NULLIF(v_item.value->>'qty',              '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'unit_price',       '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'discount',         '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'line_total',       '')::NUMERIC, 0),
            v_item.value->>'warranty',
            v_item.value->>'serial_number',
            COALESCE(NULLIF(v_item.value->>'selling_unit_price_snapshot', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'cost_unit_price_snapshot',    '')::NUMERIC, 0)
        );

        IF NULLIF(v_item.value->>'product_id', '') IS NOT NULL THEN
            v_has_tracked := TRUE;
        END IF;
    END LOOP;

    -- ── 5. Create & post new GIN for updated items ───────────────────────────
    IF v_has_tracked THEN
        -- Pick the default/first active warehouse (no 'showroom' filter —
        -- that type is now allowed by the constraint fix in 20260313_fix_inventory_po_constraint)
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
                            v_new_gin_id,
                            v_line_number,
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
                -- Post it — triggers stock deduction via BEFORE UPDATE trigger
                UPDATE public.inventory_documents
                SET    status = 'posted'
                WHERE  id = v_new_gin_id;
            ELSE
                -- No tracked lines → no GIN needed
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

GRANT EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO anon;
GRANT EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO service_role;

NOTIFY pgrst, 'reload schema';

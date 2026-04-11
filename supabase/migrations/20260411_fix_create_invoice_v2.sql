-- =====================================================
-- FIX: create_invoice_v2 with stock deduction (GIN)
-- Run this in the Supabase SQL Editor for project: ovdheejmgchtohnjozpn
-- =====================================================

-- Step 1: Drop the old/broken function
DROP FUNCTION IF EXISTS public.create_invoice_v2(jsonb, jsonb, jsonb);

-- Step 2: Recreate with stock deduction logic
CREATE OR REPLACE FUNCTION public.create_invoice_v2(
    p_payload JSONB,
    p_items JSONB,
    p_payment JSONB DEFAULT NULL::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
            -- Generate GIN doc number inline
            SELECT 'GIN-' || to_char(now(), 'YYYY') || '-' || lpad(
                (COALESCE(MAX(CAST(SUBSTRING(doc_number FROM LENGTH('GIN-' || to_char(now(), 'YYYY') || '-') + 1) AS INT)), 0) + 1)::TEXT,
                5, '0'
            ) INTO v_doc_number
            FROM inventory_documents
            WHERE company_id = v_company_id AND doc_number LIKE 'GIN-' || to_char(now(), 'YYYY') || '-%';

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

-- Step 3: Grant permissions so PostgREST API can expose it
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO anon;
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO service_role;

-- Step 4: Force PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

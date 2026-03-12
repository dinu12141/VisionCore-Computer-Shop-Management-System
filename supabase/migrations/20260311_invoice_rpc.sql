-- =========================================================
-- FIX: create_invoice_v2 RPC for frontend call
-- Frontend expects: create_invoice_v2(p_items, p_payload, p_payment)
-- =========================================================

-- 1) Drop old trigger/function if they exist
DROP TRIGGER IF EXISTS trg_invoice_item_deduct_stock ON public.invoice_items;
DROP FUNCTION IF EXISTS public.deduct_stock_for_invoice_item() CASCADE;

-- 2) Drop old create_invoice_v2 versions if they exist
DROP FUNCTION IF EXISTS public.create_invoice_v2(jsonb, jsonb, jsonb);
DROP FUNCTION IF EXISTS public.create_invoice_v2(p_payload jsonb, p_items jsonb, p_payment jsonb);
DROP FUNCTION IF EXISTS public.create_invoice_v2(p_items jsonb, p_payload jsonb, p_payment jsonb);

-- 3) Create the RPC with the EXACT parameter names/order expected by frontend
CREATE OR REPLACE FUNCTION public.create_invoice_v2(
    p_items JSONB,
    p_payload JSONB,
    p_payment JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_invoice_id UUID;
    v_invoice_no TEXT;
    v_invoice_status TEXT;
    v_payment_id UUID;
    v_wh_id UUID;
    v_branch_id UUID;
    v_doc_id UUID;
    v_doc_number TEXT;
    v_item RECORD;
    v_unit_cost NUMERIC;
    v_uom_id UUID;
    v_line_number INT := 1;
    v_tracked_items_exist BOOLEAN := FALSE;
BEGIN
    -- 1. Extract required fields
    v_company_id := NULLIF(p_payload->>'company_id', '')::UUID;
    v_invoice_status := COALESCE(NULLIF(p_payload->>'status', ''), 'issued');

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'company_id is required';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'p_items must be a non-empty JSON array';
    END IF;

    -- 2. Insert Invoice Header
    INSERT INTO public.invoices (
        company_id,
        customer_id,
        status,
        payment_type,
        subtotal,
        discount,
        tax,
        total,
        paid_amount,
        balance,
        customer_snapshot,
        notes,
        created_by,
        collection_date,
        invoice_date,
        is_vat_invoice,
        vat_amount,
        total_before_vat,
        is_service_invoice,
        service_job_id
    ) VALUES (
        v_company_id,
        NULLIF(p_payload->>'customer_id', '')::UUID,
        v_invoice_status,
        NULLIF(p_payload->>'payment_type', ''),
        COALESCE(NULLIF(p_payload->>'subtotal', '')::NUMERIC, 0),
        COALESCE(NULLIF(p_payload->>'discount', '')::NUMERIC, 0),
        COALESCE(NULLIF(p_payload->>'tax', '')::NUMERIC, 0),
        COALESCE(NULLIF(p_payload->>'total', '')::NUMERIC, 0),
        COALESCE(NULLIF(p_payload->>'paid_amount', '')::NUMERIC, 0),
        COALESCE(NULLIF(p_payload->>'balance', '')::NUMERIC, 0),
        COALESCE(p_payload->'customer_snapshot', '{}'::jsonb),
        NULLIF(p_payload->>'notes', ''),
        NULLIF(p_payload->>'created_by', '')::UUID,
        NULLIF(p_payload->>'collection_date', '')::DATE,
        COALESCE(NULLIF(p_payload->>'invoice_date', '')::DATE, CURRENT_DATE),
        COALESCE(NULLIF(p_payload->>'is_vat_invoice', '')::BOOLEAN, FALSE),
        COALESCE(NULLIF(p_payload->>'vat_amount', '')::NUMERIC, 0),
        COALESCE(NULLIF(p_payload->>'total_before_vat', '')::NUMERIC, 0),
        COALESCE(NULLIF(p_payload->>'is_service_invoice', '')::BOOLEAN, FALSE),
        NULLIF(p_payload->>'service_job_id', '')::UUID
    )
    RETURNING id, invoice_no
    INTO v_invoice_id, v_invoice_no;

    -- 3. Insert Invoice Items
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.invoice_items (
            invoice_id,
            product_id,
            description,
            item_code,
            qty,
            unit_price,
            discount,
            line_total,
            warranty,
            serial_number,
            selling_unit_price_snapshot,
            cost_unit_price_snapshot
        ) VALUES (
            v_invoice_id,
            NULLIF(v_item.value->>'product_id', '')::UUID,
            v_item.value->>'description',
            v_item.value->>'item_code',
            COALESCE(NULLIF(v_item.value->>'qty', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'unit_price', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'discount', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'line_total', '')::NUMERIC, 0),
            v_item.value->>'warranty',
            v_item.value->>'serial_number',
            COALESCE(NULLIF(v_item.value->>'selling_unit_price_snapshot', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item.value->>'cost_unit_price_snapshot', '')::NUMERIC, 0)
        );

        IF NULLIF(v_item.value->>'product_id', '') IS NOT NULL THEN
            v_tracked_items_exist := TRUE;
        END IF;
    END LOOP;

    -- 4. Insert Payment if provided
    IF p_payment IS NOT NULL
       AND COALESCE(NULLIF(p_payment->>'amount', '')::NUMERIC, 0) > 0
    THEN
        INSERT INTO public.invoice_payments (
            company_id,
            invoice_id,
            customer_id,
            amount,
            method,
            created_by
        ) VALUES (
            v_company_id,
            v_invoice_id,
            NULLIF(p_payment->>'customer_id', '')::UUID,
            COALESCE(NULLIF(p_payment->>'amount', '')::NUMERIC, 0),
            p_payment->>'method',
            NULLIF(p_payment->>'created_by', '')::UUID
        )
        RETURNING id INTO v_payment_id;
    END IF;

    -- 5. Inventory Deduction (Atomic Batch)
    IF v_tracked_items_exist THEN
        SELECT id, branch_id
        INTO v_wh_id, v_branch_id
        FROM public.warehouses
        WHERE company_id = v_company_id
          AND is_active = TRUE
        ORDER BY is_default DESC, (warehouse_type = 'showroom') DESC, created_at ASC
        LIMIT 1;

        IF v_wh_id IS NOT NULL THEN
            v_doc_number := public.generate_inv_doc_number(v_company_id, 'GIN');

            INSERT INTO public.inventory_documents (
                company_id,
                branch_id,
                doc_type,
                doc_number,
                doc_date,
                warehouse_id,
                reference_id,
                reference_type,
                status,
                remarks,
                created_by
            ) VALUES (
                v_company_id,
                v_branch_id,
                'GIN',
                v_doc_number,
                CURRENT_DATE,
                v_wh_id,
                v_invoice_id,
                'invoice',
                'draft',
                'Auto stock deduction for invoice ' || COALESCE(v_invoice_no, ''),
                NULLIF(p_payload->>'created_by', '')::UUID
            )
            RETURNING id INTO v_doc_id;

            v_line_number := 1;

            FOR v_item IN
                SELECT value
                FROM jsonb_array_elements(p_items)
            LOOP
                IF NULLIF(v_item.value->>'product_id', '') IS NOT NULL THEN
                    SELECT avg_cost, inventory_uom_id
                    INTO v_unit_cost, v_uom_id
                    FROM public.items
                    WHERE id = (v_item.value->>'product_id')::UUID;

                    IF v_uom_id IS NOT NULL THEN
                        INSERT INTO public.inventory_document_lines (
                            document_id,
                            line_number,
                            item_id,
                            uom_id,
                            quantity,
                            unit_cost,
                            notes
                        ) VALUES (
                            v_doc_id,
                            v_line_number,
                            (v_item.value->>'product_id')::UUID,
                            v_uom_id,
                            COALESCE(NULLIF(v_item.value->>'qty', '')::NUMERIC, 0),
                            COALESCE(v_unit_cost, 0),
                            'Sale from invoice'
                        );

                        v_line_number := v_line_number + 1;
                    END IF;
                END IF;
            END LOOP;

            IF v_line_number > 1 THEN
                UPDATE public.inventory_documents
                SET status = 'posted'
                WHERE id = v_doc_id;
            ELSE
                DELETE FROM public.inventory_documents
                WHERE id = v_doc_id;

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

-- 4) Grant execute for app roles
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO anon;
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO service_role;
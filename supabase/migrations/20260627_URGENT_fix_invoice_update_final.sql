-- ============================================================================
-- URGENT FINAL FIX: Drop legacy invoice stock deduction trigger & sync sequences safely
-- Date: 2026-06-27
-- Run this ONCE in Supabase SQL Editor.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop the legacy trigger on invoice_items that causes double stock deduction and 409 conflicts
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_invoice_item_deduct_stock ON public.invoice_items CASCADE;
DROP FUNCTION IF EXISTS public.deduct_stock_for_invoice_item() CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Drop the legacy restaurant POS BOM trigger
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_invoice_bom_deduct ON public.invoices CASCADE;
DROP FUNCTION IF EXISTS public.deduct_bom_for_invoice() CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Ensure invoices check constraints allow widened status values
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE public.invoices ADD CONSTRAINT invoices_status_check
CHECK (status IN ('draft','issued','unpaid','paid','partial','cancelled','void'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Ensure payment_status check constraint allows lowercase values
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS invoices_payment_status_check;
ALTER TABLE public.invoices ADD CONSTRAINT invoices_payment_status_check
CHECK (LOWER(payment_status) IN ('unpaid', 'partial', 'paid'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Synchronize inv_doc_sequences using a bulletproof numeric extraction
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

    -- 2. Synchronize all sequences to their maximum numbers using a safe suffix extraction
    FOR r IN 
        SELECT id, company_id, doc_type, fiscal_year, prefix 
        FROM public.inv_doc_sequences 
        WHERE doc_type IN ('GRN', 'GIN', 'TRANSFER', 'ADJUSTMENT', 'STOCK_COUNT', 'BOM_DEDUCT', 'OPENING', 'PO')
    LOOP
        SELECT COALESCE(MAX(
            CASE 
                -- Extract digits after the last hyphen (concurrency-safe format: TYPE-YYYY-NNNNN)
                WHEN doc_number ~ '-[0-9]+$' THEN 
                    substring(doc_number from '-([0-9]+)$')::INT
                ELSE 0 
            END
        ), 0)
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
-- 6. Reload PostgREST schema cache
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

COMMIT;

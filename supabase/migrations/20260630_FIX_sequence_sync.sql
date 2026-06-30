-- ============================================================================
-- FIX: Sync Inventory Document Sequences
-- Date: 2026-06-30
-- Run this ONCE in Supabase SQL Editor to resolve the duplicate key constraint
-- error: "inventory_documents_company_id_doc_number_key"
-- ============================================================================

BEGIN;

DO $$
DECLARE
    r RECORD;
    v_max INT;
BEGIN
    -- 1. Insert missing sequences based on actual existing documents
    INSERT INTO public.inv_doc_sequences (company_id, doc_type, prefix, current_number, fiscal_year)
    SELECT DISTINCT
        d.company_id,
        d.doc_type,
        d.doc_type || '-',
        1,
        EXTRACT(YEAR FROM d.doc_date)::INT
    FROM public.inventory_documents d
    WHERE d.doc_type IN ('GRN', 'GIN', 'TRANSFER', 'ADJUSTMENT', 'STOCK_COUNT', 'BOM_DEDUCT', 'OPENING', 'PO', 'GIN_ISSUE')
      AND NOT EXISTS (
          SELECT 1 
          FROM public.inv_doc_sequences s 
          WHERE s.company_id = d.company_id 
            AND s.doc_type = d.doc_type 
            AND s.fiscal_year = EXTRACT(YEAR FROM d.doc_date)::INT
      )
    ON CONFLICT DO NOTHING;

    -- 2. Synchronize all sequences to their maximum actual values in inventory_documents
    FOR r IN 
        SELECT id, company_id, doc_type, fiscal_year, prefix 
        FROM public.inv_doc_sequences 
    LOOP
        SELECT COALESCE(MAX(
            CASE 
                -- Extract digits after the last hyphen (e.g., GIN-2026-00005 -> 5)
                WHEN doc_number ~ '-[0-9]+$' THEN 
                    substring(doc_number from '-([0-9]+)$')::INT
                ELSE 0 
            END
        ), 0)
        INTO v_max
        FROM public.inventory_documents
        WHERE company_id = r.company_id
          AND doc_type = r.doc_type
          -- Match the year part as well
          AND doc_number LIKE '%-' || r.fiscal_year || '-%';

        IF v_max > 0 THEN
            UPDATE public.inv_doc_sequences
            SET current_number = GREATEST(current_number, v_max)
            WHERE id = r.id;
        END IF;
    END LOOP;
END $$;

COMMIT;

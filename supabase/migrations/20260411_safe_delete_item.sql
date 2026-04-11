-- =====================================================
-- MIGRATION: Safe item deletion with cascading cleanup
-- Date: 2026-04-11
-- Run in Supabase SQL Editor for project: ovdheejmgchtohnjozpn
-- =====================================================

CREATE OR REPLACE FUNCTION public.delete_item_safe(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_company_id UUID;
    v_item_name TEXT;
    v_invoice_count INT;
    v_posted_doc_count INT;
BEGIN
    -- Get calling user's company
    v_company_id := get_my_company_id();
    IF v_company_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'No company context');
    END IF;

    -- Verify item belongs to same company
    SELECT name INTO v_item_name
    FROM items
    WHERE id = p_item_id AND company_id = v_company_id;

    IF v_item_name IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Item not found or access denied');
    END IF;

    -- Check if item is used in any invoices
    SELECT COUNT(*) INTO v_invoice_count
    FROM invoice_items
    WHERE product_id = p_item_id;

    IF v_invoice_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Cannot delete: item is referenced in ' || v_invoice_count || ' invoice(s). Deactivate it instead.',
            'reason', 'invoice_reference'
        );
    END IF;

    -- Check if item is in posted inventory documents (not draft)
    SELECT COUNT(*) INTO v_posted_doc_count
    FROM inventory_document_lines idl
    JOIN inventory_documents id ON id.id = idl.document_id
    WHERE idl.item_id = p_item_id AND id.status = 'posted';

    IF v_posted_doc_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Cannot delete: item has ' || v_posted_doc_count || ' posted inventory document(s). Deactivate it instead.',
            'reason', 'posted_document_reference'
        );
    END IF;

    -- Safe to delete — clean up child records first

    -- 1. Delete from inventory_document_lines (draft docs only at this point)
    DELETE FROM inventory_document_lines
    WHERE item_id = p_item_id
      AND document_id IN (
          SELECT id FROM inventory_documents
          WHERE company_id = v_company_id AND status = 'draft'
      );

    -- 2. Delete empty draft documents that now have no lines
    DELETE FROM inventory_documents
    WHERE company_id = v_company_id
      AND status = 'draft'
      AND id NOT IN (SELECT DISTINCT document_id FROM inventory_document_lines);

    -- 3. Delete from stock_on_hand
    DELETE FROM stock_on_hand WHERE item_id = p_item_id;

    -- 4. Delete from inventory_ledger
    DELETE FROM inventory_ledger WHERE item_id = p_item_id AND company_id = v_company_id;

    -- 5. Delete from item_warehouse_settings
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='item_warehouse_settings') THEN
        DELETE FROM item_warehouse_settings WHERE item_id = p_item_id;
    END IF;

    -- 6. Delete from service_parts_used (if exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='service_parts_used') THEN
        EXECUTE 'DELETE FROM service_parts_used WHERE item_id = $1' USING p_item_id;
    END IF;

    -- 7. Finally delete the item
    DELETE FROM items WHERE id = p_item_id AND company_id = v_company_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Item "' || v_item_name || '" deleted successfully'
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.delete_item_safe(UUID) TO authenticated;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';

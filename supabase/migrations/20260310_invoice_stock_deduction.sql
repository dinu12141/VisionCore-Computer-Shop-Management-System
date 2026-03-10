CREATE OR REPLACE FUNCTION deduct_stock_for_invoice_item()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice RECORD;
    v_wh_id UUID;
    v_branch_id UUID;
    v_doc_id UUID;
    v_doc_number TEXT;
    v_unit_cost NUMERIC;
    v_uom_id UUID;
BEGIN
    -- Only act if product_id is given (i.e. it's a tracked inventory item)
    IF NEW.product_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Get invoice
    SELECT * INTO v_invoice FROM invoices WHERE id = NEW.invoice_id;
    IF v_invoice.id IS NULL THEN RETURN NEW; END IF;

    -- Get warehouse for the company
    SELECT id, branch_id INTO v_wh_id, v_branch_id
    FROM warehouses
    WHERE company_id = v_invoice.company_id AND is_active = true
    ORDER BY is_default DESC, (warehouse_type = 'showroom') DESC, created_at ASC
    LIMIT 1;

    -- If no warehouse found, skip silently
    IF v_wh_id IS NULL THEN RETURN NEW; END IF;

    -- Generate document number
    v_doc_number := generate_inv_doc_number(v_invoice.company_id, 'GIN');

    -- Create draft GIN document
    INSERT INTO inventory_documents (
        company_id, branch_id, doc_type, doc_number, doc_date,
        warehouse_id, reference_id, reference_type, status,
        remarks, created_by
    ) VALUES (
        v_invoice.company_id, v_branch_id, 'GIN',
        v_doc_number, CURRENT_DATE,
        v_wh_id, v_invoice.id, 'invoice', 'draft',
        'Auto stock deduction for invoice ' || v_invoice.invoice_no,
        v_invoice.created_by
    ) RETURNING id INTO v_doc_id;

    -- Insert line
    SELECT avg_cost, inventory_uom_id INTO v_unit_cost, v_uom_id FROM items WHERE id = NEW.product_id;

    IF v_uom_id IS NULL THEN
        RETURN NEW; -- Item has no UOM, invalid, skip
    END IF;

    INSERT INTO inventory_document_lines (
        document_id, line_number, item_id, uom_id,
        quantity, unit_cost, notes
    ) VALUES (
        v_doc_id, 1, NEW.product_id, v_uom_id,
        NEW.qty, COALESCE(v_unit_cost, 0),
        'Sale from invoice'
    );

    -- Post document to trigger ledger entry and stock reduction
    UPDATE inventory_documents
    SET status = 'posted'
    WHERE id = v_doc_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop old restaurant BOM trigger since it relies on missing tables or logic
DROP TRIGGER IF EXISTS trg_invoice_bom_deduct ON invoices;
DROP FUNCTION IF EXISTS deduct_bom_for_invoice CASCADE;

-- Create new trigger for direct stock deduction
DROP TRIGGER IF EXISTS trg_invoice_item_deduct_stock ON invoice_items;
CREATE TRIGGER trg_invoice_item_deduct_stock
AFTER INSERT ON invoice_items
FOR EACH ROW
EXECUTE FUNCTION deduct_stock_for_invoice_item();

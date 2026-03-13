-- =====================================================
-- INVENTORY POSTING ENGINE (FINAL PRODUCTION VERSION)
-- =====================================================
-- Run AFTER inventory_module.sql
-- Contains: all functions, triggers, views
-- =====================================================

-- =====================================================
-- 1. GENERATE DOCUMENT NUMBER
-- =====================================================

CREATE OR REPLACE FUNCTION generate_inv_doc_number(
    p_company_id UUID,
    p_doc_type TEXT
)
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT;
    v_next INT;
    v_year INT := EXTRACT(YEAR FROM now());
BEGIN
    UPDATE inv_doc_sequences
    SET current_number = current_number + 1
    WHERE company_id = p_company_id
      AND doc_type = p_doc_type
      AND fiscal_year = v_year
    RETURNING prefix, current_number INTO v_prefix, v_next;

    IF v_prefix IS NULL THEN
        INSERT INTO inv_doc_sequences (company_id, doc_type, prefix, current_number, fiscal_year)
        VALUES (p_company_id, p_doc_type, p_doc_type || '-', 1, v_year)
        RETURNING prefix, current_number INTO v_prefix, v_next;
    END IF;

    RETURN v_prefix || v_year || '-' || LPAD(v_next::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 1.5. GENERATE ITEM CODE (Sequentially, no fiscal year)
-- =====================================================

CREATE OR REPLACE FUNCTION generate_item_code(p_company_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'ITM-';
    v_next INT;
BEGIN
    UPDATE inv_doc_sequences
    SET current_number = current_number + 1
    WHERE company_id = p_company_id
      AND doc_type = 'ITEM'
      AND fiscal_year = 0
    RETURNING current_number INTO v_next;

    IF v_next IS NULL THEN
        INSERT INTO inv_doc_sequences (company_id, doc_type, prefix, current_number, fiscal_year)
        VALUES (p_company_id, 'ITEM', v_prefix, 1, 0)
        RETURNING current_number INTO v_next;
    END IF;

    RETURN v_prefix || LPAD(v_next::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 1.6. GENERATE SUPPLIER CODE (Sequentially)
-- =====================================================

CREATE OR REPLACE FUNCTION generate_supplier_code(p_company_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'SUP-';
    v_next INT;
BEGIN
    UPDATE inv_doc_sequences
    SET current_number = current_number + 1
    WHERE company_id = p_company_id
      AND doc_type = 'SUPPLIER'
      AND fiscal_year = 0
    RETURNING current_number INTO v_next;

    IF v_next IS NULL THEN
        INSERT INTO inv_doc_sequences (company_id, doc_type, prefix, current_number, fiscal_year)
        VALUES (p_company_id, 'SUPPLIER', v_prefix, 1, 0)
        RETURNING current_number INTO v_next;
    END IF;

    RETURN v_prefix || LPAD(v_next::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. UPSERT STOCK ON HAND (atomic per item+warehouse)
-- =====================================================

CREATE OR REPLACE FUNCTION update_stock_on_hand(
    p_company_id UUID,
    p_warehouse_id UUID,
    p_item_id UUID,
    p_signed_qty NUMERIC,
    p_signed_cost NUMERIC
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO stock_on_hand (
        company_id, warehouse_id, item_id,
        qty_on_hand, total_value, last_movement_at
    )
    VALUES (
        p_company_id, p_warehouse_id, p_item_id,
        p_signed_qty, p_signed_cost, now()
    )
    ON CONFLICT (warehouse_id, item_id)
    DO UPDATE SET
        qty_on_hand      = stock_on_hand.qty_on_hand + EXCLUDED.qty_on_hand,
        total_value      = stock_on_hand.total_value + EXCLUDED.total_value,
        last_movement_at = now(),
        updated_at       = now();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. VALIDATE: SUFFICIENT STOCK
-- =====================================================
-- Respects warehouses.allow_negative_stock flag.
-- Raises exception with item name, warehouse name, and quantities.

CREATE OR REPLACE FUNCTION validate_sufficient_stock(
    p_warehouse_id UUID,
    p_item_id UUID,
    p_deduct_qty NUMERIC
)
RETURNS VOID AS $$
DECLARE
    v_allow BOOLEAN;
    v_current NUMERIC;
    v_item_name TEXT;
    v_wh_name TEXT;
BEGIN
    -- Check warehouse setting
    SELECT allow_negative_stock INTO v_allow
    FROM warehouses WHERE id = p_warehouse_id;

    IF COALESCE(v_allow, false) = true THEN
        RETURN;
    END IF;

    -- Get current stock
    SELECT COALESCE(qty_on_hand, 0) INTO v_current
    FROM stock_on_hand
    WHERE warehouse_id = p_warehouse_id AND item_id = p_item_id;

    v_current := COALESCE(v_current, 0);

    IF v_current < p_deduct_qty THEN
        SELECT name INTO v_item_name FROM items WHERE id = p_item_id;
        SELECT name INTO v_wh_name FROM warehouses WHERE id = p_warehouse_id;

        RAISE EXCEPTION 'INSUFFICIENT_STOCK: "%" has % on hand in warehouse "%" but % required.',
            COALESCE(v_item_name, p_item_id::TEXT),
            v_current,
            COALESCE(v_wh_name, p_warehouse_id::TEXT),
            p_deduct_qty;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. VALIDATE: WAREHOUSE EXISTS + ACTIVE
-- =====================================================

CREATE OR REPLACE FUNCTION validate_warehouse_exists(p_warehouse_id UUID)
RETURNS VOID AS $$
DECLARE
    v_exists BOOLEAN;
    v_active BOOLEAN;
BEGIN
    SELECT true, is_active INTO v_exists, v_active
    FROM warehouses WHERE id = p_warehouse_id;

    IF v_exists IS NULL THEN
        RAISE EXCEPTION 'WAREHOUSE_NOT_FOUND: Warehouse % does not exist.', p_warehouse_id;
    END IF;

    IF v_active = false THEN
        RAISE EXCEPTION 'WAREHOUSE_INACTIVE: Warehouse % is deactivated.', p_warehouse_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. VALIDATE: ITEM EXISTS + ACTIVE
-- =====================================================

CREATE OR REPLACE FUNCTION validate_item_exists(p_item_id UUID)
RETURNS VOID AS $$
DECLARE
    v_exists BOOLEAN;
    v_active BOOLEAN;
BEGIN
    SELECT true, is_active INTO v_exists, v_active
    FROM items WHERE id = p_item_id;

    IF v_exists IS NULL THEN
        RAISE EXCEPTION 'ITEM_NOT_FOUND: Item % does not exist.', p_item_id;
    END IF;

    IF v_active = false THEN
        RAISE EXCEPTION 'ITEM_INACTIVE: Item % is deactivated.', p_item_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. VALIDATE: DOCUMENT HAS LINES
-- =====================================================

CREATE OR REPLACE FUNCTION validate_document_lines(p_document_id UUID)
RETURNS VOID AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM inventory_document_lines
    WHERE document_id = p_document_id;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'EMPTY_DOCUMENT: Document % has no line items. Cannot post.',
            p_document_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. VALIDATE: IDEMPOTENCY (not already posted)
-- =====================================================

CREATE OR REPLACE FUNCTION validate_not_already_posted(p_document_id UUID)
RETURNS VOID AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM inventory_ledger
    WHERE document_id = p_document_id
      AND doc_type NOT LIKE 'CANCEL_%';

    IF v_count > 0 THEN
        RAISE EXCEPTION 'ALREADY_POSTED: Document % already has % ledger entries. Cannot post again.',
            p_document_id, v_count;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. BLOCK EDITS ON POSTED / CANCELLED DOCUMENTS
-- =====================================================
-- Only allowed transition from posted → cancelled.
-- All other edits on posted/cancelled docs are blocked.

CREATE OR REPLACE FUNCTION block_posted_doc_edit()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'posted' THEN
        -- Allow only: posted → cancelled
        IF NEW.status = 'cancelled' THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'IMMUTABLE_DOC: Cannot modify posted document "%". Cancel it first.',
            OLD.doc_number;
    END IF;

    IF OLD.status = 'cancelled' THEN
        RAISE EXCEPTION 'IMMUTABLE_DOC: Cannot modify cancelled document "%".',
            OLD.doc_number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_posted_edit ON inventory_documents;
CREATE TRIGGER trg_block_posted_edit
BEFORE UPDATE ON inventory_documents
FOR EACH ROW EXECUTE FUNCTION block_posted_doc_edit();

-- =====================================================
-- 9. BLOCK LINE EDITS ON NON-DRAFT DOCUMENTS
-- =====================================================

CREATE OR REPLACE FUNCTION block_line_edit_on_posted()
RETURNS TRIGGER AS $$
DECLARE
    v_status TEXT;
    v_doc_number TEXT;
BEGIN
    SELECT status, doc_number INTO v_status, v_doc_number
    FROM inventory_documents
    WHERE id = COALESCE(NEW.document_id, OLD.document_id);

    IF v_status != 'draft' THEN
        RAISE EXCEPTION 'IMMUTABLE_LINES: Cannot modify lines of % document "%".',
            v_status, v_doc_number;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_line_edit ON inventory_document_lines;
CREATE TRIGGER trg_block_line_edit
BEFORE INSERT OR UPDATE OR DELETE ON inventory_document_lines
FOR EACH ROW EXECUTE FUNCTION block_line_edit_on_posted();

-- =====================================================
-- 10. CORE POSTING ENGINE (trigger on status change)
-- =====================================================
-- Fires on: UPDATE OF status ON inventory_documents
-- When:     draft → posted  (post document)
--           posted → cancelled (reverse all ledger entries)
--
-- Validations before posting:
--   ✓ Idempotency: no duplicate ledger rows
--   ✓ Document has lines
--   ✓ Warehouse exists and is active
--   ✓ Each item exists and is active
--   ✓ Sufficient stock for OUT movements

CREATE OR REPLACE FUNCTION post_inventory_document()
RETURNS TRIGGER AS $$
DECLARE
    v_line RECORD;
    v_ledger RECORD;
    v_signed_qty NUMERIC;
    v_signed_cost NUMERIC;
    v_line_cost NUMERIC;
    v_old_stock NUMERIC;
    v_new_stock NUMERIC;
BEGIN

    -- =================================================
    -- 1. POSTING: draft → posted
    -- =================================================
    IF NEW.status = 'posted' AND OLD.status = 'draft' THEN

        -- ---- Pre-flight validations -------------------
        PERFORM validate_not_already_posted(NEW.id);
        PERFORM validate_document_lines(NEW.id);
        PERFORM validate_warehouse_exists(NEW.warehouse_id);
        
        IF NEW.doc_type = 'TRANSFER' THEN
            PERFORM validate_warehouse_exists(NEW.target_warehouse_id);
        END IF;

        -- Stamp posted timestamp
        NEW.posted_at := now();

        -- Process each line
        FOR v_line IN
            SELECT * FROM inventory_document_lines
            WHERE document_id = NEW.id
            ORDER BY line_number
        LOOP
            PERFORM validate_item_exists(v_line.item_id);
            v_line_cost := COALESCE(v_line.unit_cost, 0);

            -- A. GRN / OPENING (Stock IN)
            IF NEW.doc_type IN ('GRN', 'OPENING') THEN
                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost,
                    batch_no, expiry_date, posted_by
                ) VALUES (
                    NEW.company_id, NEW.branch_id, NEW.warehouse_id, v_line.item_id,
                    NEW.id, NEW.doc_type, NEW.doc_number,
                    'IN', v_line.quantity, v_line_cost, v_line.quantity * v_line_cost,
                    v_line.batch_no, v_line.expiry_date, NEW.created_by
                );

                PERFORM update_stock_on_hand(
                    NEW.company_id, NEW.warehouse_id, v_line.item_id,
                    v_line.quantity, v_line.quantity * v_line_cost
                );

                -- Cost Update (Items Table) - Weighted Average Cost
                IF NEW.doc_type = 'GRN' AND v_line_cost > 0 THEN
                    -- Calculate current stock excluding this line
                    SELECT COALESCE(SUM(CASE WHEN direction='IN' THEN quantity ELSE -quantity END), 0) INTO v_new_stock
                    FROM inventory_ledger WHERE item_id = v_line.item_id;
                    
                    v_old_stock := v_new_stock - v_line.quantity;

                    UPDATE items SET 
                        last_purchase_price = v_line_cost,
                        avg_cost = CASE 
                            WHEN v_old_stock <= 0 THEN v_line_cost
                            ELSE ( (COALESCE(avg_cost, 0) * v_old_stock) + (v_line_cost * v_line.quantity) ) / v_new_stock
                        END
                    WHERE id = v_line.item_id;
                END IF;

            -- B. GIN / BOM_DEDUCT / RETURN (Stock OUT)
            ELSIF NEW.doc_type IN ('GIN', 'BOM_DEDUCT', 'GIN_ISSUE') THEN
                PERFORM validate_sufficient_stock(NEW.warehouse_id, v_line.item_id, v_line.quantity);
                
                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost,
                    posted_by
                ) VALUES (
                    NEW.company_id, NEW.branch_id, NEW.warehouse_id, v_line.item_id,
                    NEW.id, NEW.doc_type, NEW.doc_number,
                    'OUT', v_line.quantity, v_line_cost, v_line.quantity * v_line_cost,
                    NEW.created_by
                );

                PERFORM update_stock_on_hand(
                    NEW.company_id, NEW.warehouse_id, v_line.item_id,
                    -v_line.quantity, -(v_line.quantity * v_line_cost)
                );

            -- C. TRANSFER (OUT from source, IN to target)
            ELSIF NEW.doc_type = 'TRANSFER' THEN
                PERFORM validate_sufficient_stock(NEW.warehouse_id, v_line.item_id, v_line.quantity);

                -- Outbound
                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost, posted_by
                ) VALUES (
                    NEW.company_id, NEW.branch_id, NEW.warehouse_id, v_line.item_id,
                    NEW.id, NEW.doc_type, NEW.doc_number,
                    'OUT', v_line.quantity, v_line_cost, v_line.quantity * v_line_cost, NEW.created_by
                );
                PERFORM update_stock_on_hand(NEW.company_id, NEW.warehouse_id, v_line.item_id, -v_line.quantity, -(v_line.quantity * v_line_cost));

                -- Inbound
                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost, posted_by
                ) VALUES (
                    NEW.company_id, NEW.branch_id, NEW.target_warehouse_id, v_line.item_id,
                    NEW.id, NEW.doc_type, NEW.doc_number,
                    'IN', v_line.quantity, v_line_cost, v_line.quantity * v_line_cost, NEW.created_by
                );
                PERFORM update_stock_on_hand(NEW.company_id, NEW.target_warehouse_id, v_line.item_id, v_line.quantity, v_line.quantity * v_line_cost);

            -- D. ADJUSTMENT (Signed Qty)
            ELSIF NEW.doc_type = 'ADJUSTMENT' THEN
                IF v_line.quantity < 0 THEN
                    PERFORM validate_sufficient_stock(NEW.warehouse_id, v_line.item_id, ABS(v_line.quantity));
                END IF;

                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost, posted_by
                ) VALUES (
                    NEW.company_id, NEW.branch_id, NEW.warehouse_id, v_line.item_id,
                    NEW.id, NEW.doc_type, NEW.doc_number,
                    CASE WHEN v_line.quantity >= 0 THEN 'IN' ELSE 'OUT' END,
                    ABS(v_line.quantity), v_line_cost, ABS(v_line.quantity * v_line_cost), NEW.created_by
                );

                PERFORM update_stock_on_hand(NEW.company_id, NEW.warehouse_id, v_line.item_id, v_line.quantity, (v_line.quantity * v_line_cost));

            -- E. STOCK_COUNT
            ELSIF NEW.doc_type = 'STOCK_COUNT' THEN
                IF COALESCE(v_line.variance_qty, 0) != 0 THEN
                    IF v_line.variance_qty < 0 THEN
                        PERFORM validate_sufficient_stock(NEW.warehouse_id, v_line.item_id, ABS(v_line.variance_qty));
                    END IF;

                    INSERT INTO inventory_ledger (
                        company_id, branch_id, warehouse_id, item_id,
                        document_id, doc_type, doc_number,
                        direction, quantity, unit_cost, total_cost, posted_by
                    ) VALUES (
                        NEW.company_id, NEW.branch_id, NEW.warehouse_id, v_line.item_id,
                        NEW.id, NEW.doc_type, NEW.doc_number,
                        CASE WHEN v_line.variance_qty > 0 THEN 'IN' ELSE 'OUT' END,
                        ABS(v_line.variance_qty), v_line_cost, ABS(v_line.variance_qty * v_line_cost), NEW.created_by
                    );

                    PERFORM update_stock_on_hand(NEW.company_id, NEW.warehouse_id, v_line.item_id, v_line.variance_qty, (v_line.variance_qty * v_line_cost));
                END IF;
            END IF;
        END LOOP;

        -- Update document totals
        SELECT COALESCE(SUM(quantity), 0), COALESCE(SUM(quantity * unit_cost), 0)
        INTO NEW.total_qty, NEW.total_cost
        FROM inventory_document_lines WHERE document_id = NEW.id;

    -- =================================================
    -- 2. CANCELLATION: posted → cancelled
    -- =================================================
    ELSIF NEW.status = 'cancelled' AND OLD.status = 'posted' THEN
        NEW.cancelled_at := now();

        FOR v_ledger IN 
            SELECT * FROM inventory_ledger 
            WHERE document_id = NEW.id 
              AND doc_type NOT LIKE 'CANCEL_%'
        LOOP
            -- Reverse Entry
            INSERT INTO inventory_ledger (
                company_id, branch_id, warehouse_id, item_id,
                document_id, doc_type, doc_number,
                direction, quantity, unit_cost, total_cost, posted_by
            ) VALUES (
                v_ledger.company_id, v_ledger.branch_id, v_ledger.warehouse_id, v_ledger.item_id,
                NEW.id, 'CANCEL_' || v_ledger.doc_type, v_ledger.doc_number || '-REV',
                CASE WHEN v_ledger.direction = 'IN' THEN 'OUT' ELSE 'IN' END,
                v_ledger.quantity, v_ledger.unit_cost, v_ledger.total_cost, NEW.created_by
            );

            -- Stock reversal
            v_signed_qty := CASE WHEN v_ledger.direction = 'IN' THEN -v_ledger.quantity ELSE v_ledger.quantity END;
            v_signed_cost := CASE WHEN v_ledger.direction = 'IN' THEN -v_ledger.total_cost ELSE v_ledger.total_cost END;

            PERFORM update_stock_on_hand(v_ledger.company_id, v_ledger.warehouse_id, v_ledger.item_id, v_signed_qty, v_signed_cost);
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_post_inventory ON inventory_documents;
CREATE TRIGGER trg_post_inventory
BEFORE UPDATE OF status ON inventory_documents
FOR EACH ROW EXECUTE FUNCTION post_inventory_document();

-- =====================================================
-- 11. BOM / RECIPE AUTO-DEDUCTION AT INVOICING
-- =====================================================
-- Trigger on invoices INSERT.
-- Finds recipe for each order item, creates BOM_DEDUCT document,
-- auto-posts it to deduct kitchen stock.

CREATE OR REPLACE FUNCTION deduct_bom_for_invoice()
RETURNS TRIGGER AS $$
DECLARE
    v_order RECORD;
    v_oi RECORD;
    v_recipe RECORD;
    v_ri RECORD;
    v_doc_id UUID;
    v_wh_id UUID;
    v_doc_number TEXT;
    v_line_num INT := 0;
    v_has_lines BOOLEAN := false;
BEGIN
    -- Get order
    SELECT * INTO v_order FROM orders WHERE id = NEW.order_id;
    IF v_order.id IS NULL THEN RETURN NEW; END IF;

    -- Find kitchen warehouse (priority: linked to kitchen, then any kitchen, then main)
    SELECT w.id INTO v_wh_id
    FROM warehouses w
    WHERE w.branch_id = v_order.branch_id
      AND w.warehouse_type = 'kitchen'
      AND w.is_active = true
    ORDER BY w.is_default DESC
    LIMIT 1;

    IF v_wh_id IS NULL THEN
        SELECT w.id INTO v_wh_id
        FROM warehouses w
        WHERE w.branch_id = v_order.branch_id
          AND w.is_default = true AND w.is_active = true
        LIMIT 1;
    END IF;

    IF v_wh_id IS NULL THEN RETURN NEW; END IF;

    v_doc_number := generate_inv_doc_number(v_order.company_id, 'BOM_DEDUCT');

    -- Create BOM document as draft
    INSERT INTO inventory_documents (
        company_id, branch_id, doc_type, doc_number, doc_date,
        warehouse_id, reference_id, reference_type, status,
        remarks, created_by
    ) VALUES (
        v_order.company_id, v_order.branch_id, 'BOM_DEDUCT',
        v_doc_number, CURRENT_DATE,
        v_wh_id, NEW.id, 'invoice', 'draft',
        'Auto BOM deduction for invoice ' || NEW.id::TEXT,
        NEW.created_by
    ) RETURNING id INTO v_doc_id;

    -- Build lines from recipes
    FOR v_oi IN
        SELECT oi.menu_item_id, oi.variant_id, oi.quantity
        FROM order_items oi
        WHERE oi.order_id = NEW.order_id
          AND oi.status != 'cancelled'
    LOOP
        -- Recipe lookup: variant-specific first, then base
        SELECT r.* INTO v_recipe
        FROM recipes r
        WHERE r.menu_item_id = v_oi.menu_item_id
          AND r.is_active = true
        ORDER BY
            CASE
                WHEN r.variant_id = v_oi.variant_id THEN 1
                WHEN r.variant_id IS NULL THEN 2
                ELSE 3
            END
        LIMIT 1;

        IF v_recipe.id IS NOT NULL THEN
            FOR v_ri IN
                SELECT ri.item_id, ri.qty_per_serving, ri.uom_id
                FROM recipe_items ri
                WHERE ri.recipe_id = v_recipe.id
            LOOP
                v_line_num := v_line_num + 1;
                v_has_lines := true;

                INSERT INTO inventory_document_lines (
                    document_id, line_number, item_id, uom_id,
                    quantity, unit_cost, notes
                )
                SELECT
                    v_doc_id, v_line_num, v_ri.item_id, v_ri.uom_id,
                    (v_ri.qty_per_serving * v_oi.quantity)
                        / GREATEST(v_recipe.yield_qty, 1),
                    COALESCE(i.avg_cost, 0),
                    'BOM for menu item ' || v_oi.menu_item_id::TEXT
                FROM items i WHERE i.id = v_ri.item_id;
            END LOOP;
        END IF;
    END LOOP;

    -- Post or discard
    IF v_has_lines THEN
        UPDATE inventory_documents
        SET status = 'posted'
        WHERE id = v_doc_id;
    ELSE
        DELETE FROM inventory_documents WHERE id = v_doc_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='invoices') THEN
        DROP TRIGGER IF EXISTS trg_invoice_bom_deduct ON invoices;
        CREATE TRIGGER trg_invoice_bom_deduct
        AFTER INSERT ON invoices
        FOR EACH ROW EXECUTE FUNCTION deduct_bom_for_invoice();
    END IF;
END $$;

-- =====================================================
-- 12. HELPER VIEWS
-- =====================================================
-- DROP in dependency order (v_low_stock_alerts depends on v_stock_on_hand)
-- before recreating, so PostgreSQL doesn't reject column type changes.
DROP VIEW IF EXISTS v_low_stock_alerts CASCADE;
DROP VIEW IF EXISTS v_stock_on_hand CASCADE;
DROP VIEW IF EXISTS v_inventory_ledger CASCADE;

CREATE OR REPLACE VIEW v_stock_on_hand AS
SELECT
    soh.company_id,
    soh.warehouse_id,
    w.code AS warehouse_code,
    w.name AS warehouse_name,
    w.warehouse_type,
    w.branch_id,
    soh.item_id,
    i.code AS item_code,
    i.name AS item_name,
    ic.name AS category_name,
    u.code AS uom_code,
    soh.qty_on_hand,
    soh.total_value,
    COALESCE(iws.reorder_level, i.reorder_level, 0) AS reorder_level,
    COALESCE(iws.min_stock, 0) AS min_stock,
    COALESCE(iws.max_stock, 0) AS max_stock,
    CASE
        WHEN soh.qty_on_hand <= 0
            THEN 'out_of_stock'
        WHEN soh.qty_on_hand <= COALESCE(iws.reorder_level, i.reorder_level, 0)
            THEN 'low_stock'
        WHEN COALESCE(iws.max_stock, 0) > 0
             AND soh.qty_on_hand >= iws.max_stock
            THEN 'overstock'
        ELSE 'normal'
    END AS stock_status,
    soh.last_movement_at
FROM stock_on_hand soh
JOIN warehouses w ON w.id = soh.warehouse_id
JOIN items i ON i.id = soh.item_id
LEFT JOIN item_categories ic ON ic.id = i.category_id
LEFT JOIN uom u ON u.id = i.inventory_uom_id
LEFT JOIN item_warehouse_settings iws
    ON iws.item_id = soh.item_id
   AND iws.warehouse_id = soh.warehouse_id;

CREATE OR REPLACE VIEW v_low_stock_alerts AS
SELECT * FROM v_stock_on_hand
WHERE stock_status IN ('low_stock', 'out_of_stock');

CREATE OR REPLACE VIEW v_inventory_ledger AS
SELECT
    il.id,
    il.company_id,
    il.branch_id,
    il.warehouse_id,
    w.name AS warehouse_name,
    il.item_id,
    i.code AS item_code,
    i.name AS item_name,
    u.code AS uom_code,
    il.doc_type,
    il.doc_number,
    il.direction,
    il.quantity,
    il.unit_cost,
    il.total_cost,
    il.batch_no,
    il.reference_id,
    il.reference_type,
    p.full_name AS posted_by_name,
    il.posted_at
FROM inventory_ledger il
JOIN warehouses w ON w.id = il.warehouse_id
JOIN items i ON i.id = il.item_id
LEFT JOIN uom u ON u.id = i.inventory_uom_id
LEFT JOIN profiles p ON p.id = il.posted_by;

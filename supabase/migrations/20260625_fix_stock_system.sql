-- ============================================================================
-- FIX: Stock System — 3 Critical Bugs
-- Date: 2026-06-25
-- Lead: Alex (Tech Lead) / DBA: Maya
--
-- BUG-001: GIN_ISSUE missing from chk_inv_doc_type constraint
--   Symptom: Creating a GIN_ISSUE document fails with constraint violation.
--
-- BUG-002: v_items_registry.total_qty subquery missing company_id filter
--   Symptom: Items list shows stock summed across ALL companies, not just the
--            current tenant. In multi-tenant or during data migration this
--            produces wrong values.
--
-- BUG-003: post_inventory_document() avg cost calc missing company_id filter
--   Symptom: Weighted-average cost is summed from all companies' ledger entries
--            for the same item_id. Defensive fix for multi-tenant correctness.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- BUG-001: Add GIN_ISSUE (and SERVICE_PART / SERVICE_PART_REVERSAL for ledger
--          compatibility) to chk_inv_doc_type constraint.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE inventory_documents DROP CONSTRAINT IF EXISTS chk_inv_doc_type;

ALTER TABLE inventory_documents
    ADD CONSTRAINT chk_inv_doc_type CHECK (
        doc_type IN (
            'GRN', 'GIN', 'GIN_ISSUE',
            'TRANSFER', 'ADJUSTMENT',
            'STOCK_COUNT', 'BOM_DEDUCT',
            'OPENING', 'PO'
        )
    );

-- ─────────────────────────────────────────────────────────────────────────────
-- BUG-002: Recreate v_items_registry with company-scoped total_qty
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_items_registry WITH (security_invoker = true) AS
SELECT
    i.*,
    ic.name  AS category_name,
    u.code   AS uom_code,
    u.name   AS uom_name,
    s.name   AS supplier_name,
    COALESCE((
        SELECT SUM(soh.qty_on_hand)
        FROM stock_on_hand soh
        WHERE soh.item_id    = i.id
          AND soh.company_id = i.company_id   -- BUG-002 fix: scope to same company
    ), 0) AS total_qty
FROM items i
LEFT JOIN item_categories ic ON ic.id = i.category_id
LEFT JOIN uom              u  ON u.id  = i.inventory_uom_id
LEFT JOIN suppliers        s  ON s.id  = i.default_supplier_id;

-- Grant to authenticated only — anon must NOT see item registry (CRIT-002)
GRANT SELECT ON v_items_registry TO authenticated, service_role;
REVOKE SELECT ON v_items_registry FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- BUG-003: Recreate post_inventory_document() with company-scoped avg cost sum
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION post_inventory_document()
RETURNS TRIGGER AS $$
DECLARE
    v_line       RECORD;
    v_ledger     RECORD;
    v_signed_qty  NUMERIC;
    v_signed_cost NUMERIC;
    v_line_cost   NUMERIC;
    v_old_stock   NUMERIC;
    v_new_stock   NUMERIC;
BEGIN

    -- =========================================================
    -- 1. POSTING: draft → posted
    -- =========================================================
    IF NEW.status = 'posted' AND OLD.status = 'draft' THEN

        PERFORM validate_not_already_posted(NEW.id);
        PERFORM validate_document_lines(NEW.id);
        PERFORM validate_warehouse_exists(NEW.warehouse_id);

        IF NEW.doc_type = 'TRANSFER' THEN
            PERFORM validate_warehouse_exists(NEW.target_warehouse_id);
        END IF;

        NEW.posted_at := now();

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

                -- Weighted-Average Cost (GRN only)
                IF NEW.doc_type = 'GRN' AND v_line_cost > 0 THEN
                    -- BUG-003 fix: scope ledger sum to same company
                    SELECT COALESCE(
                        SUM(CASE WHEN direction = 'IN' THEN quantity ELSE -quantity END),
                        0
                    ) INTO v_new_stock
                    FROM inventory_ledger
                    WHERE item_id   = v_line.item_id
                      AND company_id = NEW.company_id;   -- ← added

                    v_old_stock := v_new_stock - v_line.quantity;

                    UPDATE items SET
                        last_purchase_price = v_line_cost,
                        avg_cost = CASE
                            WHEN v_old_stock <= 0 THEN v_line_cost
                            ELSE (
                                (COALESCE(avg_cost, 0) * v_old_stock)
                                + (v_line_cost * v_line.quantity)
                            ) / v_new_stock
                        END
                    WHERE id = v_line.item_id;
                END IF;

            -- B. GIN / BOM_DEDUCT / GIN_ISSUE (Stock OUT)
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

                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost, posted_by
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

                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost, posted_by
                ) VALUES (
                    NEW.company_id, NEW.branch_id, NEW.target_warehouse_id, v_line.item_id,
                    NEW.id, NEW.doc_type, NEW.doc_number,
                    'IN', v_line.quantity, v_line_cost, v_line.quantity * v_line_cost,
                    NEW.created_by
                );
                PERFORM update_stock_on_hand(
                    NEW.company_id, NEW.target_warehouse_id, v_line.item_id,
                    v_line.quantity, v_line.quantity * v_line_cost
                );

            -- D. ADJUSTMENT (Signed Qty)
            ELSIF NEW.doc_type = 'ADJUSTMENT' THEN
                IF v_line.quantity < 0 THEN
                    PERFORM validate_sufficient_stock(
                        NEW.warehouse_id, v_line.item_id, ABS(v_line.quantity)
                    );
                END IF;

                INSERT INTO inventory_ledger (
                    company_id, branch_id, warehouse_id, item_id,
                    document_id, doc_type, doc_number,
                    direction, quantity, unit_cost, total_cost, posted_by
                ) VALUES (
                    NEW.company_id, NEW.branch_id, NEW.warehouse_id, v_line.item_id,
                    NEW.id, NEW.doc_type, NEW.doc_number,
                    CASE WHEN v_line.quantity >= 0 THEN 'IN' ELSE 'OUT' END,
                    ABS(v_line.quantity), v_line_cost,
                    ABS(v_line.quantity * v_line_cost),
                    NEW.created_by
                );

                PERFORM update_stock_on_hand(
                    NEW.company_id, NEW.warehouse_id, v_line.item_id,
                    v_line.quantity, v_line.quantity * v_line_cost
                );

            -- E. STOCK_COUNT (variance only)
            ELSIF NEW.doc_type = 'STOCK_COUNT' THEN
                IF COALESCE(v_line.variance_qty, 0) != 0 THEN
                    IF v_line.variance_qty < 0 THEN
                        PERFORM validate_sufficient_stock(
                            NEW.warehouse_id, v_line.item_id, ABS(v_line.variance_qty)
                        );
                    END IF;

                    INSERT INTO inventory_ledger (
                        company_id, branch_id, warehouse_id, item_id,
                        document_id, doc_type, doc_number,
                        direction, quantity, unit_cost, total_cost, posted_by
                    ) VALUES (
                        NEW.company_id, NEW.branch_id, NEW.warehouse_id, v_line.item_id,
                        NEW.id, NEW.doc_type, NEW.doc_number,
                        CASE WHEN v_line.variance_qty > 0 THEN 'IN' ELSE 'OUT' END,
                        ABS(v_line.variance_qty), v_line_cost,
                        ABS(v_line.variance_qty * v_line_cost),
                        NEW.created_by
                    );

                    PERFORM update_stock_on_hand(
                        NEW.company_id, NEW.warehouse_id, v_line.item_id,
                        v_line.variance_qty, v_line.variance_qty * v_line_cost
                    );
                END IF;

            -- F. PO — no stock movement, header-only
            -- (PO is a procurement intent, stock moves only on GRN)
            END IF;
        END LOOP;

        -- Update document totals
        SELECT
            COALESCE(SUM(quantity), 0),
            COALESCE(SUM(quantity * unit_cost), 0)
        INTO NEW.total_qty, NEW.total_cost
        FROM inventory_document_lines
        WHERE document_id = NEW.id;

    -- =========================================================
    -- 2. CANCELLATION: posted → cancelled
    -- =========================================================
    ELSIF NEW.status = 'cancelled' AND OLD.status = 'posted' THEN
        NEW.cancelled_at := now();

        FOR v_ledger IN
            SELECT * FROM inventory_ledger
            WHERE document_id = NEW.id
              AND doc_type NOT LIKE 'CANCEL_%'
        LOOP
            INSERT INTO inventory_ledger (
                company_id, branch_id, warehouse_id, item_id,
                document_id, doc_type, doc_number,
                direction, quantity, unit_cost, total_cost, posted_by
            ) VALUES (
                v_ledger.company_id, v_ledger.branch_id, v_ledger.warehouse_id, v_ledger.item_id,
                NEW.id,
                'CANCEL_' || v_ledger.doc_type,
                v_ledger.doc_number || '-REV',
                CASE WHEN v_ledger.direction = 'IN' THEN 'OUT' ELSE 'IN' END,
                v_ledger.quantity, v_ledger.unit_cost, v_ledger.total_cost,
                NEW.created_by
            );

            v_signed_qty  := CASE WHEN v_ledger.direction = 'IN' THEN -v_ledger.quantity  ELSE v_ledger.quantity  END;
            v_signed_cost := CASE WHEN v_ledger.direction = 'IN' THEN -v_ledger.total_cost ELSE v_ledger.total_cost END;

            PERFORM update_stock_on_hand(
                v_ledger.company_id, v_ledger.warehouse_id, v_ledger.item_id,
                v_signed_qty, v_signed_cost
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Rebind trigger (idempotent)
DROP TRIGGER IF EXISTS trg_post_inventory ON inventory_documents;
CREATE TRIGGER trg_post_inventory
BEFORE UPDATE OF status ON inventory_documents
FOR EACH ROW EXECUTE FUNCTION post_inventory_document();

-- ─────────────────────────────────────────────────────────────────────────────
-- BUG-004: Fix SECURITY DEFINER warnings on views
--          (Supabase Advisor Linter Error 0010_security_definer_view)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER VIEW v_stock_on_hand SET (security_invoker = true);
ALTER VIEW v_inventory_ledger SET (security_invoker = true);
ALTER VIEW v_low_stock_alerts SET (security_invoker = true);

-- ─────────────────────────────────────────────────────────────────────────────
-- Reload PostgREST schema cache
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

COMMIT;

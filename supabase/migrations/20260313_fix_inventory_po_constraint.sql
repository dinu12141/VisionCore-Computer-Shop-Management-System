-- ============================================================================
-- FIX: Add 'PO' to inventory_documents doc_type constraint
--      Drop restaurant-leftover BOM trigger
-- Date: 2026-03-13
-- Bugs fixed: BUG-1 (PO creates fail), BUG-11 (BOM trigger leftover)
-- ============================================================================

-- ─── 1. Fix chk_inv_doc_type — add 'PO' ────────────────────────────────────
ALTER TABLE inventory_documents DROP CONSTRAINT IF EXISTS chk_inv_doc_type;

ALTER TABLE inventory_documents
    ADD CONSTRAINT chk_inv_doc_type CHECK (
        doc_type IN (
            'GRN', 'GIN', 'TRANSFER',
            'ADJUSTMENT', 'STOCK_COUNT',
            'BOM_DEDUCT', 'OPENING', 'PO'
        )
    );

-- ─── 2. Drop restaurant-leftover BOM trigger + function ────────────────────
-- This trigger fires on invoice INSERT and tries to deduct BOM recipes.
-- This shop is a computer parts retailer — no BOM/recipe concept exists.
-- The trigger references tables that don't exist, causing silent errors.
DROP TRIGGER IF EXISTS trg_invoice_bom_deduct ON invoices;
DROP FUNCTION IF EXISTS deduct_bom_for_invoice() CASCADE;

-- ─── 3. Fix chk_wh_type — add 'showroom' (used in create_invoice_v2) ───────
-- The posting engine selects warehouses by type = 'showroom' but the
-- constraint doesn't include it, so the filter always evaluates FALSE
-- and falls back to any active warehouse by default ordering.
-- Adding 'showroom' makes the type filter work as intended.
ALTER TABLE warehouses DROP CONSTRAINT IF EXISTS chk_wh_type;

ALTER TABLE warehouses
    ADD CONSTRAINT chk_wh_type CHECK (
        warehouse_type IN (
            'main_store', 'showroom', 'kitchen', 'bar',
            'freezer', 'dry_store', 'other'
        )
    );

NOTIFY pgrst, 'reload schema';

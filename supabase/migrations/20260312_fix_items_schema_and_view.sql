-- ============================================================================
-- FIX: Add missing columns to items table and recreate v_items_registry view
-- Date: 2026-03-12
-- Root cause: The items table was missing columns that the frontend UI expects
--   (cost_price, sale_price, brand, model_number, barcode, warranty, serials, attrs).
--   The v_items_registry view was also deleted during a previous DB cleanup,
--   causing listItems() to fail silently.
-- ============================================================================

-- 1. Add missing columns that the frontend UI expects
ALTER TABLE items ADD COLUMN IF NOT EXISTS cost_price NUMERIC(14,2) DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS sale_price NUMERIC(14,2) DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS brand TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS model_number TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS warranty TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS serials JSONB DEFAULT '[]'::jsonb;
ALTER TABLE items ADD COLUMN IF NOT EXISTS attrs JSONB DEFAULT '[]'::jsonb;

-- 2. Recreate the v_items_registry view (was dropped during DB cleanup)
CREATE OR REPLACE VIEW v_items_registry WITH (security_invoker = true) AS
SELECT 
    i.*,
    ic.name AS category_name,
    u.code AS uom_code,
    u.name AS uom_name,
    s.name AS supplier_name,
    COALESCE((
        SELECT SUM(soh.qty_on_hand) 
        FROM stock_on_hand soh
        WHERE soh.item_id = i.id
    ), 0) AS total_qty
FROM items i
LEFT JOIN item_categories ic ON i.category_id = ic.id
LEFT JOIN uom u ON i.inventory_uom_id = u.id
LEFT JOIN suppliers s ON i.default_supplier_id = s.id;

-- 3. Grant permissions on the view
GRANT SELECT ON v_items_registry TO anon, authenticated, service_role;

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

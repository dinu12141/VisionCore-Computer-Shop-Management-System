-- =====================================================
-- FIX CORRUPTED STOCK VALUES DUE TO SERVICE JOB BUG (CORRECTED)
-- =====================================================

BEGIN;

-- 1. Find the latest valid unit_cost from an IN transaction for each item
WITH latest_costs AS (
    SELECT DISTINCT ON (item_id) item_id, unit_cost
    FROM inventory_ledger
    WHERE direction = 'IN' AND unit_cost > 0
    ORDER BY item_id, posted_at DESC
)
-- 2. Update the items table to correct the avg_cost and last_purchase_price
UPDATE items
SET 
  avg_cost = lc.unit_cost,
  last_purchase_price = lc.unit_cost
FROM latest_costs lc
WHERE items.id = lc.item_id;

-- 3. Fix the inventory ledger unit_cost for SERVICE_PART
UPDATE inventory_ledger
SET unit_cost = i.avg_cost,
    total_cost = inventory_ledger.quantity * i.avg_cost
FROM items i
WHERE inventory_ledger.item_id = i.id 
  AND inventory_ledger.doc_type IN ('SERVICE_PART', 'SERVICE_PART_REVERSAL');

-- 4. Re-calculate the correct total_value for stock_on_hand
UPDATE stock_on_hand
SET total_value = stock_on_hand.qty_on_hand * COALESCE(i.avg_cost, 0)
FROM items i
WHERE stock_on_hand.item_id = i.id;

COMMIT;
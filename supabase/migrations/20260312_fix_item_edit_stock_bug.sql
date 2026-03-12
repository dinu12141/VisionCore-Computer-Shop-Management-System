-- =========================================================================
-- FIX: Stop Item Name Edits from Overwriting Stock Summaries
-- =========================================================================
-- The trg_sync_serials or similar triggers were causing the total stock 
-- to be blindly recalculated based on the length of the serials array 
-- anytime the items master row was updated, wiping out GRN stock.

-- We disable any triggers on the `items` table that attempt to perform
-- implicit stock adjustments without a formalized inventory_documents transaction.

DROP TRIGGER IF EXISTS trg_sync_serials ON items;
DROP FUNCTION IF EXISTS sync_serials_stock() CASCADE;

-- If there is a different naming convention used in the local environment,
-- uncomment and replace below with the actual trigger name:
-- DROP TRIGGER IF EXISTS [offending_trigger_name] ON items;

-- Validation Note:
-- Stock levels MUST strictly be modified via:
-- 1. GRN (Good Receiving Notes)
-- 2. GIN / Invoices (Dispatch)
-- 3. Inventory Adjustments
-- Modifying the master `items` catalog MUST NOT mutate `stock_on_hand` or `items.serials` directly!

-- =====================================================
-- ADD TITLE COLUMN TO CUSTOMERS
-- =====================================================

BEGIN;

ALTER TABLE customers ADD COLUMN IF NOT EXISTS title TEXT;

COMMIT;

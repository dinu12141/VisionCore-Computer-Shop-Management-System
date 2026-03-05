-- ============================================================================
-- MIGRATION: Add Serial Number to Invoice Items
-- Date: 2026-03-05
-- Description: Adds serial_number and warranty columns to invoice_items table
--              if they don't already exist.
-- ============================================================================

DO $$ 
BEGIN 
    -- Add serial_number column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invoice_items' AND column_name = 'serial_number') THEN
        ALTER TABLE invoice_items ADD COLUMN serial_number TEXT;
    END IF;

    -- Add warranty column if it doesn't exist (it should, but just in case)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invoice_items' AND column_name = 'warranty') THEN
        ALTER TABLE invoice_items ADD COLUMN warranty TEXT;
    END IF;
END $$;

-- Add comments for clarity
COMMENT ON COLUMN invoice_items.serial_number IS 'Unique serial number of the unit sold';
COMMENT ON COLUMN invoice_items.warranty IS 'Warranty details for this specific line item';

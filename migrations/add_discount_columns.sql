-- Run this in Supabase SQL Editor for project: ovdheejmgchtohnjozpn
-- Adds discount_type and discount_amount columns to invoice_items

ALTER TABLE invoice_items
  ADD COLUMN IF NOT EXISTS discount_type text NOT NULL DEFAULT 'amount';

ALTER TABLE invoice_items
  ADD COLUMN IF NOT EXISTS discount_amount numeric NOT NULL DEFAULT 0;

-- Validate discount_type values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_discount_type'
  ) THEN
    ALTER TABLE invoice_items
      ADD CONSTRAINT chk_discount_type CHECK (discount_type IN ('amount', 'percent'));
  END IF;
END $$;

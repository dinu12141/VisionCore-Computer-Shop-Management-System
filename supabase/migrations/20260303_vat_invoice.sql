-- ============================================================================
-- MIGRATION: Add VAT Invoice Support
-- Date: 2026-03-03
-- Description: Adds is_vat_invoice, vat_amount, and total_before_vat columns
--              to the invoices table to support VAT/Tax invoices at 18%
-- ============================================================================

-- Add VAT-related columns to invoices table
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS is_vat_invoice BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS vat_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (vat_amount >= 0);
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS total_before_vat NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_before_vat >= 0);

-- Add a comment for clarity
COMMENT ON COLUMN invoices.is_vat_invoice IS 'Whether this invoice includes VAT (18%)';
COMMENT ON COLUMN invoices.vat_amount IS 'The calculated VAT amount (18% of total before VAT)';
COMMENT ON COLUMN invoices.total_before_vat IS 'Invoice total before VAT was applied';

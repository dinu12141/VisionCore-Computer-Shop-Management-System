-- ============================================================================
-- MIGRATION: Change Invoice Number Format to Simple 5-digit Numbers
-- Date: 2026-03-03
-- Description: Changes invoice_no from 'INV-2026-000045' to '00001' format
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_assign_invoice_no()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_no IS NULL THEN
        NEW.invoice_no := LPAD(get_next_counter_value(NEW.company_id, 'invoice')::TEXT, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

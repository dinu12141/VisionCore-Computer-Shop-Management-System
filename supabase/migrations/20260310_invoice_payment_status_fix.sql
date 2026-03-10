-- Replace the trigger with a very safe and explicit implementation
CREATE OR REPLACE FUNCTION trg_update_invoice_balance_from_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_id UUID;
    v_total_paid NUMERIC(14,2);
BEGIN
    -- Determine which invoice ID to update
    IF TG_OP = 'DELETE' THEN
        v_invoice_id := OLD.invoice_id;
    ELSE
        v_invoice_id := NEW.invoice_id;
    END IF;

    -- Calculate total paid for this invoice from invoice_payments
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_paid
    FROM invoice_payments
    WHERE invoice_id = v_invoice_id;

    -- Update the invoice paid_amount and balance explicitly using alias
    UPDATE invoices inv
    SET 
        paid_amount = v_total_paid,
        balance = GREATEST(0, inv.total - v_total_paid)
    WHERE inv.id = v_invoice_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

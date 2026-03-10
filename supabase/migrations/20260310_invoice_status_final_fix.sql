-- 1. FIX STATUS CONSTRAINT
ALTER TABLE invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_check 
CHECK (status IN ('draft', 'issued', 'unpaid', 'paid', 'cancelled'));

-- 2. REVISED STATUS TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION trg_update_invoice_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Only auto-update status if it's not draft or cancelled
    IF NEW.status NOT IN ('draft', 'cancelled') THEN
        IF NEW.balance <= 0 THEN
            NEW.status := 'paid';
        ELSIF NEW.paid_amount > 0 THEN
            NEW.status := 'issued'; -- Partial payment
        ELSE
            NEW.status := 'unpaid'; -- Zero payment
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_invoice_status ON invoices;
CREATE TRIGGER trg_auto_invoice_status
BEFORE UPDATE OR INSERT ON invoices
FOR EACH ROW
EXECUTE FUNCTION trg_update_invoice_status();

-- 3. REVISED BALANCE TRIGGER FUNCTION (Fixing shadowing bug)
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

    -- Update the invoice paid_amount and balance explicitly using alias 'inv'
    -- This prevents the 'total' column from being shadowed or misinterpreted
    UPDATE invoices inv
    SET 
        paid_amount = v_total_paid,
        balance = inv.total - v_total_paid
    WHERE inv.id = v_invoice_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payment_update_invoice ON invoice_payments;
CREATE TRIGGER trg_payment_update_invoice
AFTER INSERT OR UPDATE OR DELETE ON invoice_payments
FOR EACH ROW
EXECUTE FUNCTION trg_update_invoice_balance_from_payment();

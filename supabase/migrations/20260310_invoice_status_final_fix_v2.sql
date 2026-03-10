-- 1. ADD MISSING COLUMNS TO INVOICES
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(14,2) DEFAULT 0;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS balance NUMERIC(14,2) DEFAULT 0;

-- 2. SYNC EXISTING DATA
UPDATE invoices inv
SET 
    paid_amount = (SELECT COALESCE(SUM(amount), 0) FROM payments p WHERE p.invoice_id = inv.id),
    balance = grand_total - (SELECT COALESCE(SUM(amount), 0) FROM payments p WHERE p.invoice_id = inv.id);

-- 3. FIX STATUS CONSTRAINT
ALTER TABLE invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_check 
CHECK (status IN ('draft', 'issued', 'unpaid', 'paid', 'cancelled'));

-- 4. TRIGGER FUNCTION FOR INVOICE BALANCE (FROM PAYMENTS)
CREATE OR REPLACE FUNCTION trg_update_invoice_balance_from_payment_v2()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_id UUID;
    v_total_paid NUMERIC(14,2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_invoice_id := OLD.invoice_id;
    ELSE
        v_invoice_id := NEW.invoice_id;
    END IF;

    IF v_invoice_id IS NOT NULL THEN
        SELECT COALESCE(SUM(amount), 0)
        INTO v_total_paid
        FROM payments
        WHERE invoice_id = v_invoice_id;

        UPDATE invoices inv
        SET 
            paid_amount = v_total_paid,
            balance = inv.grand_total - v_total_paid
        WHERE inv.id = v_invoice_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payment_update_invoice_v2 ON payments;
CREATE TRIGGER trg_payment_update_invoice_v2
AFTER INSERT OR UPDATE OR DELETE ON payments
FOR EACH ROW
EXECUTE FUNCTION trg_update_invoice_balance_from_payment_v2();

-- 5. TRIGGER FUNCTION FOR INVOICE STATUS
CREATE OR REPLACE FUNCTION trg_update_invoice_status_v2()
RETURNS TRIGGER AS $$
BEGIN
    -- Only auto-update status if it's not draft or cancelled
    IF NEW.status NOT IN ('draft', 'cancelled') THEN
        IF NEW.balance <= 0 THEN
            NEW.status := 'paid';
            NEW.payment_status := 'paid';
        ELSIF NEW.paid_amount > 0 THEN
            NEW.status := 'issued'; -- Partial payment
            NEW.payment_status := 'partial';
        ELSE
            NEW.status := 'unpaid'; -- Zero payment
            NEW.payment_status := 'unpaid';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_invoice_status_v2 ON invoices;
CREATE TRIGGER trg_auto_invoice_status_v2
BEFORE UPDATE OR INSERT ON invoices
FOR EACH ROW
EXECUTE FUNCTION trg_update_invoice_status_v2();

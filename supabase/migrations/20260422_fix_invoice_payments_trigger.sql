-- ============================================================================
-- FIX: Invoice Payments → Outstanding Flow
-- Date: 2026-04-22
--
-- ROOT CAUSE:
--   The frontend inserts payments into the `invoice_payments` table,
--   but there was NO trigger on that table to auto-update the parent
--   invoice's paid_amount, balance, payment_status, and status.
--   The old trigger only existed on the legacy `payments` table (from
--   the restaurant POS system), which is NOT used by the Computer ERP.
--
-- WHAT THIS FIXES:
--   1. Creates a trigger on `invoice_payments` that auto-updates the
--      parent invoice whenever a payment is added/changed/deleted
--   2. Aligns the invoice BEFORE trigger status values with ERP conventions
--   3. Migrates existing payment records from legacy `payments` table
--      to `invoice_payments` for data consistency
--   4. Re-syncs all invoice balances from actual payment records
--
-- RESULT:
--   - Unpaid invoices now correctly show in Outstanding Collections
--   - Payments made from Outstanding properly reduce the balance
--   - Invoice status auto-updates: unpaid → partial → paid
-- ============================================================================

-- ─── 1. TRIGGER FUNCTION FOR invoice_payments ─────────────────────────────
CREATE OR REPLACE FUNCTION fn_update_invoice_from_invoice_payments()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_id     UUID;
    v_total_paid     NUMERIC(14,2);
    v_inv_total      NUMERIC(14,2);
    v_new_balance    NUMERIC(14,2);
    v_new_pay_status TEXT;
    v_new_status     TEXT;
BEGIN
    -- Determine which invoice to update
    IF TG_OP = 'DELETE' THEN
        v_invoice_id := OLD.invoice_id;
    ELSE
        v_invoice_id := NEW.invoice_id;
    END IF;

    IF v_invoice_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Sum ALL payments for this invoice from invoice_payments
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_paid
    FROM invoice_payments
    WHERE invoice_id = v_invoice_id;

    -- Get invoice total
    SELECT COALESCE(total, 0) INTO v_inv_total 
    FROM invoices WHERE id = v_invoice_id;

    -- Calculate new balance (never negative)
    v_new_balance := GREATEST(v_inv_total - v_total_paid, 0);

    -- Determine payment_status
    IF v_total_paid >= v_inv_total AND v_total_paid > 0 THEN
        v_new_pay_status := 'paid';
        v_new_status     := 'paid';
    ELSIF v_total_paid > 0 THEN
        v_new_pay_status := 'partial';
        v_new_status     := 'issued';
    ELSE
        v_new_pay_status := 'unpaid';
        v_new_status     := 'unpaid';
    END IF;

    -- Update the invoice row
    UPDATE invoices
    SET
        paid_amount    = v_total_paid,
        balance        = v_new_balance,
        payment_status = v_new_pay_status,
        status         = CASE
                           WHEN status NOT IN ('cancelled', 'draft')
                           THEN v_new_status
                           ELSE status
                         END,
        collection_date = CASE
                            WHEN v_new_balance <= 0 THEN NULL
                            ELSE collection_date
                          END,
        updated_at     = now()
    WHERE id = v_invoice_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- ─── 2. CREATE TRIGGER ON invoice_payments ────────────────────────────────
DROP TRIGGER IF EXISTS trg_invoice_payments_update_invoice ON invoice_payments;
CREATE TRIGGER trg_invoice_payments_update_invoice
AFTER INSERT OR UPDATE OR DELETE ON invoice_payments
FOR EACH ROW
EXECUTE FUNCTION fn_update_invoice_from_invoice_payments();

-- ─── 3. ALIGN INVOICE STATUS TRIGGER ─────────────────────────────────────
CREATE OR REPLACE FUNCTION trg_update_invoice_status_v2()
RETURNS TRIGGER AS $$
BEGIN
    -- Don't auto-override manually set terminal statuses
    IF NEW.status IN ('cancelled', 'void', 'draft') THEN
        RETURN NEW;
    END IF;

    -- Derive status from balance/paid_amount
    IF COALESCE(NEW.balance, 0) <= 0 AND COALESCE(NEW.paid_amount, 0) > 0 THEN
        NEW.status         := 'paid';
        NEW.payment_status := 'paid';
    ELSIF COALESCE(NEW.paid_amount, 0) > 0 THEN
        NEW.status         := 'issued';
        NEW.payment_status := 'partial';
    ELSE
        -- Fresh invoice — not yet paid
        NEW.status         := 'unpaid';
        NEW.payment_status := 'unpaid';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public;

-- Allow 'partial' and 'void' in status constraint
ALTER TABLE invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_check 
CHECK (status IN ('draft', 'issued', 'unpaid', 'paid', 'partial', 'cancelled', 'void'));

-- ─── 4. MIGRATE LEGACY PAYMENTS ──────────────────────────────────────────
INSERT INTO invoice_payments (
    company_id, invoice_id, customer_id, amount, method,
    reference_no, note, paid_at, created_by, created_at
)
SELECT
    p.company_id, p.invoice_id, NULL, p.amount,
    COALESCE(UPPER(p.payment_method), 'CASH'),
    p.transaction_reference, p.notes, p.created_at, p.cashier_id, p.created_at
FROM payments p
WHERE p.invoice_id IS NOT NULL
  AND NOT COALESCE(p.voided, false)
  AND NOT EXISTS (
    SELECT 1 FROM invoice_payments ip 
    WHERE ip.invoice_id = p.invoice_id 
      AND ip.amount = p.amount 
      AND ip.created_at = p.created_at
  );

-- ─── 5. RE-SYNC ALL INVOICE BALANCES ─────────────────────────────────────
UPDATE invoices inv
SET
    paid_amount = sub.total_paid,
    balance     = GREATEST(inv.total - sub.total_paid, 0),
    payment_status = CASE
        WHEN sub.total_paid >= inv.total AND sub.total_paid > 0 THEN 'paid'
        WHEN sub.total_paid > 0 THEN 'partial'
        ELSE 'unpaid'
    END,
    status = CASE
        WHEN inv.status IN ('cancelled', 'draft') THEN inv.status
        WHEN sub.total_paid >= inv.total AND sub.total_paid > 0 THEN 'paid'
        WHEN sub.total_paid > 0 THEN 'issued'
        ELSE 'unpaid'
    END,
    updated_at = now()
FROM (
    SELECT 
        i.id as invoice_id,
        COALESCE(ip_sum.total_paid, 0) as total_paid
    FROM invoices i
    LEFT JOIN (
        SELECT invoice_id, SUM(amount) as total_paid
        FROM invoice_payments
        GROUP BY invoice_id
    ) ip_sum ON ip_sum.invoice_id = i.id
    WHERE i.status NOT IN ('cancelled', 'draft')
) sub
WHERE inv.id = sub.invoice_id
  AND inv.status NOT IN ('cancelled', 'draft');

NOTIFY pgrst, 'reload schema';

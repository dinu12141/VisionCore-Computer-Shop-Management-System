-- ============================================================================
-- SCHEMA ALIGNMENT: Add missing columns to invoices and customers tables
-- Date: 2026-03-12
-- ============================================================================

-- ─── 1. CUSTOMERS TABLE ─────────────────────────────────────────────────────
ALTER TABLE customers ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS name TEXT GENERATED ALWAYS AS (full_name) STORED;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS customer_code TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive'));
ALTER TABLE customers ADD COLUMN IF NOT EXISTS category_id UUID;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS nic_brn TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS notes TEXT;

-- ─── 2. INVOICES TABLE ──────────────────────────────────────────────────────
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS customer_snapshot JSONB DEFAULT '{}'::jsonb;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'cash';
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS customer_po_no TEXT;

-- Computer Shop ERP does not use order routing. We must drop the RESTAURANT POS constraints if they exist.
DO $$ 
BEGIN
  -- Drop constraint if exists
  ALTER TABLE invoices DROP CONSTRAINT IF EXISTS invoices_order_id_fkey;
  
  -- Conditionally drop NOT NULL if columns exist
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='invoices' AND column_name='order_id') THEN
    ALTER TABLE invoices ALTER COLUMN order_id DROP NOT NULL;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='invoices' AND column_name='branch_id') THEN
    ALTER TABLE invoices ALTER COLUMN branch_id DROP NOT NULL;
  END IF;
END $$;

-- ─── 3. CREATE invoice_payments TABLE ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS invoice_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    method TEXT NOT NULL DEFAULT 'CASH',
    reference_no TEXT,
    note TEXT,
    paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_invoice_payments_invoice ON invoice_payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_payments_company ON invoice_payments(company_id);
ALTER TABLE invoice_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS invoice_payments_select ON invoice_payments;
CREATE POLICY invoice_payments_select ON invoice_payments FOR SELECT
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS invoice_payments_insert ON invoice_payments;
CREATE POLICY invoice_payments_insert ON invoice_payments FOR INSERT
    WITH CHECK (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS invoice_payments_update ON invoice_payments;
CREATE POLICY invoice_payments_update ON invoice_payments FOR UPDATE
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS invoice_payments_delete ON invoice_payments;
CREATE POLICY invoice_payments_delete ON invoice_payments FOR DELETE
    USING (company_id IN (SELECT fn_user_company_ids()));

NOTIFY pgrst, 'reload schema';

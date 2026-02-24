-- ============================================================================
-- ERP MODULE: CUSTOMERS & BILLING (PROFESSIONAL MULTI-TENANT ARCHITECTURE)
-- ============================================================================

-- Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. CUSTOMER CATEGORIES
CREATE TABLE IF NOT EXISTS customer_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, name)
);

-- 2. CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    category_id UUID REFERENCES customer_categories(id) ON DELETE SET NULL,
    customer_code TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    nic_brn TEXT,
    notes TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, customer_code)
);

-- Search Indexes for Customers
CREATE INDEX idx_customers_search ON customers USING gin (
    to_tsvector('english', name || ' ' || coalesce(phone, '') || ' ' || customer_code)
);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_lookup ON customers(company_id, customer_code);

-- 3. INVOICES
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    invoice_no TEXT NOT NULL,
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    customer_snapshot JSONB NOT NULL, -- Immutable record of customer data at billing time
    payment_type TEXT NOT NULL CHECK (payment_type IN ('cash', 'card', 'credit', 'other')),
    subtotal NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    discount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    tax NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
    total NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    paid_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
    balance NUMERIC(14,2) NOT NULL DEFAULT 0, -- Can be negative if overpaid
    status TEXT NOT NULL DEFAULT 'issued' CHECK (status IN ('draft', 'issued', 'cancelled')),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, invoice_no)
);

CREATE INDEX idx_invoices_no ON invoices(company_id, invoice_no);
CREATE INDEX idx_invoices_date ON invoices(invoice_date);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);

-- 4. INVOICE ITEMS
CREATE TABLE IF NOT EXISTS invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    product_id UUID, -- Optional link to stock items
    description TEXT NOT NULL,
    qty NUMERIC(14,3) NOT NULL DEFAULT 1 CHECK (qty > 0),
    unit_price NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    discount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    line_total NUMERIC(14,2) NOT NULL CHECK (line_total >= 0),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 5. CONCURRENCY-SAFE CODE GENERATION (Table-based Counters)
-- ============================================================================

CREATE TABLE IF NOT EXISTS company_counters (
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    counter_type TEXT NOT NULL, -- 'customer', 'invoice'
    last_value INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (company_id, counter_type)
);

CREATE OR REPLACE FUNCTION get_next_counter_value(p_company_id UUID, p_type TEXT)
RETURNS INTEGER AS $$
DECLARE
    new_val INTEGER;
BEGIN
    INSERT INTO company_counters (company_id, counter_type, last_value)
    VALUES (p_company_id, p_type, 1)
    ON CONFLICT (company_id, counter_type)
    DO UPDATE SET last_value = company_counters.last_value + 1
    RETURNING last_value INTO new_val;
    
    RETURN new_val;
END;
$$ LANGUAGE plpgsql;

-- Trigger functions to auto-assign codes
CREATE OR REPLACE FUNCTION trg_assign_customer_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.customer_code IS NULL THEN
        NEW.customer_code := 'CUS-' || LPAD(get_next_counter_value(NEW.company_id, 'customer')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_assign_invoice_no()
RETURNS TRIGGER AS $$
DECLARE
    year_prefix TEXT;
BEGIN
    year_prefix := to_char(now(), 'YYYY');
    IF NEW.invoice_no IS NULL THEN
        NEW.invoice_no := 'INV-' || year_prefix || '-' || LPAD(get_next_counter_value(NEW.company_id, 'invoice')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_customer_code BEFORE INSERT ON customers FOR EACH ROW EXECUTE FUNCTION trg_assign_customer_code();
CREATE TRIGGER trg_set_invoice_no BEFORE INSERT ON invoices FOR EACH ROW EXECUTE FUNCTION trg_assign_invoice_no();

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE customer_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_counters ENABLE ROW LEVEL SECURITY;

-- Helper function for company_id from JWT (assumes company_id is in app_metadata or user_metadata)
CREATE OR REPLACE FUNCTION auth.company_id() RETURNS UUID AS $$
    SELECT (auth.jwt() -> 'user_metadata' ->> 'company_id')::UUID;
$$ LANGUAGE sql STABLE;

-- Generic Policy Template: Access own company only
CREATE POLICY "Company Access" ON customer_categories FOR ALL TO authenticated USING (company_id = auth.company_id());
CREATE POLICY "Company Access" ON customers FOR ALL TO authenticated USING (company_id = auth.company_id());
CREATE POLICY "Company Access" ON invoices FOR ALL TO authenticated USING (company_id = auth.company_id());
CREATE POLICY "Company Access" ON company_counters FOR ALL TO authenticated USING (company_id = auth.company_id());

-- Invoice Items are accessed via parent invoice check
CREATE POLICY "Invoice Item Access" ON invoice_items FOR ALL TO authenticated 
USING (invoice_id IN (SELECT id FROM invoices WHERE company_id = auth.company_id()));

-- ============================================================================
-- 7. KEY ARCHITECTURAL DECISIONS
-- ============================================================================
-- 1. Table-based Counters: Used instead of sequences to provide per-company sequential 
--    numbering (Sequences in PG are global/serial). Handles concurrency via 'UPDATE ... RETURNING'.
-- 2. Customer Snapshot: Stores a static copy of customer details inside the invoice. 
--    Ensures that if a customer changes their phone/address later, the original invoice 
--    remains legally accurate to the time of sale.
-- 3. Strict Constraints: Added CHECK constraints on qty and prices at the DB level to 
--    prevent invalid data (e.g. negative prices) even if frontend validation is bypassed.
-- 4. GIN Index: Optimized for partial text matching (FTS) across multiple customer fields.

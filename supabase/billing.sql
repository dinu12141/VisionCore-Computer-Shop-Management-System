-- =====================================================
-- POS BILLING SCHEMA
-- =====================================================

-- =====================================================
-- 1. UTILITIES
-- =====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. PAYMENT METHODS
-- =====================================================

CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE, -- Cash, Card, Online, etc.
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed default payment methods
INSERT INTO payment_methods (name, description) VALUES
('Cash', 'Cash payment'),
('Card', 'Credit/Debit Card'),
('Online', 'Online Payment (UberEats, PickMe, etc.)'),
('Transfer', 'Bank Transfer')
ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- 2. INVOICES
-- =====================================================

CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    invoice_number SERIAL, -- Consider a more complex generation strategy if needed per-branch
    customer_name TEXT,
    customer_phone TEXT,
    
    subtotal NUMERIC(12,2) DEFAULT 0,
    tax_total NUMERIC(12,2) DEFAULT 0,
    discount_total NUMERIC(12,2) DEFAULT 0,
    grand_total NUMERIC(12,2) DEFAULT 0,
    
    payment_status TEXT NOT NULL DEFAULT 'unpaid',
    status TEXT NOT NULL DEFAULT 'issued', -- issued, voided, paid
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT chk_invoice_payment_status CHECK (
        payment_status IN ('unpaid', 'partial', 'paid', 'refunded')
    ),
    CONSTRAINT chk_invoice_status CHECK (
        status IN ('issued', 'voided', 'paid')
    )
);

CREATE INDEX idx_invoices_order ON invoices(order_id);
CREATE INDEX idx_invoices_branch ON invoices(branch_id);
CREATE INDEX idx_invoices_created ON invoices(created_at DESC);

CREATE TRIGGER trg_invoices_updated
BEFORE UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 3. INVOICE ITEMS (Snapshot of Order Items)
-- =====================================================

CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL, -- Link back to original item if needed
    menu_item_name TEXT NOT NULL, -- Snapshot name
    quantity INT NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_price NUMERIC(12,2) NOT NULL,
    tax_amount NUMERIC(12,2) DEFAULT 0,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);

-- =====================================================
-- 4. PAYMENTS
-- =====================================================

DROP TABLE IF EXISTS payments CASCADE;
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    payment_method_id UUID NOT NULL REFERENCES payment_methods(id),
    amount NUMERIC(12,2) NOT NULL,
    transaction_ref TEXT, -- For card/online IDs
    status TEXT NOT NULL DEFAULT 'completed',
    received_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT chk_payment_status CHECK (
        status IN ('pending', 'completed', 'failed', 'refunded')
    )
);

CREATE INDEX idx_payments_invoice ON payments(invoice_id);
CREATE INDEX idx_payments_method ON payments(payment_method_id);

-- =====================================================
-- 5. VOID TRANSACTIONS
-- =====================================================

CREATE TABLE void_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type TEXT NOT NULL, -- 'invoice' or 'payment'
    entity_id UUID NOT NULL,   -- ID of invoice or payment
    reason TEXT NOT NULL,
    voided_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    manager_approval_by UUID REFERENCES profiles(id) ON DELETE SET NULL, -- Optional, if approval required
    voided_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT chk_void_entity_type CHECK (
        entity_type IN ('invoice', 'payment')
    )
);

CREATE INDEX idx_void_entity ON void_transactions(entity_id);

-- =====================================================
-- LOGGING / TRIGGERS
-- =====================================================

-- Trigger to update Order payment status when Invoice is fully paid is distinct logic usually handled by application or
-- complex triggers. For now, we assume application layer handles status updates between Invoice -> Order.

-- Realtime subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE payments;

-- =====================================================
-- INVENTORY SYSTEM SCHEMA (DESIGN)
-- =====================================================

-- 1. SUPPLIERS
-- =====================================================

CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_suppliers_company ON suppliers(company_id);

-- 2. STOCK ITEMS (Inventory Master)
-- Replaces/Enhances 'ingredients' concept with more detail
-- =====================================================

CREATE TABLE stock_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sku TEXT UNIQUE,
    description TEXT,
    category TEXT, -- e.g., 'Vegetables', 'Meat', 'Packaging', 'Cleaning'
    unit TEXT NOT NULL, -- kg, ltr, pcs, pack
    cost_price NUMERIC(10,2) DEFAULT 0, -- Current average cost
    reorder_level NUMERIC(10,4) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_stock_items_company ON stock_items(company_id);

-- 3. STORES (Storage Locations)
-- Redefining stores table if needed, ensuring correct fields
-- =====================================================

-- Note: If 'stores' already exists from schema.sql, this might need ALTER or IF NOT EXISTS
-- Assuming we are defining the full inventory module here.

DROP TABLE IF EXISTS stores CASCADE;
CREATE TABLE IF NOT EXISTS stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- 'Main Store', 'Kitchen Store', 'Bar Store'
    type TEXT, -- 'main', 'kitchen', 'bar'
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_stores_branch ON stores(branch_id);

-- 4. STOCK LEVELS (Current Stock)
-- Tracks quantity per item per store. FIFO/Batch tracking supported via batch_no
-- =====================================================

DROP TABLE IF EXISTS stock_levels CASCADE;
CREATE TABLE stock_levels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
    quantity NUMERIC(10,4) DEFAULT 0,
    batch_no TEXT, -- Optional: for tracking specific batches
    expiry_date DATE, -- Optional: for perishable goods
    last_updated TIMESTAMPTZ DEFAULT now(),
    UNIQUE(store_id, stock_item_id, batch_no) -- Unique stock per batch in a store
);

CREATE INDEX idx_stock_levels_store_item ON stock_levels(store_id, stock_item_id);

-- 5. STOCK MOVEMENTS (Audit Trail)
-- Logs every single transaction: GRN, Transfer, Usage, Wastage
-- =====================================================

DROP TABLE IF EXISTS stock_movements CASCADE;
CREATE TABLE stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
    quantity NUMERIC(10,4) NOT NULL, -- Positive for IN, Negative for OUT
    movement_type TEXT NOT NULL, -- 'GRN', 'TRANSFER_IN', 'TRANSFER_OUT', 'SALES', 'WASTAGE', 'ADJUSTMENT'
    reference_id UUID, -- Links to GRN ID, Transfer ID, or Order ID
    reference_type TEXT, -- 'grn', 'transfer', 'order', 'wastage'
    batch_no TEXT,
    notes TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_movements_store_item ON stock_movements(store_id, stock_item_id);
CREATE INDEX idx_movements_date ON stock_movements(created_at);

-- 6. GRN (Goods Received Note)
-- =====================================================

CREATE TABLE grn (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES suppliers(id),
    reference_no TEXT, -- Invoice number from supplier
    received_date DATE DEFAULT CURRENT_DATE,
    total_amount NUMERIC(10,2) DEFAULT 0,
    status TEXT DEFAULT 'pending', -- 'pending', 'verified', 'cancelled'
    notes TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_grn_store ON grn(store_id);

CREATE TABLE grn_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_id UUID NOT NULL REFERENCES grn(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id),
    quantity NUMERIC(10,4) NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    total_price NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    batch_no TEXT,
    expiry_date DATE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_grn_items_grn ON grn_items(grn_id);

-- 7. STOCK TRANSFERS (Internal Movement)
-- =====================================================

CREATE TABLE stock_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_store_id UUID NOT NULL REFERENCES stores(id),
    to_store_id UUID NOT NULL REFERENCES stores(id),
    status TEXT DEFAULT 'requested', -- 'requested', 'approved', 'completed', 'rejected'
    reference_no TEXT,
    requested_by UUID REFERENCES profiles(id),
    approved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE stock_transfer_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_id UUID NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id),
    quantity_requested NUMERIC(10,4) NOT NULL,
    quantity_transferred NUMERIC(10,4), -- Set upon approval/completion
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_transfer_items_transfer ON stock_transfer_items(transfer_id);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to Process GRN (Updates Stock & Logs Movement)
CREATE OR REPLACE FUNCTION process_grn_verification()
RETURNS TRIGGER AS $$
DECLARE
    r RECORD;
BEGIN
    -- Only run when status changes to 'verified'
    IF NEW.status = 'verified' AND OLD.status != 'verified' THEN
        
        FOR r IN SELECT * FROM grn_items WHERE grn_id = NEW.id LOOP
            
            -- 1. Update or Insert Stock Level
            -- Using UPSERT logic for stock_levels
            INSERT INTO stock_levels (store_id, stock_item_id, quantity, batch_no, expiry_date)
            VALUES (NEW.store_id, r.stock_item_id, r.quantity, r.batch_no, r.expiry_date)
            ON CONFLICT (store_id, stock_item_id, batch_no)
            DO UPDATE SET
                quantity = stock_levels.quantity + EXCLUDED.quantity,
                last_updated = now();

            -- 2. Log Movement
            INSERT INTO stock_movements (
                store_id, stock_item_id, quantity, movement_type, 
                reference_id, reference_type, batch_no, created_by
            )
            VALUES (
                NEW.store_id, r.stock_item_id, r.quantity, 'GRN',
                NEW.id, 'grn', r.batch_no, NEW.created_by
            );

        END LOOP;
        
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_process_grn
AFTER UPDATE ON grn
FOR EACH ROW
EXECUTE FUNCTION process_grn_verification();

-- Function to Process Stock Transfer (Updates Stock & Logs Movement)
CREATE OR REPLACE FUNCTION process_stock_transfer()
RETURNS TRIGGER AS $$
DECLARE
    r RECORD;
BEGIN
    -- Only run when status changes to 'completed'
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        
        FOR r IN SELECT * FROM stock_transfer_items WHERE transfer_id = NEW.id LOOP
            
            -- Ensure quantity_transferred is set (default to requested if null)
            IF r.quantity_transferred IS NULL THEN
                 r.quantity_transferred := r.quantity_requested;
            END IF;

            -- 1. Deduct from Source Store
            UPDATE stock_levels 
            SET quantity = quantity - r.quantity_transferred,
                last_updated = now()
            WHERE store_id = NEW.from_store_id 
              AND stock_item_id = r.stock_item_id;
              -- Note: Managing batch deduction for transfers is complex; 
              -- simplified here to deduction from any available stock or assuming specific logic needed.
              -- For this design, we assume basic deduction. Real-world might require selecting batches.

            -- 2. Add to Destination Store
             INSERT INTO stock_levels (store_id, stock_item_id, quantity)
            VALUES (NEW.to_store_id, r.stock_item_id, r.quantity_transferred)
            ON CONFLICT (store_id, stock_item_id, batch_no) -- Assuming NULL batch for simple transfer
            DO UPDATE SET
                quantity = stock_levels.quantity + EXCLUDED.quantity,
                last_updated = now();

            -- 3. Log Movements (OUT from Source, IN to Destination)
            
            -- OUT
            INSERT INTO stock_movements (
                store_id, stock_item_id, quantity, movement_type, 
                reference_id, reference_type, created_by
            ) VALUES (
                NEW.from_store_id, r.stock_item_id, -r.quantity_transferred, 'TRANSFER_OUT',
                NEW.id, 'transfer', NEW.approved_by
            );

            -- IN
            INSERT INTO stock_movements (
                store_id, stock_item_id, quantity, movement_type, 
                reference_id, reference_type, created_by
            ) VALUES (
                NEW.to_store_id, r.stock_item_id, r.quantity_transferred, 'TRANSFER_IN',
                NEW.id, 'transfer', NEW.approved_by
            );

        END LOOP;
        
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_process_transfer
AFTER UPDATE ON stock_transfers
FOR EACH ROW
EXECUTE FUNCTION process_stock_transfer();

-- =====================================================
-- REALTIME
-- =====================================================
ALTER PUBLICATION supabase_realtime ADD TABLE stock_levels;

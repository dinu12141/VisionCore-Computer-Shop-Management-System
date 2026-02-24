-- =====================================================
-- INVENTORY MODULE — PART 1: TABLES (FINAL PRODUCTION VERSION)
-- =====================================================
-- Run order: 1) this file  2) inventory_module_functions.sql
-- Depends on: schema.sql (companies, branches, profiles, kitchens)
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 1. UNITS OF MEASURE
-- =====================================================

CREATE TABLE IF NOT EXISTS uom (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    base_uom_id UUID REFERENCES uom(id) ON DELETE SET NULL,
    conversion_factor NUMERIC(12,6) DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, code)
);

CREATE INDEX IF NOT EXISTS idx_uom_company ON uom(company_id);

CREATE TRIGGER trg_uom_updated
BEFORE UPDATE ON uom
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 2. ITEM CATEGORIES
-- =====================================================

CREATE TABLE IF NOT EXISTS item_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    parent_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, name)
);

CREATE INDEX IF NOT EXISTS idx_item_cat_company ON item_categories(company_id);

-- =====================================================
-- 3. SUPPLIERS
-- =====================================================

DROP TABLE IF EXISTS suppliers CASCADE;
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    tax_id TEXT,
    payment_terms_days INT DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, code)
);

CREATE INDEX IF NOT EXISTS idx_suppliers_company ON suppliers(company_id);

CREATE TRIGGER trg_suppliers_updated
BEFORE UPDATE ON suppliers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 4. ITEMS (Raw materials / Ingredients / Consumables)
-- =====================================================

CREATE TABLE IF NOT EXISTS items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    category_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    inventory_uom_id UUID NOT NULL REFERENCES uom(id),
    purchase_uom_id UUID REFERENCES uom(id),
    purchase_to_inventory_factor NUMERIC(12,6) DEFAULT 1,
    default_supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    avg_cost NUMERIC(14,4) DEFAULT 0,
    last_purchase_price NUMERIC(14,4) DEFAULT 0,
    reorder_level NUMERIC(14,4) DEFAULT 0,
    reorder_qty NUMERIC(14,4) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, code)
);

CREATE INDEX IF NOT EXISTS idx_items_company ON items(company_id);
CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id);
CREATE INDEX IF NOT EXISTS idx_items_supplier ON items(default_supplier_id);

CREATE TRIGGER trg_items_updated
BEFORE UPDATE ON items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 5. WAREHOUSES
-- =====================================================

DROP TABLE IF EXISTS warehouses CASCADE;
CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    kitchen_id UUID REFERENCES kitchens(id) ON DELETE SET NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    warehouse_type TEXT NOT NULL DEFAULT 'main_store',
    allow_negative_stock BOOLEAN DEFAULT false,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, code),
    CONSTRAINT chk_wh_type CHECK (
        warehouse_type IN (
            'main_store','kitchen','bar',
            'freezer','dry_store','other'
        )
    )
);

CREATE INDEX IF NOT EXISTS idx_wh_company ON warehouses(company_id);
CREATE INDEX IF NOT EXISTS idx_wh_branch ON warehouses(branch_id);
CREATE INDEX IF NOT EXISTS idx_wh_kitchen ON warehouses(kitchen_id);
CREATE INDEX IF NOT EXISTS idx_wh_type ON warehouses(warehouse_type);

CREATE TRIGGER trg_warehouses_updated
BEFORE UPDATE ON warehouses
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 6. ITEM–WAREHOUSE SETTINGS
-- =====================================================

CREATE TABLE IF NOT EXISTS item_warehouse_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    min_stock NUMERIC(14,4) DEFAULT 0,
    max_stock NUMERIC(14,4) DEFAULT 0,
    reorder_level NUMERIC(14,4) DEFAULT 0,
    reorder_qty NUMERIC(14,4) DEFAULT 0,
    bin_location TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(item_id, warehouse_id)
);

CREATE INDEX IF NOT EXISTS idx_iws_item ON item_warehouse_settings(item_id);
CREATE INDEX IF NOT EXISTS idx_iws_warehouse ON item_warehouse_settings(warehouse_id);

CREATE TRIGGER trg_iws_updated
BEFORE UPDATE ON item_warehouse_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 7. INVENTORY DOCUMENTS (Header)
-- =====================================================
-- doc_type: GRN, GIN, TRANSFER, ADJUSTMENT, STOCK_COUNT
-- status:   draft → posted → cancelled
-- posted docs are immutable; corrections via cancellation doc

CREATE TABLE IF NOT EXISTS inventory_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    doc_type TEXT NOT NULL,
    doc_number TEXT NOT NULL,
    doc_date DATE NOT NULL DEFAULT CURRENT_DATE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    target_warehouse_id UUID REFERENCES warehouses(id),
    supplier_id UUID REFERENCES suppliers(id),
    reference_id UUID,
    reference_type TEXT,
    status TEXT NOT NULL DEFAULT 'draft',
    remarks TEXT,
    total_qty NUMERIC(14,4) DEFAULT 0,
    total_cost NUMERIC(14,2) DEFAULT 0,
    posted_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancels_document_id UUID REFERENCES inventory_documents(id),
    created_by UUID REFERENCES profiles(id),
    approved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT chk_inv_doc_type CHECK (
        doc_type IN (
            'GRN','GIN','TRANSFER',
            'ADJUSTMENT','STOCK_COUNT',
            'BOM_DEDUCT','OPENING'
        )
    ),
    CONSTRAINT chk_inv_doc_status CHECK (
        status IN ('draft','posted','cancelled')
    ),
    CONSTRAINT chk_transfer_target CHECK (
        (doc_type = 'TRANSFER' AND target_warehouse_id IS NOT NULL)
        OR doc_type != 'TRANSFER'
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_doc_company ON inventory_documents(company_id);
CREATE INDEX IF NOT EXISTS idx_inv_doc_branch ON inventory_documents(branch_id);
CREATE INDEX IF NOT EXISTS idx_inv_doc_type ON inventory_documents(doc_type);
CREATE INDEX IF NOT EXISTS idx_inv_doc_status ON inventory_documents(status);
CREATE INDEX IF NOT EXISTS idx_inv_doc_wh ON inventory_documents(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_inv_doc_date ON inventory_documents(doc_date DESC);
CREATE INDEX IF NOT EXISTS idx_inv_doc_ref ON inventory_documents(reference_id);
CREATE INDEX IF NOT EXISTS idx_inv_doc_number ON inventory_documents(doc_number);
CREATE INDEX IF NOT EXISTS idx_inv_doc_cancels ON inventory_documents(cancels_document_id);

CREATE TRIGGER trg_inv_doc_updated
BEFORE UPDATE ON inventory_documents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 8. INVENTORY DOCUMENT LINES
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_document_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES inventory_documents(id) ON DELETE CASCADE,
    line_number INT NOT NULL DEFAULT 1,
    item_id UUID NOT NULL REFERENCES items(id),
    uom_id UUID NOT NULL REFERENCES uom(id),
    quantity NUMERIC(14,4) NOT NULL,
    unit_cost NUMERIC(14,4) DEFAULT 0,
    line_total NUMERIC(14,4) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    batch_no TEXT,
    expiry_date DATE,
    system_qty NUMERIC(14,4),
    counted_qty NUMERIC(14,4),
    variance_qty NUMERIC(14,4),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(document_id, line_number)
);

CREATE INDEX IF NOT EXISTS idx_inv_line_doc ON inventory_document_lines(document_id);
CREATE INDEX IF NOT EXISTS idx_inv_line_item ON inventory_document_lines(item_id);

-- =====================================================
-- 9. INVENTORY LEDGER (Immutable — single source of truth)
-- =====================================================
-- NEVER update or delete rows. Stock = SUM(signed qty).
-- direction IN  → positive quantity
-- direction OUT → quantity stored positive, sign applied by queries

CREATE TABLE IF NOT EXISTS inventory_ledger (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id),
    branch_id UUID NOT NULL REFERENCES branches(id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    item_id UUID NOT NULL REFERENCES items(id),
    document_id UUID NOT NULL REFERENCES inventory_documents(id),
    doc_type TEXT NOT NULL,
    doc_number TEXT NOT NULL,
    direction TEXT NOT NULL,
    quantity NUMERIC(14,4) NOT NULL CHECK (quantity >= 0),
    unit_cost NUMERIC(14,4) DEFAULT 0,
    total_cost NUMERIC(14,4) DEFAULT 0,
    batch_no TEXT,
    expiry_date DATE,
    reference_id UUID,
    reference_type TEXT,
    posted_by UUID REFERENCES profiles(id),
    posted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_ledger_dir CHECK (direction IN ('IN','OUT'))
);

CREATE INDEX IF NOT EXISTS idx_ledger_company ON inventory_ledger(company_id);
CREATE INDEX IF NOT EXISTS idx_ledger_wh ON inventory_ledger(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_ledger_item ON inventory_ledger(item_id);
CREATE INDEX IF NOT EXISTS idx_ledger_doc ON inventory_ledger(document_id);
CREATE INDEX IF NOT EXISTS idx_ledger_wh_item ON inventory_ledger(warehouse_id, item_id);
CREATE INDEX IF NOT EXISTS idx_ledger_posted ON inventory_ledger(posted_at DESC);
CREATE INDEX IF NOT EXISTS idx_ledger_doc_type ON inventory_ledger(doc_type);

-- =====================================================
-- 10. STOCK ON HAND (Cached — updated by trigger)
-- =====================================================

CREATE TABLE IF NOT EXISTS stock_on_hand (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    item_id UUID NOT NULL REFERENCES items(id),
    qty_on_hand NUMERIC(14,4) NOT NULL DEFAULT 0,
    total_value NUMERIC(14,4) NOT NULL DEFAULT 0,
    last_movement_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(warehouse_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_soh_company ON stock_on_hand(company_id);
CREATE INDEX IF NOT EXISTS idx_soh_wh ON stock_on_hand(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_soh_item ON stock_on_hand(item_id);
CREATE INDEX IF NOT EXISTS idx_soh_wh_item ON stock_on_hand(warehouse_id, item_id);

-- =====================================================
-- 11. RECIPES / BOM
-- =====================================================

DROP TABLE IF EXISTS recipes CASCADE;
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES item_variants(id) ON DELETE CASCADE,
    name TEXT,
    yield_qty NUMERIC(10,4) NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(menu_item_id, variant_id)
);

CREATE INDEX IF NOT EXISTS idx_recipes_menu ON recipes(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_recipes_variant ON recipes(variant_id);
CREATE INDEX IF NOT EXISTS idx_recipes_company ON recipes(company_id);

CREATE TRIGGER trg_recipes_updated
BEFORE UPDATE ON recipes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 12. RECIPE ITEMS (BOM Lines)
-- =====================================================

DROP TABLE IF EXISTS recipe_items CASCADE;
CREATE TABLE recipe_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    qty_per_serving NUMERIC(14,4) NOT NULL,
    uom_id UUID NOT NULL REFERENCES uom(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(recipe_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_ri_recipe ON recipe_items(recipe_id);
CREATE INDEX IF NOT EXISTS idx_ri_item ON recipe_items(item_id);

-- =====================================================
-- 13. DOCUMENT NUMBER SEQUENCES
-- =====================================================

CREATE TABLE IF NOT EXISTS inv_doc_sequences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    doc_type TEXT NOT NULL,
    prefix TEXT NOT NULL,
    current_number INT NOT NULL DEFAULT 0,
    fiscal_year INT NOT NULL DEFAULT EXTRACT(YEAR FROM now()),
    UNIQUE(company_id, doc_type, fiscal_year)
);

-- =====================================================
-- SEED: Default UOMs
-- =====================================================

DO $$
DECLARE v_cid UUID;
BEGIN
    FOR v_cid IN SELECT id FROM companies LOOP
        INSERT INTO uom (company_id, code, name) VALUES
            (v_cid, 'KG',   'Kilogram'),
            (v_cid, 'G',    'Gram'),
            (v_cid, 'L',    'Litre'),
            (v_cid, 'ML',   'Millilitre'),
            (v_cid, 'PCS',  'Pieces'),
            (v_cid, 'PKT',  'Packet'),
            (v_cid, 'BTL',  'Bottle'),
            (v_cid, 'BOX',  'Box'),
            (v_cid, 'DOZEN','Dozen'),
            (v_cid, 'BUNCH','Bunch')
        ON CONFLICT (company_id, code) DO NOTHING;
    END LOOP;
END $$;

-- =====================================================
-- SEED: Default Warehouses (1 main + 6 kitchen per branch)
-- =====================================================

DO $$
DECLARE
    v_br RECORD;
BEGIN
    FOR v_br IN SELECT id, company_id FROM branches WHERE is_active = true LOOP
        INSERT INTO warehouses (company_id, branch_id, code, name, warehouse_type, is_default) VALUES
            (v_br.company_id, v_br.id, 'MAIN-' || LEFT(v_br.id::TEXT,4), 'Main Store',           'main_store', true),
            (v_br.company_id, v_br.id, 'KIT1-' || LEFT(v_br.id::TEXT,4), 'Hot Kitchen',           'kitchen',    false),
            (v_br.company_id, v_br.id, 'KIT2-' || LEFT(v_br.id::TEXT,4), 'Cold Kitchen',          'kitchen',    false),
            (v_br.company_id, v_br.id, 'KIT3-' || LEFT(v_br.id::TEXT,4), 'Bakery',                'kitchen',    false),
            (v_br.company_id, v_br.id, 'KIT4-' || LEFT(v_br.id::TEXT,4), 'Grill Station',         'kitchen',    false),
            (v_br.company_id, v_br.id, 'KIT5-' || LEFT(v_br.id::TEXT,4), 'Prep Kitchen',          'kitchen',    false),
            (v_br.company_id, v_br.id, 'BAR-'  || LEFT(v_br.id::TEXT,4), 'Bar Store',             'bar',        false)
        ON CONFLICT (company_id, code) DO NOTHING;
    END LOOP;
END $$;

-- =====================================================
-- REALTIME
-- =====================================================

DO $$
BEGIN
    ALTER TABLE warehouses       REPLICA IDENTITY FULL;
    ALTER TABLE items            REPLICA IDENTITY FULL;
    ALTER TABLE inventory_documents REPLICA IDENTITY FULL;
    ALTER TABLE stock_on_hand    REPLICA IDENTITY FULL;
    ALTER TABLE inventory_ledger REPLICA IDENTITY FULL;

    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='warehouses') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE warehouses;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='items') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE items;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='inventory_documents') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE inventory_documents;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='stock_on_hand') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE stock_on_hand;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='inventory_ledger') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE inventory_ledger;
    END IF;
END $$;

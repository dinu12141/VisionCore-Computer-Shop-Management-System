-- =====================================================
-- SYSTEM MODULES — CONFIGURATION-DRIVEN MODULE SYSTEM (FINAL PRODUCTION VERSION)
-- =====================================================
-- Depends on: schema.sql (companies)
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
-- 1. SYSTEM MODULES (Feature toggles)
-- =====================================================

CREATE TABLE IF NOT EXISTS system_modules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    icon TEXT DEFAULT 'settings',
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, code)
);

CREATE INDEX IF NOT EXISTS idx_sys_mod_company ON system_modules(company_id);
CREATE INDEX IF NOT EXISTS idx_sys_mod_code ON system_modules(company_id, code);

CREATE TRIGGER trg_system_modules_updated
BEFORE UPDATE ON system_modules
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 2. MODULE SETTINGS (Key/value config per module)
-- =====================================================

CREATE TABLE IF NOT EXISTS module_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    module_code TEXT NOT NULL,
    setting_key TEXT NOT NULL,
    setting_value JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, module_code, setting_key)
);

CREATE INDEX IF NOT EXISTS idx_mod_settings_lookup
    ON module_settings(company_id, module_code);

CREATE TRIGGER trg_module_settings_updated
BEFORE UPDATE ON module_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 3. WORKFLOWS (Future-proof configurable rules)
-- =====================================================

CREATE TABLE IF NOT EXISTS workflows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    rules JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, code)
);

CREATE INDEX IF NOT EXISTS idx_workflows_company ON workflows(company_id);

CREATE TRIGGER trg_workflows_updated
BEFORE UPDATE ON workflows
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================
-- 4. HELPER FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION is_module_enabled(
    p_company_id UUID,
    p_module_code TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_enabled BOOLEAN;
BEGIN
    SELECT is_enabled INTO v_enabled
    FROM system_modules
    WHERE company_id = p_company_id
      AND code = p_module_code;

    -- If module not configured, treat as enabled (permissive default)
    IF NOT FOUND THEN
        RETURN true;
    END IF;

    RETURN v_enabled;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


CREATE OR REPLACE FUNCTION get_module_setting(
    p_company_id UUID,
    p_module_code TEXT,
    p_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_val JSONB;
BEGIN
    SELECT setting_value INTO v_val
    FROM module_settings
    WHERE company_id = p_company_id
      AND module_code = p_module_code
      AND setting_key = p_key;

    RETURN v_val; -- NULL if not found
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =====================================================
-- 5. SEED DATA — Default modules for all companies
-- =====================================================

DO $$
DECLARE
    v_cid UUID;
BEGIN
    FOR v_cid IN SELECT id FROM companies LOOP

        INSERT INTO system_modules (company_id, code, name, description, is_enabled, icon, sort_order)
        VALUES
            (v_cid, 'GRN',             'Goods Received Note',     'Enable receiving stock into warehouses',           true,  'archive',           1),
            (v_cid, 'GIN',             'Goods Issue Note',        'Enable issuing stock from warehouses',             true,  'unarchive',         2),
            (v_cid, 'TRANSFER',        'Stock Transfer',          'Enable inter-warehouse stock transfers',           true,  'swap_horiz',        3),
            (v_cid, 'AUTO_DEDUCT',     'Auto Stock Deduction',    'Automatically deduct ingredients when orders are paid', true, 'auto_fix_high', 4),
            (v_cid, 'NEGATIVE_STOCK',  'Allow Negative Stock',    'Allow stock to go below zero in warehouses',      false, 'remove_circle',     5),
            (v_cid, 'BATCH_TRACKING',  'Batch & Expiry Tracking', 'Track batch numbers and expiry dates on stock',   false, 'event_note',        6),
            (v_cid, 'FINANCE',         'Finance Module',          'Track income, expenses, and accounts.',           true,  'account_balance',   7),
            (v_cid, 'HR',              'HR & Payroll Module',     'Manage employees, attendance, and payroll.',      true,  'people',            8)
        ON CONFLICT (company_id, code) DO NOTHING;

        -- Default settings for AUTO_DEDUCT
        INSERT INTO module_settings (company_id, module_code, setting_key, setting_value)
        VALUES
            (v_cid, 'AUTO_DEDUCT', 'deduct_on_status', '"paid"'::jsonb),
            (v_cid, 'AUTO_DEDUCT', 'create_doc_type',  '"BOM_DEDUCT"'::jsonb)
        ON CONFLICT (company_id, module_code, setting_key) DO NOTHING;

    END LOOP;
END $$;

-- =====================================================
-- 6. ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE system_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE module_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS system_modules_company_policy ON system_modules;
CREATE POLICY system_modules_company_policy ON system_modules
    FOR ALL USING (
        company_id IN (
            SELECT b.company_id FROM user_branches ub
            JOIN branches b ON b.id = ub.branch_id
            WHERE ub.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS module_settings_company_policy ON module_settings;
CREATE POLICY module_settings_company_policy ON module_settings
    FOR ALL USING (
        company_id IN (
            SELECT b.company_id FROM user_branches ub
            JOIN branches b ON b.id = ub.branch_id
            WHERE ub.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS workflows_company_policy ON workflows;
CREATE POLICY workflows_company_policy ON workflows
    FOR ALL USING (
        company_id IN (
            SELECT b.company_id FROM user_branches ub
            JOIN branches b ON b.id = ub.branch_id
            WHERE ub.user_id = auth.uid()
        )
    );

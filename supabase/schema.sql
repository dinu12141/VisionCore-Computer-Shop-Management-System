-- =====================================================
-- EXTENSIONS
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. COMPANIES
-- =====================================================

DROP TABLE IF EXISTS companies CASCADE;
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- 2. BRANCHES
-- =====================================================

DROP TABLE IF EXISTS branches CASCADE;
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    is_main BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_branches_company_id ON branches(company_id);

-- =====================================================
-- 3. PROFILES & RBAC
-- =====================================================

DROP TABLE IF EXISTS profiles CASCADE;
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

DROP TABLE IF EXISTS roles CASCADE;
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL, -- admin, manager, hr, inventory, finance
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

DROP TABLE IF EXISTS permissions CASCADE;
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

DROP TABLE IF EXISTS role_permissions CASCADE;
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(role_id, permission_id)
);

DROP TABLE IF EXISTS user_roles CASCADE;
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, role_id)
);

DROP TABLE IF EXISTS user_branches CASCADE;
CREATE TABLE user_branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    is_home_branch BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, branch_id)
);

-- Insert Default Roles
INSERT INTO roles (name, description) VALUES
('admin', 'System Administrator with full access'),
('manager', 'Branch Manager'),
('inventory', 'Inventory Manager'),
('finance', 'Finance Manager')
ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- 4. ITEMS & INVENTORY
-- =====================================================

DROP TABLE IF EXISTS items CASCADE;
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category TEXT,
    unit TEXT NOT NULL,
    cost_per_unit NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

DROP TABLE IF EXISTS stores CASCADE;
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT, -- warehouse, showroom, office
    created_at TIMESTAMPTZ DEFAULT now()
);

DROP TABLE IF EXISTS stock_levels CASCADE;
CREATE TABLE stock_levels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    quantity NUMERIC(10,4) DEFAULT 0,
    reorder_level NUMERIC(10,4) DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(store_id, item_id)
);

DROP TABLE IF EXISTS stock_movements CASCADE;
CREATE TABLE stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id),
    item_id UUID REFERENCES items(id),
    quantity NUMERIC(10,4),
    movement_type TEXT, -- in, out, transfer, adjustment
    reference_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- 5. AUDIT LOGS
-- =====================================================

DROP TABLE IF EXISTS audit_logs CASCADE;
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id),
    action TEXT,
    table_name TEXT,
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- REALTIME
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'stock_levels') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE stock_levels;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'stock_movements') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE stock_movements;
    END IF;
END $$;

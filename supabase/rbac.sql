-- =====================================================
-- RESTAURANT UNIFIED ORDER MANAGEMENT SYSTEM
-- Quasar + Supabase Architecture
-- =====================================================

-- Enable UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. ROLES & USERS
-- =====================================================

CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL
);

INSERT INTO roles (name) VALUES
('admin'),
('manager'),
('cashier'),
('kitchen'),
('delivery');

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  role_id UUID REFERENCES roles(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- 2. ORDER SOURCES
-- =====================================================

CREATE TABLE order_sources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL
);

INSERT INTO order_sources (name) VALUES
('POS'),
('WEBSITE'),
('UBER_EATS'),
('PICKME');

-- =====================================================
-- 3. MENU & CATEGORIES
-- =====================================================

CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL
);

CREATE TABLE menu_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID REFERENCES categories(id),
  name TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- 4. ORDERS
-- =====================================================

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number SERIAL,
  source_id UUID REFERENCES order_sources(id),

  customer_name TEXT,
  customer_phone TEXT,
  delivery_address TEXT,

  status TEXT DEFAULT 'pending',
  payment_status TEXT DEFAULT 'unpaid',

  subtotal NUMERIC(10,2) DEFAULT 0,
  tax NUMERIC(10,2) DEFAULT 0,
  total NUMERIC(10,2) DEFAULT 0,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- 5. ORDER ITEMS
-- =====================================================

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  menu_item_id UUID REFERENCES menu_items(id),

  quantity INTEGER NOT NULL,
  unit_price NUMERIC(10,2) NOT NULL,
  total_price NUMERIC(10,2) NOT NULL
);

-- =====================================================
-- 6. PAYMENTS
-- =====================================================

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,

  payment_method TEXT,
  amount NUMERIC(10,2),
  status TEXT DEFAULT 'completed',

  paid_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- 7. INVENTORY
-- =====================================================

CREATE TABLE inventory_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  unit TEXT,
  stock_quantity NUMERIC DEFAULT 0,
  minimum_level NUMERIC DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE inventory_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  inventory_item_id UUID REFERENCES inventory_items(id),
  change_amount NUMERIC,
  reason TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- 8. KITCHEN DISPLAY SYSTEM (KDS)
-- =====================================================

CREATE TABLE kitchen_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'waiting',
  priority INTEGER DEFAULT 1,
  started_at TIMESTAMP,
  completed_at TIMESTAMP
);

-- =====================================================
-- 9. DELIVERY TRACKING
-- =====================================================

CREATE TABLE deliveries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  driver_name TEXT,
  platform TEXT,
  delivery_status TEXT DEFAULT 'assigned',
  assigned_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);

-- =====================================================
-- 10. ORDER STATUS LOG (AUDIT)
-- =====================================================

CREATE TABLE order_status_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  status TEXT,
  changed_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- 11. AUTO UPDATE TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_orders_timestamp
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- =====================================================
-- 12. REALTIME SUPPORT (Supabase)
-- =====================================================

ALTER TABLE orders REPLICA IDENTITY FULL;
ALTER TABLE kitchen_queue REPLICA IDENTITY FULL;

-- =====================================================
-- DONE ✅
-- =====================================================

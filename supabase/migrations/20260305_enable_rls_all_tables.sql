-- ============================================================================
-- MIGRATION: Enable RLS on All Public Tables + Policies
-- Date: 2026-03-05
-- Safe version: uses IF EXISTS for every table — never fails on missing tables
-- Run in Supabase SQL Editor
-- ============================================================================

-- ── HELPER FUNCTIONS ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles ur JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = auth.uid() AND r.name = 'admin'
  );
END; $$;

CREATE OR REPLACE FUNCTION public.get_my_company_id()
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_company_id UUID;
BEGIN
  SELECT b.company_id INTO v_company_id
  FROM user_branches ub JOIN branches b ON ub.branch_id = b.id
  WHERE ub.user_id = auth.uid() LIMIT 1;
  RETURN v_company_id;
END; $$;

-- ============================================================================
-- Apply RLS safely using a helper DO block
-- Pattern: Check table exists → Enable RLS → Drop old policy → Create policy
-- ============================================================================

DO $MAIN$
DECLARE
  tbl TEXT;
BEGIN

-- ─────────────────────────────────────────────────────────────────────────────
-- SIMPLE COMPANY-SCOPED TABLES (have company_id column directly)
-- ─────────────────────────────────────────────────────────────────────────────
FOREACH tbl IN ARRAY ARRAY[
  'uom','item_categories','suppliers','items','warehouses',
  'inventory_documents','inventory_ledger','inv_doc_sequences',
  'recipes','system_modules','module_settings','workflows',
  'customer_categories','customers','invoices','company_counters',
  'service_jobs','service_issue_templates',
  'ap_invoices','supplier_payments','ap_ledger','collections',
  'audit_logs'
]
LOOP
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = tbl
  ) THEN
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);

    IF tbl = 'audit_logs' THEN
      -- audit_logs: admin only
      EXECUTE format('DROP POLICY IF EXISTS "audit_logs_admin" ON %I', tbl);
      EXECUTE format($p$
        CREATE POLICY "audit_logs_admin" ON %I FOR ALL TO authenticated
        USING (is_admin()) WITH CHECK (is_admin())
      $p$, tbl);
    ELSIF tbl = 'system_modules' THEN
      -- read-only for all, write for admin
      EXECUTE format('DROP POLICY IF EXISTS "%s_select" ON %I', tbl, tbl);
      EXECUTE format($p$
        CREATE POLICY "%s_select" ON %I FOR SELECT TO authenticated USING (true)
      $p$, tbl, tbl);
      EXECUTE format('DROP POLICY IF EXISTS "%s_admin_write" ON %I', tbl, tbl);
      EXECUTE format($p$
        CREATE POLICY "%s_admin_write" ON %I FOR ALL TO authenticated
        USING (is_admin()) WITH CHECK (is_admin())
      $p$, tbl, tbl);
    ELSE
      -- standard company-scoped
      EXECUTE format('DROP POLICY IF EXISTS "%s_company" ON %I', tbl, tbl);
      EXECUTE format($p$
        CREATE POLICY "%s_company" ON %I FOR ALL TO authenticated
        USING (company_id = get_my_company_id())
        WITH CHECK (company_id = get_my_company_id())
      $p$, tbl, tbl);
    END IF;

    RAISE NOTICE 'RLS enabled: %', tbl;
  ELSE
    RAISE NOTICE 'Skipped (not found): %', tbl;
  END IF;
END LOOP;

-- ─────────────────────────────────────────────────────────────────────────────
-- companies
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='companies') THEN
  ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "companies_select" ON companies;
  CREATE POLICY "companies_select" ON companies FOR SELECT TO authenticated
    USING (id IN (
      SELECT b.company_id FROM branches b
      JOIN user_branches ub ON ub.branch_id = b.id
      WHERE ub.user_id = auth.uid()
    ));
  DROP POLICY IF EXISTS "companies_admin_all" ON companies;
  CREATE POLICY "companies_admin_all" ON companies FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());
  RAISE NOTICE 'RLS enabled: companies';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- branches
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='branches') THEN
  ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "branches_select" ON branches;
  CREATE POLICY "branches_select" ON branches FOR SELECT TO authenticated
    USING (id IN (SELECT branch_id FROM user_branches WHERE user_id = auth.uid()) OR is_admin());
  DROP POLICY IF EXISTS "branches_admin_all" ON branches;
  CREATE POLICY "branches_admin_all" ON branches FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());
  RAISE NOTICE 'RLS enabled: branches';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='profiles') THEN
  ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "profiles_select_own"   ON profiles;
  DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
  DROP POLICY IF EXISTS "profiles_update_own"   ON profiles;
  DROP POLICY IF EXISTS "profiles_insert_self"  ON profiles;
  CREATE POLICY "profiles_select_own"  ON profiles FOR SELECT TO authenticated USING (id = auth.uid() OR is_admin());
  CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
  CREATE POLICY "profiles_insert_self" ON profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
  RAISE NOTICE 'RLS enabled: profiles';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- roles
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='roles') THEN
  ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "roles_select_all"   ON roles;
  DROP POLICY IF EXISTS "roles_admin_write"  ON roles;
  CREATE POLICY "roles_select_all"  ON roles FOR SELECT TO authenticated USING (true);
  CREATE POLICY "roles_admin_write" ON roles FOR ALL    TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  RAISE NOTICE 'RLS enabled: roles';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- user_roles
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_roles') THEN
  ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "user_roles_select_own"   ON user_roles;
  DROP POLICY IF EXISTS "user_roles_admin_write"  ON user_roles;
  CREATE POLICY "user_roles_select_own"  ON user_roles FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_admin());
  CREATE POLICY "user_roles_admin_write" ON user_roles FOR ALL    TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  RAISE NOTICE 'RLS enabled: user_roles';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- user_branches
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_branches') THEN
  ALTER TABLE user_branches ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "user_branches_select_own"  ON user_branches;
  DROP POLICY IF EXISTS "user_branches_admin_write" ON user_branches;
  CREATE POLICY "user_branches_select_own"  ON user_branches FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_admin());
  CREATE POLICY "user_branches_admin_write" ON user_branches FOR ALL    TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  RAISE NOTICE 'RLS enabled: user_branches';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- item_warehouse_settings  (joins via warehouse_id)
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='item_warehouse_settings') THEN
  ALTER TABLE item_warehouse_settings ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "item_warehouse_settings_company" ON item_warehouse_settings;
  CREATE POLICY "item_warehouse_settings_company" ON item_warehouse_settings FOR ALL TO authenticated
    USING (warehouse_id IN (SELECT id FROM warehouses WHERE company_id = get_my_company_id()))
    WITH CHECK (warehouse_id IN (SELECT id FROM warehouses WHERE company_id = get_my_company_id()));
  RAISE NOTICE 'RLS enabled: item_warehouse_settings';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- inventory_document_lines  (joins via document_id)
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='inventory_document_lines') THEN
  ALTER TABLE inventory_document_lines ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "inventory_document_lines_company" ON inventory_document_lines;
  CREATE POLICY "inventory_document_lines_company" ON inventory_document_lines FOR ALL TO authenticated
    USING (document_id IN (SELECT id FROM inventory_documents WHERE company_id = get_my_company_id()))
    WITH CHECK (document_id IN (SELECT id FROM inventory_documents WHERE company_id = get_my_company_id()));
  RAISE NOTICE 'RLS enabled: inventory_document_lines';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- stock_on_hand  (joins via warehouse_id)
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='stock_on_hand') THEN
  ALTER TABLE stock_on_hand ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "stock_on_hand_company" ON stock_on_hand;
  CREATE POLICY "stock_on_hand_company" ON stock_on_hand FOR ALL TO authenticated
    USING (warehouse_id IN (SELECT id FROM warehouses WHERE company_id = get_my_company_id()))
    WITH CHECK (warehouse_id IN (SELECT id FROM warehouses WHERE company_id = get_my_company_id()));
  RAISE NOTICE 'RLS enabled: stock_on_hand';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- recipe_items  (joins via recipe_id)
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='recipe_items') THEN
  ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "recipe_items_company" ON recipe_items;
  CREATE POLICY "recipe_items_company" ON recipe_items FOR ALL TO authenticated
    USING (recipe_id IN (SELECT id FROM recipes WHERE company_id = get_my_company_id()))
    WITH CHECK (recipe_id IN (SELECT id FROM recipes WHERE company_id = get_my_company_id()));
  RAISE NOTICE 'RLS enabled: recipe_items';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- invoice_items  (joins via invoice_id)
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='invoice_items') THEN
  ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "invoice_items_company" ON invoice_items;
  CREATE POLICY "invoice_items_company" ON invoice_items FOR ALL TO authenticated
    USING (invoice_id IN (SELECT id FROM invoices WHERE company_id = get_my_company_id()))
    WITH CHECK (invoice_id IN (SELECT id FROM invoices WHERE company_id = get_my_company_id()));
  RAISE NOTICE 'RLS enabled: invoice_items';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- service child tables  (joins via job_id)
-- ─────────────────────────────────────────────────────────────────────────────
FOREACH tbl IN ARRAY ARRAY[
  'service_diagnosis_items','service_parts_used',
  'service_activity_log','service_reports'
]
LOOP
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=tbl) THEN
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "%s_company" ON %I', tbl, tbl);
    EXECUTE format($p$
      CREATE POLICY "%s_company" ON %I FOR ALL TO authenticated
      USING (job_id IN (SELECT id FROM service_jobs WHERE company_id = get_my_company_id()))
      WITH CHECK (job_id IN (SELECT id FROM service_jobs WHERE company_id = get_my_company_id()))
    $p$, tbl, tbl);
    RAISE NOTICE 'RLS enabled: %', tbl;
  END IF;
END LOOP;

-- ─────────────────────────────────────────────────────────────────────────────
-- notifications  (joins via user_id)
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='notifications') THEN
  ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "notifications_own" ON notifications;
  CREATE POLICY "notifications_own" ON notifications FOR ALL TO authenticated
    USING (user_id = auth.uid() OR is_admin())
    WITH CHECK (user_id = auth.uid() OR is_admin());
  RAISE NOTICE 'RLS enabled: notifications';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- user_route_access
-- ─────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_route_access') THEN
  ALTER TABLE user_route_access ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "user_route_access_own" ON user_route_access;
  CREATE POLICY "user_route_access_own" ON user_route_access FOR ALL TO authenticated
    USING (user_id = auth.uid() OR is_admin())
    WITH CHECK (is_admin());
  RAISE NOTICE 'RLS enabled: user_route_access';
END IF;

-- ─────────────────────────────────────────────────────────────────────────────
-- export_audit_log
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS export_audit_log (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_email   TEXT, user_name TEXT, report_type TEXT, report_label TEXT,
  export_format TEXT, date_from DATE, date_to DATE,
  filters      JSONB DEFAULT '{}', row_count INT DEFAULT 0,
  company_id   UUID REFERENCES companies(id) ON DELETE SET NULL,
  branch_id    UUID REFERENCES branches(id)  ON DELETE SET NULL,
  exported_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE export_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "export_audit_log_insert" ON export_audit_log;
CREATE POLICY "export_audit_log_insert" ON export_audit_log FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "export_audit_log_select" ON export_audit_log;
CREATE POLICY "export_audit_log_select" ON export_audit_log FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_admin());
RAISE NOTICE 'RLS enabled: export_audit_log';

END $MAIN$;

-- ── Final check ───────────────────────────────────────────────────────────────
SELECT
  schemaname,
  tablename,
  CASE WHEN rowsecurity THEN '✅ RLS ON' ELSE '❌ RLS OFF' END AS rls_status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

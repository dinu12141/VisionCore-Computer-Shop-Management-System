-- ============================================================================
-- MIGRATION: Fix auth_rls_initplan Performance Warnings
-- Date: 2026-03-05
-- Description: Wraps auth.uid() inside (select auth.uid()) to cache 
-- evaluations and prevents row-by-row overhead in RLS policies.
-- Also removes older conflicting duplicate policies (fixes some multiple_permissive_policies).
-- ============================================================================

DO $MAIN$
BEGIN

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. OPTIMIZE HELPER FUNCTIONS (Make STABLE and use SELECT auth.uid())
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $func$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles ur JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = (SELECT auth.uid()) AND r.name = 'admin'
  );
END; $func$;

CREATE OR REPLACE FUNCTION public.get_my_company_id()
RETURNS UUID LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $func$
DECLARE v_company_id UUID;
BEGIN
  SELECT b.company_id INTO v_company_id
  FROM user_branches ub JOIN branches b ON ub.branch_id = b.id
  WHERE ub.user_id = (SELECT auth.uid()) LIMIT 1;
  RETURN v_company_id;
END; $func$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. FIX INITPLAN WARNINGS & DUPLICATES IN OUR RECENT POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

-- PROFILES
DROP POLICY IF EXISTS "profiles_select_own"  ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
CREATE POLICY "profiles_select_own"  ON profiles FOR SELECT TO authenticated USING (id = (select auth.uid()) OR is_admin());
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE TO authenticated USING (id = (select auth.uid())) WITH CHECK (id = (select auth.uid()));
CREATE POLICY "profiles_insert_self" ON profiles FOR INSERT TO authenticated WITH CHECK (id = (select auth.uid()));

-- USER ROLES & BRANCHES
DROP POLICY IF EXISTS "user_roles_select_own"  ON user_roles;
CREATE POLICY "user_roles_select_own"  ON user_roles FOR SELECT TO authenticated USING (user_id = (select auth.uid()) OR is_admin());

DROP POLICY IF EXISTS "user_branches_select_own"  ON user_branches;
CREATE POLICY "user_branches_select_own"  ON user_branches FOR SELECT TO authenticated USING (user_id = (select auth.uid()) OR is_admin());

-- ROUTE ACCESS
DROP POLICY IF EXISTS "user_route_access_own" ON user_route_access;
DROP POLICY IF EXISTS "users_read_own_access" ON user_route_access;
DROP POLICY IF EXISTS "admins_manage_all_access" ON user_route_access;
CREATE POLICY "user_route_access_own" ON user_route_access FOR ALL TO authenticated
USING (user_id = (select auth.uid()) OR is_admin())
WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Authenticated users can read role_route_access" ON role_route_access;
CREATE POLICY "Authenticated users can read role_route_access" ON role_route_access FOR SELECT TO authenticated USING (true);

-- EXPORT AUDIT LOG (Clear old conflicting versions)
DROP POLICY IF EXISTS "export_audit_log_insert" ON export_audit_log;
DROP POLICY IF EXISTS "export_audit_log_select" ON export_audit_log;
DROP POLICY IF EXISTS "Users can insert own export logs" ON export_audit_log;
DROP POLICY IF EXISTS "Admins can view all export logs" ON export_audit_log;
CREATE POLICY "export_audit_log_insert" ON export_audit_log FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));
CREATE POLICY "export_audit_log_select" ON export_audit_log FOR SELECT TO authenticated USING (user_id = (select auth.uid()) OR is_admin());

-- NOTIFICATIONS (Clear overlaps)
DROP POLICY IF EXISTS "notif_select_own" ON notifications;
DROP POLICY IF EXISTS "notif_update_own" ON notifications;
DROP POLICY IF EXISTS "notif_delete_own" ON notifications;
DROP POLICY IF EXISTS "notifications_own" ON notifications;
DROP POLICY IF EXISTS "notifications_secure_user" ON notifications;
CREATE POLICY "notifications_secure_user" ON notifications FOR ALL TO authenticated
USING (user_id = (select auth.uid()) OR is_admin())
WITH CHECK (user_id = (select auth.uid()) OR is_admin());

-- PUSH TOKENS
DROP POLICY IF EXISTS "push_own" ON push_tokens;
CREATE POLICY "push_own" ON push_tokens FOR ALL TO authenticated
USING (user_id = (select auth.uid()))
WITH CHECK (user_id = (select auth.uid()));

-- BRANCHES & COMPANIES
DROP POLICY IF EXISTS "branches_select" ON branches;
CREATE POLICY "branches_select" ON branches FOR SELECT TO authenticated
USING (id IN (SELECT branch_id FROM user_branches WHERE user_id = (select auth.uid())) OR is_admin());

DROP POLICY IF EXISTS "companies_select" ON companies;
CREATE POLICY "companies_select" ON companies FOR SELECT TO authenticated
USING (id IN (
    SELECT b.company_id FROM branches b JOIN user_branches ub ON ub.branch_id = b.id WHERE ub.user_id = (select auth.uid())
));

-- BACKUP LOGS & SECURE INSERTS
DROP POLICY IF EXISTS "admins_read_backup_logs" ON backup_logs;
CREATE POLICY "admins_read_backup_logs" ON backup_logs FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admins_read_backup_lock" ON backup_lock;
CREATE POLICY "admins_read_backup_lock" ON backup_lock FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "kot_print_logs_secure_insert" ON kot_print_logs;
CREATE POLICY "kot_print_logs_secure_insert" ON kot_print_logs FOR INSERT TO authenticated WITH CHECK ((SELECT auth.role()) = 'authenticated');

DROP POLICY IF EXISTS "order_acceptance_secure_insert" ON order_acceptance;
CREATE POLICY "order_acceptance_secure_insert" ON order_acceptance FOR INSERT TO authenticated WITH CHECK ((SELECT auth.role()) = 'authenticated');

DROP POLICY IF EXISTS "stores_secure_insert" ON stores;
CREATE POLICY "stores_secure_insert" ON stores FOR INSERT TO authenticated WITH CHECK ((SELECT auth.role()) = 'authenticated');

END $MAIN$;

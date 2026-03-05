-- ============================================================================
-- MIGRATION: Fix multiple_permissive_policies & auth_rls_initplan Warnings
-- Date: 2026-03-05
-- Strategy:
--   1. For auth_rls_initplan: wrap auth.uid() in (SELECT auth.uid())
--   2. For multiple_permissive_policies: drop the broad *_admin FOR ALL policy
--      and add OR is_admin() to specific role policies so only ONE policy per
--      role+action exists.
-- ============================================================================

DO $main$
BEGIN

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 1: Fix auth_rls_initplan on ORDERS table
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "ord_waiter_update"                ON orders;
DROP POLICY IF EXISTS "waiter_select_orders_on_shift"    ON orders;
DROP POLICY IF EXISTS "waiter_update_orders_on_shift"    ON orders;
DROP POLICY IF EXISTS "orders_insert_policy"             ON orders;

-- Rebuild consolidated orders policies (no duplicate per action/role)
DROP POLICY IF EXISTS "ord_admin"          ON orders;
DROP POLICY IF EXISTS "ord_waiter_insert"  ON orders;
DROP POLICY IF EXISTS "ord_cashier_select" ON orders;
DROP POLICY IF EXISTS "ord_kitchen_select" ON orders;
DROP POLICY IF EXISTS "ord_waiter_select"  ON orders;
DROP POLICY IF EXISTS "ord_cashier_update" ON orders;

-- Drop the new consolidated names too (in case of re-run)
DROP POLICY IF EXISTS "orders_insert" ON orders;
DROP POLICY IF EXISTS "orders_select" ON orders;
DROP POLICY IF EXISTS "orders_update" ON orders;
DROP POLICY IF EXISTS "orders_delete" ON orders;

-- Single INSERT policy
CREATE POLICY "orders_insert" ON orders
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    OR company_id = get_my_company_id()
  );

-- Single SELECT policy
CREATE POLICY "orders_select" ON orders
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR company_id = get_my_company_id()
    OR branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
  );

-- Single UPDATE policy  
CREATE POLICY "orders_update" ON orders
  FOR UPDATE TO authenticated
  USING (
    is_admin()
    OR company_id = get_my_company_id()
    OR branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
  )
  WITH CHECK (
    is_admin()
    OR company_id = get_my_company_id()
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 2: BRANCHES  (branches_admin_all + branches_select → one policy)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "branches_admin_all" ON branches;
DROP POLICY IF EXISTS "branches_select"    ON branches;
CREATE POLICY "branches_select" ON branches
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 3: CATEGORIES  (cat_admin + cat_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "cat_admin"  ON categories;
DROP POLICY IF EXISTS "cat_select" ON categories;
CREATE POLICY "cat_select" ON categories
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR company_id = get_my_company_id()
  );
-- Also allow anon read (menu display)
DROP POLICY IF EXISTS "cat_anon_select" ON categories;
CREATE POLICY "cat_anon_select" ON categories
  FOR SELECT TO anon
  USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 4: COMPANIES  (companies_admin_all + companies_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "companies_admin_all" ON companies;
DROP POLICY IF EXISTS "companies_select"    ON companies;
CREATE POLICY "companies_select" ON companies
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR id IN (
      SELECT b.company_id FROM branches b
      JOIN user_branches ub ON ub.branch_id = b.id
      WHERE ub.user_id = (SELECT auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 5: CUSTOMER_SESSIONS  (cs_admin + cs_staff_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "cs_admin"        ON customer_sessions;
DROP POLICY IF EXISTS "cs_staff_select" ON customer_sessions;
DROP POLICY IF EXISTS "cs_select"       ON customer_sessions;
CREATE POLICY "cs_select" ON customer_sessions
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM restaurant_tables rt 
      WHERE rt.id = customer_sessions.table_id 
      AND rt.company_id = get_my_company_id()
    )
  );
DROP POLICY IF EXISTS "cs_anon_select" ON customer_sessions;
CREATE POLICY "cs_anon_select" ON customer_sessions
  FOR SELECT TO anon USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 6: ITEM_VARIANTS  (iv_admin + iv_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "iv_admin"  ON item_variants;
DROP POLICY IF EXISTS "iv_select" ON item_variants;
DROP POLICY IF EXISTS "item_variants_select" ON item_variants; -- case of generic naming
DROP POLICY IF EXISTS "iv_select" ON item_variants; -- consolidated name
CREATE POLICY "iv_select" ON item_variants
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM menu_items mi 
      WHERE mi.id = item_variants.menu_item_id 
      AND mi.company_id = get_my_company_id()
    )
  );
DROP POLICY IF EXISTS "iv_anon_select" ON item_variants;
CREATE POLICY "iv_anon_select" ON item_variants
  FOR SELECT TO anon USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 7: KITCHENS  (k_admin + k_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "k_admin"  ON kitchens;
DROP POLICY IF EXISTS "k_select" ON kitchens;
CREATE POLICY "k_select" ON kitchens
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
  );
DROP POLICY IF EXISTS "k_anon_select" ON kitchens;
CREATE POLICY "k_anon_select" ON kitchens
  FOR SELECT TO anon USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 8: KOT_ITEMS  (ki_admin + ki_waiter_insert + ki_kitchen_select + ki_waiter_select + ki_kitchen_update)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "ki_admin"          ON kot_items;
DROP POLICY IF EXISTS "ki_waiter_insert"  ON kot_items;
DROP POLICY IF EXISTS "ki_kitchen_select" ON kot_items;
DROP POLICY IF EXISTS "ki_waiter_select"  ON kot_items;
DROP POLICY IF EXISTS "ki_kitchen_update" ON kot_items;
DROP POLICY IF EXISTS "ki_insert"         ON kot_items;
DROP POLICY IF EXISTS "ki_select"         ON kot_items;
DROP POLICY IF EXISTS "ki_update"         ON kot_items;

CREATE POLICY "ki_insert" ON kot_items
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM kot_tickets kt
      JOIN orders o ON o.id = kt.order_id
      JOIN user_branches ub ON ub.branch_id = o.branch_id
      WHERE kt.id = kot_items.kot_id AND ub.user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "ki_select" ON kot_items
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM kot_tickets kt
      JOIN orders o ON o.id = kt.order_id
      JOIN user_branches ub ON ub.branch_id = o.branch_id
      WHERE kt.id = kot_items.kot_id AND ub.user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "ki_update" ON kot_items
  FOR UPDATE TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM kot_tickets kt
      JOIN orders o ON o.id = kt.order_id
      JOIN user_branches ub ON ub.branch_id = o.branch_id
      WHERE kt.id = kot_items.kot_id AND ub.user_id = (SELECT auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 9: KOT_TICKETS  (kot_admin + kot_waiter_insert + kot_kitchen_select + kot_waiter_select + kot_kitchen_update)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "kot_admin"          ON kot_tickets;
DROP POLICY IF EXISTS "kot_waiter_insert"  ON kot_tickets;
DROP POLICY IF EXISTS "kot_kitchen_select" ON kot_tickets;
DROP POLICY IF EXISTS "kot_waiter_select"  ON kot_tickets;
DROP POLICY IF EXISTS "kot_kitchen_update" ON kot_tickets;
DROP POLICY IF EXISTS "kot_insert"         ON kot_tickets;
DROP POLICY IF EXISTS "kot_select"         ON kot_tickets;
DROP POLICY IF EXISTS "kot_update"         ON kot_tickets;

CREATE POLICY "kot_insert" ON kot_tickets
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o 
      WHERE o.id = kot_tickets.order_id 
      AND o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
    )
  );

CREATE POLICY "kot_select" ON kot_tickets
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o 
      WHERE o.id = kot_tickets.order_id 
      AND o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
    )
  );

CREATE POLICY "kot_update" ON kot_tickets
  FOR UPDATE TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o 
      WHERE o.id = kot_tickets.order_id 
      AND o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 10: MENU_ITEMS  (mi_admin + mi_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "mi_admin"  ON menu_items;
DROP POLICY IF EXISTS "mi_select" ON menu_items;
CREATE POLICY "mi_select" ON menu_items
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR company_id = get_my_company_id()
  );
DROP POLICY IF EXISTS "mi_anon_select" ON menu_items;
CREATE POLICY "mi_anon_select" ON menu_items
  FOR SELECT TO anon USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 11: ORDER_ITEMS  (oi_admin + oi_waiter_insert + oi_cashier_select + oi_kitchen_select + oi_waiter_select + oi_kitchen_update + oi_waiter_update)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "oi_admin"          ON order_items;
DROP POLICY IF EXISTS "oi_waiter_insert"  ON order_items;
DROP POLICY IF EXISTS "oi_cashier_select" ON order_items;
DROP POLICY IF EXISTS "oi_kitchen_select" ON order_items;
DROP POLICY IF EXISTS "oi_waiter_select"  ON order_items;
DROP POLICY IF EXISTS "oi_kitchen_update" ON order_items;
DROP POLICY IF EXISTS "oi_waiter_update"  ON order_items;
DROP POLICY IF EXISTS "oi_insert"         ON order_items;
DROP POLICY IF EXISTS "oi_select"         ON order_items;
DROP POLICY IF EXISTS "oi_update"         ON order_items;

CREATE POLICY "oi_insert" ON order_items
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_items.order_id
      AND (o.company_id = get_my_company_id() OR o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid())))
    )
  );

CREATE POLICY "oi_select" ON order_items
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_items.order_id
      AND (o.company_id = get_my_company_id() OR o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid())))
    )
  );

CREATE POLICY "oi_update" ON order_items
  FOR UPDATE TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_items.order_id
      AND (o.company_id = get_my_company_id() OR o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid())))
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 12: ORDER_STATUS_LOGS  (osl_admin + osl_staff_insert + osl_staff_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "osl_admin"        ON order_status_logs;
DROP POLICY IF EXISTS "osl_staff_insert" ON order_status_logs;
DROP POLICY IF EXISTS "osl_staff_select" ON order_status_logs;
DROP POLICY IF EXISTS "osl_insert"       ON order_status_logs;
DROP POLICY IF EXISTS "osl_select"       ON order_status_logs;

CREATE POLICY "osl_insert" ON order_status_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_status_logs.order_id
      AND (o.company_id = get_my_company_id() OR o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid())))
    )
  );

CREATE POLICY "osl_select" ON order_status_logs
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_status_logs.order_id
      AND (o.company_id = get_my_company_id() OR o.branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid())))
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 13: PAYMENT_METHODS  (pm_admin + pm_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "pm_admin"  ON payment_methods;
DROP POLICY IF EXISTS "pm_select" ON payment_methods;
CREATE POLICY "pm_select" ON payment_methods
  FOR SELECT TO authenticated
  USING (true);   -- Global table, everyone can view methods
DROP POLICY IF EXISTS "pm_anon_select" ON payment_methods;
CREATE POLICY "pm_anon_select" ON payment_methods
  FOR SELECT TO anon USING (true);

-- (removed pos_invoices, pos_invoice_items, pos_payments as they were dropped from the schema)

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 17: PRINTERS (Consolidated printers_manage_admin + printers_select_staff)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "printers_manage_admin" ON printers;
DROP POLICY IF EXISTS "printers_select_staff" ON printers;
DROP POLICY IF EXISTS "printers_manage"       ON printers;
DROP POLICY IF EXISTS "printers_select"       ON printers;
DROP POLICY IF EXISTS "printers_admin_manage" ON printers;
DROP POLICY IF EXISTS "printers_admin_insert" ON printers;
DROP POLICY IF EXISTS "printers_admin_update" ON printers;
DROP POLICY IF EXISTS "printers_admin_delete" ON printers;

CREATE POLICY "printers_select" ON printers
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
  );
  
CREATE POLICY "printers_admin_insert" ON printers
  FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "printers_admin_update" ON printers
  FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "printers_admin_delete" ON printers
  FOR DELETE TO authenticated USING (is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 18: RESTAURANT_TABLES  (rt_admin + rt_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "rt_admin"  ON restaurant_tables;
DROP POLICY IF EXISTS "rt_select" ON restaurant_tables;
CREATE POLICY "rt_select" ON restaurant_tables
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR company_id = get_my_company_id()
  );
DROP POLICY IF EXISTS "rt_anon_select" ON restaurant_tables;
CREATE POLICY "rt_anon_select" ON restaurant_tables
  FOR SELECT TO anon USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 19: ROLE_ROUTE_ACCESS  (Admins can manage + Authenticated users can read)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Admins can manage role_route_access"           ON role_route_access;
DROP POLICY IF EXISTS "Authenticated users can read role_route_access" ON role_route_access;
DROP POLICY IF EXISTS "role_route_access_select"       ON role_route_access;
DROP POLICY IF EXISTS "role_route_access_admin_manage" ON role_route_access;
DROP POLICY IF EXISTS "role_route_access_admin_insert" ON role_route_access;
DROP POLICY IF EXISTS "role_route_access_admin_update" ON role_route_access;
DROP POLICY IF EXISTS "role_route_access_admin_delete" ON role_route_access;
-- One SELECT policy for all authenticated (admin or not)
CREATE POLICY "role_route_access_select" ON role_route_access
  FOR SELECT TO authenticated USING (true);
-- Separate manage policy for admins only
CREATE POLICY "role_route_access_admin_insert" ON role_route_access FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "role_route_access_admin_update" ON role_route_access FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "role_route_access_admin_delete" ON role_route_access FOR DELETE TO authenticated USING (is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 20: ROLES (Consolidated roles_admin_manage + roles_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "roles_admin_manage" ON roles;
DROP POLICY IF EXISTS "roles_select"       ON roles;
DROP POLICY IF EXISTS "roles_admin_write"  ON roles;
DROP POLICY IF EXISTS "roles_select_all"   ON roles;
DROP POLICY IF EXISTS "roles_admin_insert" ON roles;
DROP POLICY IF EXISTS "roles_admin_update" ON roles;
DROP POLICY IF EXISTS "roles_admin_delete" ON roles;
CREATE POLICY "roles_select" ON roles
  FOR SELECT TO authenticated
  USING (true); -- Roles viewable by all authenticated
CREATE POLICY "roles_admin_insert" ON roles FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "roles_admin_update" ON roles FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "roles_admin_delete" ON roles FOR DELETE TO authenticated USING (is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 21: SERVICE_ACTIVITY_LOG  (sal_insert + sal_select + service_activity_log_company)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sal_insert"                  ON service_activity_log;
DROP POLICY IF EXISTS "sal_select"                  ON service_activity_log;
DROP POLICY IF EXISTS "service_activity_log_company" ON service_activity_log;

CREATE POLICY "sal_insert" ON service_activity_log
  FOR INSERT TO authenticated
  WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "sal_select" ON service_activity_log
  FOR SELECT TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 22: SERVICE_DIAGNOSIS_ITEMS  (sdi_* + service_diagnosis_items_company)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sdi_select"                      ON service_diagnosis_items;
DROP POLICY IF EXISTS "sdi_insert"                      ON service_diagnosis_items;
DROP POLICY IF EXISTS "sdi_update"                      ON service_diagnosis_items;
DROP POLICY IF EXISTS "sdi_delete"                      ON service_diagnosis_items;
DROP POLICY IF EXISTS "service_diagnosis_items_company" ON service_diagnosis_items;

CREATE POLICY "sdi_select" ON service_diagnosis_items
  FOR SELECT TO authenticated
  USING (is_admin() OR EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_diagnosis_items.job_id
    AND sj.company_id = get_my_company_id()
  ));

CREATE POLICY "sdi_insert" ON service_diagnosis_items
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_diagnosis_items.job_id
    AND sj.company_id = get_my_company_id()
  ));

CREATE POLICY "sdi_update" ON service_diagnosis_items
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_diagnosis_items.job_id
    AND sj.company_id = get_my_company_id()
  ));

CREATE POLICY "sdi_delete" ON service_diagnosis_items
  FOR DELETE TO authenticated
  USING (is_admin() OR EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_diagnosis_items.job_id
    AND sj.company_id = get_my_company_id()
  ));

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 23: SERVICE_ISSUE_TEMPLATES  (sit_* + service_issue_templates_company)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sit_select"                       ON service_issue_templates;
DROP POLICY IF EXISTS "sit_insert"                       ON service_issue_templates;
DROP POLICY IF EXISTS "sit_update"                       ON service_issue_templates;
DROP POLICY IF EXISTS "sit_delete"                       ON service_issue_templates;
DROP POLICY IF EXISTS "service_issue_templates_company"  ON service_issue_templates;

CREATE POLICY "sit_select" ON service_issue_templates
  FOR SELECT TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());
CREATE POLICY "sit_insert" ON service_issue_templates
  FOR INSERT TO authenticated
  WITH CHECK (company_id = get_my_company_id());
CREATE POLICY "sit_update" ON service_issue_templates
  FOR UPDATE TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());
CREATE POLICY "sit_delete" ON service_issue_templates
  FOR DELETE TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 24: SERVICE_JOBS  (service_jobs_* + service_jobs_company)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "service_jobs_select"  ON service_jobs;
DROP POLICY IF EXISTS "service_jobs_insert"  ON service_jobs;
DROP POLICY IF EXISTS "service_jobs_update"  ON service_jobs;
DROP POLICY IF EXISTS "service_jobs_delete"  ON service_jobs;
DROP POLICY IF EXISTS "service_jobs_company" ON service_jobs;

CREATE POLICY "service_jobs_select" ON service_jobs
  FOR SELECT TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());
CREATE POLICY "service_jobs_insert" ON service_jobs
  FOR INSERT TO authenticated
  WITH CHECK (company_id = get_my_company_id());
CREATE POLICY "service_jobs_update" ON service_jobs
  FOR UPDATE TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());
CREATE POLICY "service_jobs_delete" ON service_jobs
  FOR DELETE TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 25: SERVICE_PARTS_USED  (spu_* + service_parts_used_company)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "spu_select"                  ON service_parts_used;
DROP POLICY IF EXISTS "spu_insert"                  ON service_parts_used;
DROP POLICY IF EXISTS "spu_update"                  ON service_parts_used;
DROP POLICY IF EXISTS "spu_delete"                  ON service_parts_used;
DROP POLICY IF EXISTS "service_parts_used_company"  ON service_parts_used;

CREATE POLICY "spu_select" ON service_parts_used
  FOR SELECT TO authenticated
  USING (is_admin() OR EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_parts_used.job_id
    AND sj.company_id = get_my_company_id()
  ));
CREATE POLICY "spu_insert" ON service_parts_used
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_parts_used.job_id
    AND sj.company_id = get_my_company_id()
  ));
CREATE POLICY "spu_update" ON service_parts_used
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_parts_used.job_id
    AND sj.company_id = get_my_company_id()
  ));
CREATE POLICY "spu_delete" ON service_parts_used
  FOR DELETE TO authenticated
  USING (is_admin() OR EXISTS (
    SELECT 1 FROM service_jobs sj WHERE sj.id = service_parts_used.job_id
    AND sj.company_id = get_my_company_id()
  ));

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 26: SERVICE_REPORTS  (sr_* + service_reports_company)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sr_select"               ON service_reports;
DROP POLICY IF EXISTS "sr_insert"               ON service_reports;
DROP POLICY IF EXISTS "sr_update"               ON service_reports;
DROP POLICY IF EXISTS "service_reports_company" ON service_reports;

CREATE POLICY "sr_select" ON service_reports
  FOR SELECT TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());
CREATE POLICY "sr_insert" ON service_reports
  FOR INSERT TO authenticated
  WITH CHECK (company_id = get_my_company_id());
CREATE POLICY "sr_update" ON service_reports
  FOR UPDATE TO authenticated
  USING (is_admin() OR company_id = get_my_company_id());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 27: SYSTEM_MODULES (Consolidated system_modules_admin_manage + system_modules_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "system_modules_admin_write" ON system_modules;
DROP POLICY IF EXISTS "system_modules_select"      ON system_modules;
DROP POLICY IF EXISTS "system_modules_admin_manage" ON system_modules;
DROP POLICY IF EXISTS "system_modules_company_policy" ON system_modules;
DROP POLICY IF EXISTS "system_modules_admin_insert" ON system_modules;
DROP POLICY IF EXISTS "system_modules_admin_update" ON system_modules;
DROP POLICY IF EXISTS "system_modules_admin_delete" ON system_modules;
CREATE POLICY "system_modules_select" ON system_modules
  FOR SELECT TO authenticated
  USING (
    company_id IS NULL 
    OR is_admin() 
    OR company_id = get_my_company_id()
  );
CREATE POLICY "system_modules_admin_insert" ON system_modules FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "system_modules_admin_update" ON system_modules FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "system_modules_admin_delete" ON system_modules FOR DELETE TO authenticated USING (is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 28: TABLE_DEVICES (Consolidated td_admin + td_staff_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "td_admin"        ON table_devices;
DROP POLICY IF EXISTS "td_staff_select" ON table_devices;
DROP POLICY IF EXISTS "td_select"       ON table_devices;
CREATE POLICY "td_select" ON table_devices
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR branch_id IN (SELECT branch_id FROM user_branches WHERE user_id = (SELECT auth.uid()))
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 29: TABLE_QR_TOKENS (Consolidated qr_admin + qr_public_select)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "qr_admin"         ON table_qr_tokens;
DROP POLICY IF EXISTS "qr_public_select" ON table_qr_tokens;
DROP POLICY IF EXISTS "qr_select"        ON table_qr_tokens;
CREATE POLICY "qr_select" ON table_qr_tokens
  FOR SELECT TO authenticated
  USING (true); -- Scannable status check

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 30: USER_BRANCHES (Consolidated user_branches_admin_write + user_branches_select_own)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "user_branches_admin_write" ON user_branches;
DROP POLICY IF EXISTS "user_branches_select_own"  ON user_branches;
DROP POLICY IF EXISTS "user_branches_select"      ON user_branches;
CREATE POLICY "user_branches_select" ON user_branches
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR user_id = (SELECT auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 31: USER_ROLES (Consolidated user_roles_admin_write + user_roles_select_own)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "user_roles_admin_write" ON user_roles;
DROP POLICY IF EXISTS "user_roles_select_own"  ON user_roles;
DROP POLICY IF EXISTS "user_roles_select"      ON user_roles;
CREATE POLICY "user_roles_select" ON user_roles
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR user_id = (SELECT auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 32: CLEANUP DUPLICATE INDEXES
-- ─────────────────────────────────────────────────────────────────────────────
DROP INDEX IF EXISTS idx_invoices_no_trgm; -- Duplicate of idx_invoices_search_trgm

END $main$;

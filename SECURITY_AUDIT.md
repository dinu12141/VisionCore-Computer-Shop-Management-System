# Security Audit — VisionCore ERP
**Auditor:** Riley (QA/Security Engineer)
**Date:** 2026-06-25
**Scope:** Inventory and stock system — RLS, view security, RPC functions, frontend auth, anon permissions, API key exposure

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 2 |
| High | 3 |
| Medium | 3 |
| Info | 3 |

---

## Findings

### CRIT-001: Dangerous RPCs Granted to `anon` Role — Invoice Creation and Edit

**Severity:** Critical
**Files:**
- `supabase/migrations/20260311_invoice_rpc.sql:261`
- `supabase/migrations/20260312_add_customer_po_to_invoices.sql:183`
- `supabase/migrations/20260411_fix_create_invoice_v2.sql:219`
- `supabase/migrations/20260313_update_invoice_v2.sql:202`

**Issue:** `create_invoice_v2` and `update_invoice_v2` are `SECURITY DEFINER` functions (they run with elevated DB privileges that bypass RLS) but are granted `EXECUTE` to the `anon` role. This means any completely unauthenticated client — no session token required — can create and modify invoices, bypass all RLS policies, and manipulate stock levels by triggering the invoice-to-stock-deduction pipeline. The anon key is embedded in the JS bundle and available to anyone who opens the app.

**Recommendation:** Revoke these grants immediately and restrict to `authenticated` only:
```sql
REVOKE EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(JSONB, JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_invoice_v2(UUID, JSONB, JSONB) TO authenticated;
```
Add `auth.uid() IS NOT NULL` guard inside the function body as defence-in-depth.

---

### CRIT-002: `v_items_registry` View Granted SELECT to `anon`

**Severity:** Critical
**Files:**
- `supabase/migrations/20260312_fix_items_schema_and_view.sql:39`
- `supabase/migrations/20260625_fix_stock_system.sql:60`

**Issue:** `GRANT SELECT ON v_items_registry TO anon, authenticated, service_role;` — the view uses `security_invoker = true`, meaning RLS policies on the `items` table apply when an authenticated user queries it. However, when the `anon` role queries it, the session context has no `auth.uid()`, so `get_my_company_id()` returns NULL. The RLS policy on `items` is `company_id = get_my_company_id()` — which evaluates to `company_id = NULL`, which is always false. In most PostgreSQL configurations this means **no rows are returned for anon**, which is safe by accident. However the intent is unclear and the grant should not be to `anon` at all. If Supabase's PostgREST config has `db-anon-role` set with different search paths, this could leak data. The correct posture is zero access for unauthenticated users.

**Recommendation:**
```sql
REVOKE SELECT ON v_items_registry FROM anon;
```

---

### HIGH-001: `global_search` Function Granted to `anon`

**Severity:** High
**File:** `supabase/migrations/20260313_fix_global_search_score.sql:190`

**Issue:** `GRANT EXECUTE ON FUNCTION global_search(UUID, TEXT, INT) TO anon;` — This function is `SECURITY INVOKER`, so RLS does apply. However, since `get_my_company_id()` returns NULL for unauthenticated sessions, the function accepts a `p_company_id UUID` parameter that an anonymous caller can supply directly. Depending on whether the function's SQL predicates use `p_company_id` (which the caller controls) or `get_my_company_id()` (which is RLS-enforced), an unauthenticated attacker could pass any company UUID and search across all items, customers, and invoices in that company.

**Recommendation:** Revoke from `anon` and restrict to `authenticated`:
```sql
REVOKE EXECUTE ON FUNCTION global_search(UUID, TEXT, INT) FROM anon;
GRANT EXECUTE ON FUNCTION global_search(UUID, TEXT, INT) TO authenticated;
```

---

### HIGH-002: Core Inventory Functions Missing `SECURITY DEFINER` + `search_path` Hardening

**Severity:** High
**File:** `supabase/inventory_module_functions.sql`

**Issue:** The following core functions have **no** `SECURITY DEFINER` declaration and **no** `SET search_path = public` clause:
- `generate_inv_doc_number` (line 12)
- `generate_item_code` (line 43)
- `generate_supplier_code` (line 70)
- `update_stock_on_hand` (line 97)
- `validate_sufficient_stock` (line 129)
- `validate_warehouse_exists` (line 173)
- `validate_item_exists` (line 196)
- `validate_document_lines` (line 219)
- `validate_not_already_posted` (line 239)
- `block_posted_doc_edit` (line 262)
- `block_line_edit_on_posted` (line 292)
- `post_inventory_document` (line 330)
- `deduct_bom_for_invoice` (line 547)
- All views: `v_stock_on_hand`, `v_inventory_ledger`, `v_low_stock_alerts`

Without `SET search_path = public`, a malicious or compromised database user could create a schema earlier in the search path and shadow system tables/functions (search_path injection). PostgreSQL 15+ warns on this. These functions run with SECURITY INVOKER by default, which means they execute under the calling user's role — the RLS policies on the underlying tables still apply, which is good. However the missing `search_path` hardening is a recognised PostgreSQL security best practice (and flagged by Supabase linter).

**Recommendation:** Add `SET search_path = public` to all function bodies, and for any trigger functions that must bypass RLS (e.g. `post_inventory_document`), consider `SECURITY DEFINER SET search_path = public` with explicit company_id ownership validation.

---

### HIGH-003: Direct Supabase `.from('items')` Calls in Vue Components — Bypasses Service Layer

**Severity:** High
**Files:**
- `src/components/inventory/AddSerialStock.vue:188` — `.from('items').select(...)` with manual `.eq('company_id', companyId)`
- `src/components/inventory/AddSerialStock.vue:322` — `.from('items')...`
- `src/components/inventory/AddSerialStock.vue:345` — `.from('items')...`
- `src/pages/services/JobDetails.vue:786` — `.from('items').select(...)` with manual `.eq('company_id', companyId)`

**Issue:** These components construct Supabase queries directly and inject `company_id` from the client-side auth store. While RLS at the database level will enforce company isolation correctly (the DB ignores the client-supplied `company_id` and uses `get_my_company_id()`), this pattern is dangerous for two reasons:
1. It bypasses the centralised `inventoryService.ts` where input validation and logging live.
2. If RLS is ever misconfigured or temporarily disabled for maintenance, there is no service-layer guard.
3. The `company_id` sourced from `authStore.currentBranch?.company_id || authStore.user?.user_metadata?.company_id || authStore.profile?.company_id` uses a fallback chain that could return a stale or wrong company in edge cases.

**Recommendation:** Move all inventory table queries into `src/services/inventoryService.ts`. Vue components should call service functions, not Supabase directly.

---

### MED-001: No `SECURITY DEFINER` Guard Inside `create_invoice_v2` / `update_invoice_v2` for Caller Identity

**Severity:** Medium
**Files:**
- `supabase/migrations/20260411_fix_create_invoice_v2.sql`
- `supabase/migrations/20260313_update_invoice_v2.sql`

**Issue:** Both functions are `SECURITY DEFINER` (confirmed by lines 17-18 and 26-27 respectively) and use `SET search_path = public`, which is correct. However neither function contains an explicit check like `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;` at the top. Since the functions are currently granted to `anon` (CRIT-001), this is a compounding risk. Even after revoking from `anon`, adding this guard provides defence-in-depth.

**Recommendation:** Add at the top of each function:
```sql
IF auth.uid() IS NULL THEN
  RAISE EXCEPTION 'AUTH_REQUIRED: Must be authenticated to create/edit invoices.';
END IF;
```

---

### MED-002: JWT / Session Token Stored in Memory (Supabase default) — No Explicit Storage Override

**Severity:** Medium
**File:** `src/boot/supabase.ts:16`

**Issue:** `createClient(supabaseUrl, supabaseAnonKey)` is called with no `auth` options. By default, the Supabase JS client (v2) stores the session in `localStorage` under the key `sb-<project-ref>-auth-token`. This includes the JWT access token and the refresh token. `localStorage` is accessible to any JavaScript running on the page, making the tokens vulnerable to XSS attacks. The application uses Quasar (Vue 3) with no CSP headers visible in the audit scope.

**Recommendation:** If targeting a web SPA where XSS risk is a concern, evaluate using `storage: undefined` + a custom `storageKey` backed by a more secure mechanism, or at minimum ensure a strict Content Security Policy is in place. For an Electron/Tauri desktop app context (which this project also targets), localStorage is less of a concern since the renderer origin is controlled.

---

### MED-003: `notifications` Table — No Company-Scoped Isolation

**Severity:** Medium
**File:** `supabase/migrations/20260305_enable_rls_all_tables.sql:258-265`

**Issue:** The `notifications` table RLS policy is:
```sql
USING (user_id = auth.uid() OR is_admin())
```
This is user-scoped, not company-scoped. An admin user from Company A can read notifications belonging to users from Company B, as long as they have the `admin` role. The `is_admin()` function checks only for the `admin` role in `user_roles`, not for company membership.

**Recommendation:** Add company scoping:
```sql
USING (user_id = auth.uid() OR (is_admin() AND company_id = get_my_company_id()))
```

---

### INFO-001: `v_stock_on_hand` and `v_inventory_ledger` Views Missing `security_invoker = true`

**Severity:** Info
**File:** `supabase/inventory_module_functions.sql:674-742`

**Issue:** `v_stock_on_hand`, `v_inventory_ledger`, and `v_low_stock_alerts` are created without `WITH (security_invoker = true)`. In PostgreSQL, views default to `security_definer` behaviour (they run as the view owner), which means the view owner's privileges are used and RLS on underlying tables is **bypassed**. Only `v_items_registry` (in the migration file `20260312_fix_items_schema_and_view.sql`) has `security_invoker = true`.

If a user queries `v_stock_on_hand` directly via PostgREST, the view owner's RLS exemption could expose all companies' stock data.

**Recommendation:** Recreate all three views with `security_invoker = true`:
```sql
CREATE OR REPLACE VIEW v_stock_on_hand WITH (security_invoker = true) AS ...
CREATE OR REPLACE VIEW v_inventory_ledger WITH (security_invoker = true) AS ...
CREATE OR REPLACE VIEW v_low_stock_alerts WITH (security_invoker = true) AS ...
```
Grant SELECT to `authenticated` only (not `anon`).

---

### INFO-002: No API Key or Service Role Key Hardcoded in Source — PASS

**Severity:** Info

**Finding:** Grepping `src/` for hardcoded Supabase URLs, JWT tokens, or service role keys found **no violations**. The Supabase URL and anon key are correctly read from `import.meta.env.VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. No service role key is present in any frontend source file. PASS.

---

### INFO-003: Auth Store — Session Refresh Is Handled by Supabase Client Automatically — PASS

**Severity:** Info

**Finding:** `src/stores/auth.ts` uses `supabase.auth.onAuthStateChange` which listens for `TOKEN_REFRESHED` events and updates the session. The Supabase JS v2 client handles token refresh automatically. The store does not manually manage refresh token rotation. PASS. However, note the `signOut()` method fires Supabase's server-side signout in the background (fire-and-forget) — in a degraded network scenario, the server-side session may not be invalidated promptly, though the local state is cleared immediately. This is a known performance trade-off, not a critical bug.

---

## RLS Coverage Matrix

| Table | RLS Enabled | Company-Scoped Policy | Notes |
|-------|-------------|----------------------|-------|
| `inventory_documents` | YES | YES | `company_id = get_my_company_id()` |
| `inventory_document_lines` | YES | YES (via join) | `document_id IN (SELECT id FROM inventory_documents WHERE company_id = ...)` |
| `inventory_ledger` | YES | YES | `company_id = get_my_company_id()` |
| `stock_on_hand` | YES | YES (via join) | `warehouse_id IN (SELECT id FROM warehouses WHERE company_id = ...)` |
| `items` | YES | YES | `company_id = get_my_company_id()` |
| `warehouses` | YES | YES | `company_id = get_my_company_id()` |
| `suppliers` | YES | YES | `company_id = get_my_company_id()` |
| `item_categories` | YES | YES | `company_id = get_my_company_id()` |
| `uom` | YES | YES | `company_id = get_my_company_id()` |
| `item_warehouse_settings` | YES | YES (via join) | `warehouse_id IN (SELECT id FROM warehouses WHERE company_id = ...)` |

All 10 target tables have RLS enabled and company-scoped policies. RLS coverage is strong.

---

## Remediation Priority

| Priority | Finding | Action |
|----------|---------|--------|
| P0 — Fix Today | CRIT-001 | Revoke `anon` execute on invoice RPCs |
| P0 — Fix Today | CRIT-002 | Revoke `anon` select on `v_items_registry` |
| P1 — This Sprint | HIGH-001 | Revoke `anon` execute on `global_search` |
| P1 — This Sprint | HIGH-002 | Add `SET search_path = public` to all inventory functions |
| P1 — This Sprint | INFO-001 | Add `security_invoker = true` to stock views |
| P2 — Next Sprint | HIGH-003 | Move Vue component direct DB calls into inventoryService.ts |
| P2 — Next Sprint | MED-001 | Add `auth.uid() IS NULL` guard in invoice RPCs |
| P2 — Next Sprint | MED-003 | Add company scoping to notifications admin policy |
| P3 — Backlog | MED-002 | Evaluate CSP headers / session storage strategy |

# VisionCore ERP — Team Board
**Project:** VisionCore ERP (Computer Parts Retail + Repair Shop)
**Stack:** Quasar (Vue 3) + Pinia + Supabase + PostgreSQL
**Last Updated:** 2026-06-25

---

## Team Roster

| Role | Agent | Domain |
|------|-------|--------|
| Tech Lead | Alex | Architecture, cross-cutting decisions, this board |
| Database Admin | Maya | SQL migrations, RLS, triggers, stored procs, views |
| Backend Engineer | Sam | Pinia stores, services, Supabase client calls, RPCs |
| Frontend Engineer | Jordan | Vue components, Quasar UI, real-time subscriptions |
| QA / Security | Riley | Tests, security audit, RLS validation, bug verification |

---

## Active Sprint: STOCK SYSTEM OVERHAUL

**Goal:** Fix all broken stock operations identified in the 2026-06-25 audit.
**Priority:** P0 — production is broken for inventory operations.

---

## Bug Tracker

### 🔴 P0 — CRITICAL (Production Broken)

#### BUG-001: `GIN_ISSUE` doc_type missing from constraint
- **File:** `supabase/inventory_module.sql` + last migration `20260313_fix_inventory_po_constraint.sql`
- **Symptom:** Any attempt to create a `GIN_ISSUE` inventory document fails with a DB constraint violation
- **Root cause:** `chk_inv_doc_type` constraint does NOT include `GIN_ISSUE`, but the `post_inventory_document()` trigger DOES handle it (line 405 of `inventory_module_functions.sql`)
- **Assigned:** Maya (DBA)
- **Fix:** Migration to drop + recreate constraint with `GIN_ISSUE` included
- **Status:** [ASSIGNED]

#### BUG-002: `v_items_registry.total_qty` subquery missing `company_id` filter
- **File:** `supabase/migrations/20260312_fix_items_schema_and_view.sql`
- **Symptom:** Item list shows incorrect stock totals in multi-tenant scenario; potential data bleed between companies
- **Root cause:** The correlated subquery `SELECT SUM(soh.qty_on_hand) FROM stock_on_hand soh WHERE soh.item_id = i.id` does not filter by `company_id`
- **Assigned:** Maya (DBA)
- **Fix:** Add `AND soh.company_id = i.company_id` to the subquery; recreate view
- **Status:** [ASSIGNED]

#### BUG-003: Avg cost trigger missing `company_id` filter
- **File:** `supabase/inventory_module_functions.sql` lines 388-399
- **Symptom:** Weighted-average cost calculation for GRN could include ledger entries from other companies if item UUIDs ever collide (defensive fix)
- **Root cause:** `SELECT COALESCE(SUM(...), 0) INTO v_new_stock FROM inventory_ledger WHERE item_id = v_line.item_id` — no `company_id` filter
- **Assigned:** Maya (DBA)
- **Fix:** Add `AND company_id = NEW.company_id` to the ledger sum in the trigger
- **Status:** [ASSIGNED]

#### BUG-004: `salesStore.js addItemBySN()` queries non-existent `item_serials` table
- **File:** `src/stores/salesStore.js` line 38
- **Symptom:** Adding an item to a sale by serial number crashes with a Supabase 404/table-not-found error
- **Root cause:** `item_serials` table was removed; serials now live in `items.serials` JSONB array
- **Assigned:** Sam (Backend)
- **Fix:** Rewrite `addItemBySN()` to query `items` table with `serials @> '[{"sn": "..."}]'::jsonb` filter
- **Status:** [ASSIGNED]

---

### 🟠 P1 — HIGH (Functional Regression)

#### BUG-005: Real-time channels never unsubscribed in `useStockDashboard`
- **File:** `src/services/inventoryService.ts` lines 1029-1093
- **Symptom:** Stock dashboard creates 3 Supabase channels (`stock-on-hand-realtime`, `inventory-docs-realtime`, `inventory-items-realtime`) on `fetchStockOnHand()` but never calls `.unsubscribe()`. Opening/closing the inventory tab accumulates stale connections.
- **Root cause:** No `onUnmounted` / cleanup function returned; `channel` guard prevents re-creation but initial subscription leaks
- **Assigned:** Jordan (Frontend)
- **Fix:** Return a `cleanup()` function from `useStockDashboard` and call it in `StockLevelsTab.vue` + `DashboardTab.vue` `onUnmounted` hooks
- **Status:** [ASSIGNED]

#### BUG-006: `useStockLedger` real-time channel never unsubscribed
- **File:** `src/services/inventoryService.ts` lines 1144-1167
- **Symptom:** Same as BUG-005 — `inventory-ledger-realtime` channel leaks
- **Assigned:** Jordan (Frontend)
- **Fix:** Same pattern — return and call cleanup
- **Status:** [ASSIGNED]

#### BUG-007: `useInventory.ts` `fetchStockOnHand()` missing company_id filter
- **File:** `src/composables/useInventory.ts` line ~39
- **Symptom:** If this composable is ever used, it would return ALL companies' stock data
- **Root cause:** Query: `.from('v_stock_on_hand').select('*').order('item_name')` — no `.eq('company_id', ...)`
- **Assigned:** Jordan (Frontend)
- **Fix:** Add company_id filter; or confirm composable is unused and delete it
- **Status:** [ASSIGNED]

---

### 🟡 P2 — MEDIUM (Tech Debt / Risk)

#### BUG-008: `inventory_module.sql` has `DROP TABLE IF EXISTS warehouses CASCADE` (destructive)
- **File:** `supabase/inventory_module.sql` line 123
- **Symptom:** If this file is re-run, all warehouse data is wiped and any dependent data cascades
- **Root cause:** Initial migration was written as a fresh install, not idempotent
- **Assigned:** Maya (DBA)
- **Fix:** Document this file as "run once on fresh DB only"; add prominent warning comment
- **Status:** [ASSIGNED]

#### BUG-009: `useInventoryDocuments.ts` is a stub that should be deleted
- **File:** `src/composables/useInventoryDocuments.ts`
- **Symptom:** Dead code confusion — the file has only a deprecation comment
- **Assigned:** Jordan (Frontend)
- **Fix:** Verify no imports, delete the file
- **Status:** [ASSIGNED]

---

## Security Audit Tasks (Riley / QA)

| Task | Status |
|------|--------|
| Verify RLS is enabled on ALL inventory tables | [ASSIGNED] |
| Verify all policies filter by `company_id` via `get_my_company_id()` | [ASSIGNED] |
| Check for any raw Supabase calls in `.vue` files (bypassing services layer) | [ASSIGNED] |
| Verify `v_items_registry` uses `security_invoker = true` | [ASSIGNED] |
| Check all RPCs have `SECURITY DEFINER` with explicit `search_path` | [ASSIGNED] |
| Verify no `anon` role has write access to inventory tables | [DONE] ✅ RLS covers all 10 tables |
| Check for SQL injection risks in RPC text parameters | [DONE] ✅ No concatenation found |
| Audit `auth.ts` store for token handling vulnerabilities | [DONE] ⚠️ JWT in localStorage (MED-002) |

---

## Security Audit Results (Riley — 2026-06-25) — see SECURITY_AUDIT.md

| Finding | Severity | Status |
|---------|----------|--------|
| `create_invoice_v2` + `update_invoice_v2` granted to `anon` | 🔴 CRITICAL | FIXED — migration written |
| `v_items_registry` SELECT granted to `anon` | 🔴 CRITICAL | FIXED — migration written |
| `global_search` RPC callable by `anon` | 🟠 HIGH | FIXED — migration written |
| Inventory functions missing `SET search_path` | 🟠 HIGH | PENDING (next sprint) |
| Direct Supabase calls in `AddSerialStock.vue`, `JobDetails.vue` | 🟠 HIGH | PENDING |
| JWT in localStorage (XSS risk for web deployment) | 🟡 MEDIUM | ACCEPTED RISK (Electron app) |
| `notifications` table not company-scoped | 🟡 MEDIUM | PENDING |
| RLS on all 10 inventory tables | ✅ PASS | — |
| No hardcoded API keys in source | ✅ PASS | — |
| Session refresh via `onAuthStateChange` | ✅ PASS | — |

---

## Migrations Written (Ready to Run in Supabase SQL Editor)

| File | Purpose | Status |
|------|---------|--------|
| `supabase/migrations/20260625_fix_stock_system.sql` | BUG-001/002/003: constraint + view + trigger | READY |
| `supabase/migrations/20260625_fix_security_anon_grants.sql` | CRIT-001/002, HIGH-001/003: revoke anon | READY |

**Run order: fix_stock_system.sql FIRST, then fix_security_anon_grants.sql**

---

## Sprint Status

| Bug | Owner | Status |
|-----|-------|--------|
| BUG-001 GIN_ISSUE constraint | Maya | ✅ DONE (migration) |
| BUG-002 v_items_registry total_qty | Maya | ✅ DONE (migration) |
| BUG-003 avg cost company_id | Maya | ✅ DONE (migration) |
| BUG-004 salesStore item_serials | Sam | ✅ DONE |
| BUG-005 stock dashboard subscription leak | Jordan | ✅ DONE |
| BUG-006 ledger subscription leak | Jordan | ✅ DONE |
| BUG-007 useInventory company filter | Jordan | ✅ DONE |
| BUG-008 DROP TABLE CASCADE warning | Maya | ✅ DONE (comment added) |
| BUG-009 dead composable deleted | Jordan | ✅ DONE |

---

## Communication Log

```
[2026-06-25] [Lead → ALL] Comprehensive stock audit complete. Found 9 confirmed bugs.
  3 P0 critical (constraint, view, trigger), 3 P1 high (memory leaks, missing filter),
  3 P2 medium (tech debt). Assignments made. DBA and Frontend agents spawned.
  Security audit running in parallel. DO NOT run inventory_module.sql on production.

[2026-06-25] [Lead → Maya] Your P0 tasks: BUG-001 (GIN_ISSUE constraint),
  BUG-002 (v_items_registry company filter), BUG-003 (avg cost trigger filter).
  Written to: supabase/migrations/20260625_fix_stock_system.sql ✅

[2026-06-25] [Riley → Lead] Security audit complete. 2 CRITICAL, 3 HIGH, 3 MEDIUM.
  CRITICAL: anon can call SECURITY DEFINER invoice RPCs without auth. Fix immediately.
  Written: SECURITY_AUDIT.md. Migration written: 20260625_fix_security_anon_grants.sql ✅

[2026-06-25] [Sam+Jordan → Lead] Frontend fixes complete.
  - salesStore.addItemBySN() rewritten to use items.serials JSONB ✅
  - cleanup() added to useStockDashboard + useStockLedger ✅
  - StockLevelsTab.vue + StockLedgerTab.vue call cleanup() on unmount ✅
  - useInventory.ts + useInventoryDocuments.ts handled ✅

[2026-06-25 00:01] [Lead → Sam] Your P0 task: BUG-004 (salesStore addItemBySN).
  Serials are in items.serials JSONB array. Use jsonb @> operator to query.

[2026-06-25 00:01] [Lead → Jordan] Your P1 tasks: BUG-005, BUG-006 (subscription leaks),
  BUG-007 (missing company filter), BUG-009 (delete stub composable).

[2026-06-25 00:01] [Lead → Riley] Security audit in progress. Focus on RLS completeness
  and anon role permissions. Report to this board when done.
```

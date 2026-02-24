# Inventory Module — Architecture & Rules

## 📐 System Architecture (SAP B1-Style)

```
┌─────────────────────────────────────────────────────────────┐
│                    INVENTORY MODULE                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │   GRN    │   │   GIN    │   │ Transfer │               │
│  │ Document │   │ Document │   │ Document │               │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘              │
│       │              │              │                      │
│  ┌────┴─────┐   ┌────┴──────┐  ┌───┴──────┐              │
│  │ Adjust   │   │  Stock    │  │ BOM/     │              │
│  │ Document │   │  Count    │  │ Recipe   │              │
│  └────┬─────┘   └────┬─────┘  └───┬──────┘              │
│       │              │             │                      │
│       └──────────────┼─────────────┘                      │
│                      ▼                                     │
│           ┌──────────────────┐                             │
│           │ post_inv_document│  ← SINGLE POSTING FUNCTION  │
│           │     (SQL fn)     │                             │
│           └────────┬─────────┘                             │
│                    ▼                                       │
│     ┌──────────────────────────────┐                       │
│     │    STOCK LEDGER (Immutable)  │ ← APPEND-ONLY         │
│     │    Every IN/OUT is a row     │                       │
│     └──────────────┬───────────────┘                       │
│                    ▼                                       │
│     ┌──────────────────────────────┐                       │
│     │ STOCK ON HAND (Mat. View)   │ ← DERIVED from ledger  │
│     │ SUM(IN) - SUM(OUT) per wh   │                       │
│     └──────────────────────────────┘                       │
│                                                             │
│  WAREHOUSES:                                                │
│  ┌─────────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌─────┐ ┌─────┐  │
│  │  MAIN   │ │ KIT1 │ │ KIT2 │ │ KIT3 │ │KIT4 │ │ BAR │  │
│  │  STORE  │ │ Hot  │ │ Cold │ │Bakery│ │Grill│ │     │  │
│  └─────────┘ └──────┘ └──────┘ └──────┘ └─────┘ └─────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Posting Rules

### Rule 1: Every Document Posts to the Immutable Stock Ledger

- **No direct stock_levels updates.** All changes flow through `inv_documents` → `stock_ledger`.
- The `stock_ledger` is **append-only** — rows are never updated or deleted.
- `stock_on_hand` is a materialized view: `SUM(IN) - SUM(OUT)` per item + warehouse.

### Rule 2: Document Lifecycle

```
draft → pending_approval → approved → posted → closed
                                  └──→ cancelled
```

| Status             | Can Edit Lines? | Ledger Effect      | Notes                     |
| ------------------ | --------------- | ------------------ | ------------------------- |
| `draft`            | ✅ Yes          | None               | User is still editing     |
| `pending_approval` | ❌ No           | None               | Awaiting manager approval |
| `approved`         | ❌ No           | None               | Ready to post             |
| `posted`           | ❌ No           | ✅ Written         | Immutable once posted     |
| `cancelled`        | ❌ No           | None               | Void — no ledger entry    |
| `closed`           | ❌ No           | ✅ Already written | Archived                  |

### Rule 3: Posting Rules per Document Type

| Doc Type             | Code         | Direction | Source Warehouse | Target Warehouse | Approval? |
| -------------------- | ------------ | --------- | ---------------- | ---------------- | --------- |
| Goods Received Note  | `GRN`        | IN        | Main Store       | —                | No        |
| Goods Issue Note     | `GIN`        | OUT       | Kitchen/Bar/Main | —                | Yes       |
| Stock Transfer       | `TRF`        | TRANSFER  | Source WH        | Target WH        | Yes       |
| Stock Adjustment     | `ADJ`        | ADJUST    | Any WH           | —                | Yes       |
| Stock Count          | `CNT`        | COUNT     | Counted WH       | —                | Yes       |
| Recipe/BOM Deduction | `BOM_DEDUCT` | OUT       | Kitchen Store    | —                | No (auto) |
| Wastage              | `WASTAGE`    | OUT       | Any WH           | —                | Yes       |
| Opening Balance      | `OPENING`    | IN        | Any WH           | —                | No        |

### Rule 4: BOM/Recipe Auto-Deduction

- **Trigger**: When an `invoice` is created (INSERT on `invoices` table).
- **Process**:
  1. Look up order items from the invoice's order.
  2. For each item, find recipe (variant-specific first, then base).
  3. Calculate ingredient quantities: `recipe_qty × order_qty`.
  4. Create a `BOM_DEDUCT` document targeting the kitchen warehouse.
  5. Auto-post the document → stock ledger entries created.
- **Warehouse Selection**: Kitchen warehouse of the branch; fallback to main store.

### Rule 5: Reversal (Correction) Pattern

- Documents are **never deleted** from the ledger.
- To reverse: create a **new document** of opposite direction with reference to original.
- Example: GRN reversal → create GIN with same items, referencing original GRN number.

### Rule 6: Stock Count Posting

- Counted quantity is entered per item.
- System quantity is fetched from `stock_on_hand` materialized view.
- Variance = `counted_qty - system_qty`.
- Only non-zero variances post to ledger (positive = IN, negative = OUT).

---

## 🔌 API / Service Layer Structure

### Composables (Frontend — `/src/composables/`)

```
composables/
├── useInventory.ts          # Stock on hand, item master CRUD
├── useInventoryDocuments.ts  # Create/edit/post documents
├── useWarehouses.ts          # Warehouse management
└── useSuppliers.ts           # Supplier management
```

### Pinia Store (Frontend — `/src/stores/`)

```
stores/
└── inventoryStore.js        # Central state for inventory module
```

### Key API Functions

#### `useInventory.ts`

```javascript
// Stock on hand
fetchStockOnHand(warehouseId?, companyId?)
fetchLowStockAlerts(companyId)
fetchStockLedger(filters: { itemId?, warehouseId?, dateFrom?, dateTo? })

// Item Master
fetchStockItems(companyId)
createStockItem(item)
updateStockItem(id, data)
deactivateStockItem(id)

// Item Groups
fetchItemGroups(companyId)
createItemGroup(group)
```

#### `useInventoryDocuments.ts`

```javascript
// Document CRUD
createDocument(docType, headerData, lineItems)
updateDocumentLines(docId, lineItems)
submitForApproval(docId)
approveDocument(docId, approvedBy)
postDocument(docId) // calls post_inv_document RPC
cancelDocument(docId)

// Specific document helpers
createGRN(supplierId, warehouseId, items)
createGIN(warehouseId, items, reason)
createTransfer(fromWhId, toWhId, items)
createStockCount(warehouseId, countedItems)
createAdjustment(warehouseId, items, reason)

// Sequences
getNextDocNumber(companyId, docTypeCode)
```

#### `useWarehouses.ts`

```javascript
fetchWarehouses(branchId?, companyId?)
createWarehouse(data)
updateWarehouse(id, data)
deactivateWarehouse(id)
getDefaultWarehouse(branchId, type?)
```

#### `useSuppliers.ts`

```javascript
fetchSuppliers(companyId)
createSupplier(data)
updateSupplier(id, data)
deactivateSupplier(id)
```

---

## 🖥️ UI Pages & Workflows

### Page Structure

```
InventoryPage.vue (Main — Tabbed Layout)
├── Tab: Dashboard        → Stats, charts, alerts overview
├── Tab: Stock On Hand    → Grid: item × warehouse quantities
├── Tab: Documents        → List all inv_documents + create new
├── Tab: Stock Items      → Item master CRUD
├── Tab: Warehouses       → Warehouse management
├── Tab: Suppliers        → Supplier management
└── Tab: Stock Ledger     → Full audit trail (read-only)
```

### Workflow: Goods Received Note (GRN)

```
1. User clicks "New GRN"
2. Select warehouse (default: Main Store) + Supplier
3. Add line items: stock item, qty, unit price, batch, expiry
4. Save as Draft
5. Review totals → Submit (status → 'posted' directly, no approval for GRN)
6. System posts all lines to stock_ledger as direction=IN
7. Materialized view refreshed → stock_on_hand updated
```

### Workflow: Goods Issue Note (GIN)

```
1. User clicks "New GIN"
2. Select source warehouse (kitchen/bar/main)
3. Add items to issue + reason (wastage, consumption, etc.)
4. Save as Draft → Submit for Approval
5. Manager approves → status = 'approved'
6. System auto-posts (if workflow config allows) or user clicks Post
7. Stock ledger updated with direction=OUT
```

### Workflow: Stock Transfer

```
1. User clicks "New Transfer"
2. Select Source Warehouse → Target Warehouse
3. Add items + quantities
4. Save as Draft → Submit for Approval
5. Manager reviews → Approve
6. Post: creates 2 ledger entries per item (OUT from source, IN to target)
7. Both warehouses updated in stock_on_hand
```

### Workflow: Stock Count

```
1. User clicks "New Stock Count"
2. Select warehouse to count
3. System pre-loads all items with system quantity from stock_on_hand
4. User enters counted quantities
5. Variance auto-calculated: variance = counted - system
6. Save → Submit for Approval
7. Manager reviews variances → Approve
8. Post: only non-zero variances written to ledger
```

### Workflow: Stock Adjustment

```
1. User clicks "New Adjustment"
2. Select warehouse
3. Add items with +/- quantities + reason
4. Save → Submit for Approval
5. Manager approves → Post
6. Positive qty → IN to ledger, Negative → OUT
```

### Workflow: Recipe/BOM Auto-Deduction

```
1. Cashier creates invoice for an order (billing flow)
2. Trigger fires on INSERT to invoices table
3. System looks up order items → finds recipes → calculates ingredients
4. Creates BOM_DEDUCT document → auto-posts to stock_ledger
5. Kitchen store stock reduced automatically
6. Dashboard reflects updated quantities in real-time
```

---

## 🔮 Future Extensibility

| Feature                 | How to Add                                                      |
| ----------------------- | --------------------------------------------------------------- |
| New warehouse           | INSERT into `warehouses` table — no schema change               |
| New document type       | INSERT into `inv_document_types` — posting engine handles it    |
| Enable/disable approval | UPDATE `inv_workflow_config` per company + doc type             |
| Purchase Orders         | New table `purchase_orders` → links to GRN via `reference_no`   |
| Batch/Lot tracking      | Already supported via `batch_no` + `expiry_date` on ledger      |
| Multi-branch inventory  | Already supported — warehouses are per-branch                   |
| Barcode scanning        | Add `barcode` column to `stock_items` — no schema change needed |
| Inter-branch transfers  | Use `TRF` document with warehouses from different branches      |

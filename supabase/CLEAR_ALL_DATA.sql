-- ============================================================================
-- VISION-ERP: DELETE ALL MOCK/EXISTING OPERATIONAL DATA
-- ============================================================================
-- NOTE: This will delete all existing transactions, items, and customers,
-- but will keep your company, branches, and admin users intact.

-- 1. DELETE TRANSACTIONAL DATA (Invoices, Service Jobs, Inventory movements)
TRUNCATE TABLE 
    invoices,
    invoice_items,
    invoice_payments,
    service_jobs,
    service_diagnosis_items,
    service_parts_used,
    service_activity_log,
    service_reports,
    inventory_documents,
    inventory_document_lines,
    inventory_ledger,
    stock_on_hand
CASCADE;

-- 2. DELETE MASTER DATA (Items, Customers, Suppliers, Categories)
TRUNCATE TABLE 
    items,
    customers,
    suppliers,
    item_categories
CASCADE;

-- 3. RESET COUNTERS
-- Important: We must reset the 'last_value' for all counters 
-- back to 0 so new records start from 1 again (e.g. INV-0001, JOB-0001)
UPDATE company_counters
SET last_value = 0;

UPDATE inv_doc_sequences
SET current_number = 0;

-- DONE! The system is now 100% clean and ready for real data.

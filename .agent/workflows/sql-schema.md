---
description: How to create SQL schema files for the Restaurant ERP
---

## Rules

1. **Always create each schema module as a separate `.sql` file** inside `supabase/`.
   - Do NOT combine multiple schemas into one file.
   - Example file names: `menu_recipes.sql`, `rbac.sql`, `inventory.sql`, `orders.sql`

2. **Every file must include at the top:**

   ```sql
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
   ```

3. **Include the `set_updated_at()` trigger function** at the top of each file:

   ```sql
   CREATE OR REPLACE FUNCTION set_updated_at()
   RETURNS TRIGGER AS $$
   BEGIN
     NEW.updated_at = now();
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql;
   ```

4. **For every table that has an `updated_at` column**, add a trigger:

   ```sql
   CREATE TRIGGER trg_<table_name>_updated
   BEFORE UPDATE ON <table_name>
   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
   ```

5. **Formatting rules:**
   - Clean column alignment (no excessive spacing)
   - No inline comments on column definitions — keep it clean
   - Indexes on separate lines after each table
   - Section headers with `-- =====================================================`

6. **Stock deduction functions** should use `GREATEST(..., 0)` to prevent negative stock.

7. **Recipe lookup priority:** variant-specific recipe first, then base recipe (variant_id IS NULL).

8. **File header format:**
   ```sql
   -- =====================================================
   -- <MODULE NAME> (FINAL PRODUCTION VERSION)
   -- =====================================================
   ```

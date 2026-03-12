-- ============================================================================
-- FIX: service_jobs.device_type CHECK constraint vs service_device_types mismatch
--
-- Root Cause:
--   The original migration created device_type with a static CHECK constraint
--   allowing only lowercase values: ('laptop','desktop','printer','phone',
--   'tablet','monitor','other').
--
--   However, the service_device_types lookup table (the authoritative source
--   the UI reads from) stores Title Case names: 'Laptop', 'Desktop', etc.
--   When users add custom types (e.g. 'CCTV Camera'), these also won't match.
--
--   The UI sets device_type = service_device_types.name (whatever case the
--   DB stores), so the static CHECK constraint is fundamentally incompatible
--   with a dynamic device type system.
--
-- Fix:
--   1. Drop the static CHECK constraint — service_device_types IS the validator.
--   2. Fix the column default to 'Laptop' (matches service_device_types seeds).
--   3. Ensure RLS policies exist on service_device_types so the form can read it.
-- ============================================================================

-- Step 1: Drop the conflicting static CHECK constraint
ALTER TABLE public.service_jobs
  DROP CONSTRAINT IF EXISTS service_jobs_device_type_check;

-- Step 2: Fix the column default to match service_device_types seed data
ALTER TABLE public.service_jobs
  ALTER COLUMN device_type SET DEFAULT 'Laptop';

-- Step 3: Ensure RLS policies on service_device_types
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'service_device_types' 
      AND policyname = 'sdt_select'
  ) THEN
    EXECUTE 'CREATE POLICY sdt_select ON service_device_types FOR SELECT
      USING (company_id IN (SELECT fn_user_company_ids()))';
    EXECUTE 'CREATE POLICY sdt_insert ON service_device_types FOR INSERT
      WITH CHECK (company_id IN (SELECT fn_user_company_ids()))';
    EXECUTE 'CREATE POLICY sdt_update ON service_device_types FOR UPDATE
      USING (company_id IN (SELECT fn_user_company_ids()))';
    EXECUTE 'CREATE POLICY sdt_delete ON service_device_types FOR DELETE
      USING (company_id IN (SELECT fn_user_company_ids()))';
  END IF;
END;
$$;

-- Step 4: Enable RLS on service_device_types (idempotent)
ALTER TABLE service_device_types ENABLE ROW LEVEL SECURITY;

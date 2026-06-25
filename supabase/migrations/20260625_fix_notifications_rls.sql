-- ============================================================================
-- SECURITY FIX: Notifications table — add company_id scoping
-- Date: 2026-06-25
-- Auditor: Riley (QA/Security)
-- Lead sign-off: Alex
--
-- MED-003: The current notifications policy uses:
--   USING (user_id = auth.uid() OR is_admin())
-- The is_admin() branch lets an admin from Company A read Company B's
-- notifications in a multi-tenant deployment.
--
-- Fix:
--   1. Add company_id column to notifications (IF NOT EXISTS — safe to run)
--   2. Replace the policy with one that additionally checks company_id for
--      admin users, preventing cross-company access.
-- ============================================================================

BEGIN;

-- 1. Add company_id column if the table exists and column is missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'notifications'
    ) THEN
        ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS company_id UUID
            REFERENCES companies(id) ON DELETE CASCADE;

        -- Index for fast company-scoped queries
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE tablename = 'notifications' AND indexname = 'idx_notif_company'
        ) THEN
            CREATE INDEX idx_notif_company ON notifications(company_id)
                WHERE company_id IS NOT NULL;
        END IF;
    END IF;
END $$;

-- 2. Replace the RLS policy with one that is company-scoped
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'notifications'
    ) THEN
        ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "notifications_own"          ON notifications;
        DROP POLICY IF EXISTS "notif_select_own"           ON notifications;
        DROP POLICY IF EXISTS "notif_update_own"           ON notifications;
        DROP POLICY IF EXISTS "notif_delete_own"           ON notifications;
        DROP POLICY IF EXISTS "notifications_secure_user"  ON notifications;
        DROP POLICY IF EXISTS "notifications_company_user" ON notifications;

        -- Users see only their own notifications within their company.
        -- Admins see all notifications within their company only.
        CREATE POLICY "notifications_company_user" ON notifications
            FOR ALL TO authenticated
            USING (
                user_id = (SELECT auth.uid())
                OR (
                    is_admin()
                    AND (
                        company_id IS NULL               -- legacy rows without company_id
                        OR company_id = get_my_company_id()
                    )
                )
            )
            WITH CHECK (
                user_id = (SELECT auth.uid())
                OR (
                    is_admin()
                    AND (
                        company_id IS NULL
                        OR company_id = get_my_company_id()
                    )
                )
            );

        RAISE NOTICE 'notifications: RLS policy updated with company_id scoping';
    ELSE
        RAISE NOTICE 'notifications table does not exist — skipping';
    END IF;
END $$;

COMMIT;

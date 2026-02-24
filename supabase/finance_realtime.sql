-- =====================================================
-- REALTIME REGISTRATION FOR FINANCE & REPORTS
-- =====================================================

-- Ensure the publication exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- Add relevant tables to the publication for real-time updates
-- Note: invoices and payments might already be added, but adding again is safe or we can check
ALTER PUBLICATION supabase_realtime ADD TABLE invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE invoice_items;
ALTER PUBLICATION supabase_realtime ADD TABLE payments;

-- Ensure RLS is enabled and policies allow reading (necessary for realtime)
-- (Policies are usually already set in billing_module.sql and billing.sql)

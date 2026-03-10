-- Add invoice_date column to invoices table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invoices' AND column_name = 'invoice_date') THEN
        ALTER TABLE invoices ADD COLUMN invoice_date DATE;
    END IF;
END $$;

-- Populate existing invoices with their created_at date
UPDATE invoices 
SET invoice_date = DATE(created_at)
WHERE invoice_date IS NULL;

-- ============================================================================
-- VISION-ERP: SEED COMPUTER SHOP CATEGORIES
-- ============================================================================
-- Run this script if you need to quickly populate missing categories for a 
-- computer shop ERP environment. This automatically links categories to 
-- your existing company ID.

INSERT INTO item_categories (company_id, name, is_active)
SELECT id, category_name, true
FROM companies
CROSS JOIN (
    VALUES
        ('Laptops & Notebooks'),
        ('Desktop Computers'),
        ('Processors (CPU)'),
        ('Motherboards'),
        ('Memory (RAM)'),
        ('Storage (HDD/SSD/NVMe)'),
        ('Graphics Cards (GPU)'),
        ('Power Supplies (PSU)'),
        ('PC Cases / Casing'),
        ('Cooling (Fans/Liquid Coolers)'),
        ('Monitors & Displays'),
        ('Keyboards & Mouse'),
        ('Networking (Routers/Switches)'),
        ('Printers & Scanners'),
        ('Cables & Adapters'),
        ('UPS & Surge Protectors'),
        ('Audio (Headsets/Speakers)'),
        ('Storage Media (Pen Drives/SD Cards)'),
        ('Software & OS Licenses'),
        ('Other Accessories')
) AS default_categories(category_name)
ON CONFLICT DO NOTHING;

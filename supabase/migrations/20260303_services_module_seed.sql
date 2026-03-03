-- ============================================================================
-- SERVICES MODULE: Register in system_modules + Seed Data
-- ============================================================================

-- Register SERVICES as a system module
INSERT INTO system_modules (company_id, code, name, description, is_enabled, icon, sort_order)
SELECT
    c.id,
    'SERVICES',
    'Services',
    'Laptop/Device Repair & Service Management',
    true,
    'build',
    60
FROM companies c
WHERE NOT EXISTS (
    SELECT 1 FROM system_modules sm WHERE sm.company_id = c.id AND sm.code = 'SERVICES'
);

-- ============================================================================
-- SEED: Common Issue Templates
-- ============================================================================
INSERT INTO service_issue_templates (company_id, category, title, description, recommended_fix, default_cost)
SELECT c.id, t.category, t.title, t.description, t.fix, t.cost
FROM companies c
CROSS JOIN (VALUES
    ('hardware', 'RAM Failure', 'One or more RAM modules not detected or failing', 'Replace RAM module', 3500),
    ('hardware', 'Hard Drive Failure', 'HDD/SSD not detected or showing bad sectors', 'Replace storage drive + data recovery', 8000),
    ('hardware', 'Overheating', 'Device overheating and shutting down', 'Clean internals + replace thermal paste', 2500),
    ('hardware', 'Keyboard Malfunction', 'Keys not responding or ghost typing', 'Replace keyboard assembly', 4000),
    ('hardware', 'Battery Not Charging', 'Battery not charging or draining quickly', 'Replace battery + check charging circuit', 5000),
    ('hardware', 'Screen Damage', 'Cracked or non-functional display', 'Replace LCD/LED panel', 12000),
    ('hardware', 'Motherboard Issue', 'Board-level fault detected', 'Board repair or replacement', 15000),
    ('hardware', 'Fan Noise/Failure', 'Cooling fan making noise or not spinning', 'Replace cooling fan', 2000),
    ('display', 'No Display Output', 'Screen remains black, no output', 'Check GPU/cable/inverter', 3000),
    ('display', 'Screen Flickering', 'Display flickering intermittently', 'Replace display cable or inverter', 2500),
    ('power', 'Not Powering On', 'Device does not power on at all', 'Check power jack/board/adapter', 3500),
    ('power', 'Charging Port Damaged', 'Charging port loose or broken', 'Replace charging port', 3000),
    ('software', 'OS Corruption', 'Operating system not booting properly', 'Reinstall OS + driver setup', 2000),
    ('software', 'Virus/Malware', 'System infected with malware', 'Full scan + cleanup + security setup', 1500),
    ('software', 'Slow Performance', 'System running very slow', 'Cleanup + optimize + RAM/SSD upgrade recommendation', 1500),
    ('software', 'BSOD / Blue Screen', 'Frequent blue screen errors', 'Diagnose driver/hardware conflict', 2500),
    ('network', 'Wi-Fi Not Working', 'Cannot connect to wireless networks', 'Check/replace Wi-Fi card + driver update', 2000),
    ('network', 'Ethernet Port Dead', 'LAN port not functioning', 'Replace ethernet port or USB adapter', 1500),
    ('storage', 'Data Recovery', 'Customer needs data recovered from failed drive', 'Professional data recovery', 10000),
    ('other', 'Physical Damage', 'Casing cracked or hinges broken', 'Replace casing/hinge assembly', 5000)
) AS t(category, title, description, fix, cost)
WHERE NOT EXISTS (
    SELECT 1 FROM service_issue_templates sit WHERE sit.company_id = c.id AND sit.title = t.title
);

-- ============================================================================
-- VISION CORE ERP: SERVICES MODULE â€” COMPLETE MIGRATION
-- Copy-paste this entire file into Supabase SQL Editor and run it
-- ============================================================================

-- Ensure extension for UUID generation is enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Helper Function to get user company IDs
CREATE OR REPLACE FUNCTION public.fn_user_company_ids()
RETURNS SETOF UUID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT DISTINCT b.company_id 
    FROM user_branches ub
    JOIN branches b ON b.id = ub.branch_id
    WHERE ub.user_id = auth.uid();
$$;

-- â”€â”€â”€ 1. SERVICE JOBS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE TABLE IF NOT EXISTS service_jobs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    branch_id       UUID REFERENCES branches(id) ON DELETE SET NULL,
    job_no          TEXT NOT NULL,
    customer_id     UUID REFERENCES customers(id) ON DELETE SET NULL,
    device_type     TEXT NOT NULL DEFAULT 'Laptop',
    brand           TEXT,
    model           TEXT,
    serial_no       TEXT,
    accessories_received JSONB DEFAULT '[]'::jsonb,
    issue_reported_by_customer TEXT,
    inspection_notes TEXT,
    priority        TEXT NOT NULL DEFAULT 'normal'
                    CHECK (priority IN ('low','normal','high','urgent')),
    assigned_technician_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status          TEXT NOT NULL DEFAULT 'received'
                    CHECK (status IN (
                        'received','diagnosing','waiting_approval',
                        'approved','repairing','ready','delivered','closed','cancelled'
                    )),
    received_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    estimated_fix_date  DATE,
    delivered_date      DATE,
    warranty_days   INT DEFAULT 0,
    is_approved     BOOLEAN DEFAULT false,
    approved_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    approved_at     TIMESTAMPTZ,
    total_estimated_cost NUMERIC(14,2) DEFAULT 0,
    total_final_cost     NUMERIC(14,2) DEFAULT 0,
    payment_status  TEXT NOT NULL DEFAULT 'unpaid'
                    CHECK (payment_status IN ('unpaid','partial','paid')),
    customer_signature_url TEXT,
    created_by      UUID REFERENCES auth.users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, job_no)
);

CREATE INDEX IF NOT EXISTS idx_service_jobs_company    ON service_jobs(company_id);
CREATE INDEX IF NOT EXISTS idx_service_jobs_no         ON service_jobs(company_id, job_no);
CREATE INDEX IF NOT EXISTS idx_service_jobs_customer   ON service_jobs(customer_id);
CREATE INDEX IF NOT EXISTS idx_service_jobs_status     ON service_jobs(status);
CREATE INDEX IF NOT EXISTS idx_service_jobs_serial     ON service_jobs(serial_no);
CREATE INDEX IF NOT EXISTS idx_service_jobs_dates      ON service_jobs(received_date, estimated_fix_date);
CREATE INDEX IF NOT EXISTS idx_service_jobs_technician ON service_jobs(assigned_technician_id);

-- â”€â”€â”€ 2. SERVICE DIAGNOSIS ITEMS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE TABLE IF NOT EXISTS service_diagnosis_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID NOT NULL REFERENCES service_jobs(id) ON DELETE CASCADE,
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    category        TEXT DEFAULT 'hardware'
                    CHECK (category IN ('hardware','software','power','display','network','storage','other')),
    error_title     TEXT NOT NULL,
    error_description TEXT,
    severity        TEXT DEFAULT 'medium'
                    CHECK (severity IN ('low','medium','high')),
    recommended_fix TEXT,
    estimated_cost  NUMERIC(14,2) DEFAULT 0,
    final_cost      NUMERIC(14,2) DEFAULT 0,
    is_fixed        BOOLEAN DEFAULT false,
    fixed_notes     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sdi_job ON service_diagnosis_items(job_id);

-- â”€â”€â”€ 3. SERVICE PARTS USED â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE TABLE IF NOT EXISTS service_parts_used (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID NOT NULL REFERENCES service_jobs(id) ON DELETE CASCADE,
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    item_id         UUID REFERENCES items(id) ON DELETE SET NULL,
    item_name       TEXT,
    qty             NUMERIC(14,3) NOT NULL DEFAULT 1 CHECK (qty > 0),
    unit_price      NUMERIC(14,2) NOT NULL DEFAULT 0,
    total           NUMERIC(14,2) NOT NULL DEFAULT 0,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_spu_job ON service_parts_used(job_id);

-- â”€â”€â”€ 4. SERVICE ACTIVITY LOG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE TABLE IF NOT EXISTS service_activity_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID NOT NULL REFERENCES service_jobs(id) ON DELETE CASCADE,
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    action          TEXT NOT NULL
                    CHECK (action IN (
                        'status_change','note_added','report_generated',
                        'approval','payment_update','diagnosis_added',
                        'part_added','assignment_change','created'
                    )),
    description     TEXT,
    meta            JSONB DEFAULT '{}'::jsonb,
    created_by      UUID REFERENCES auth.users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sal_job ON service_activity_log(job_id);
CREATE INDEX IF NOT EXISTS idx_sal_created ON service_activity_log(created_at);

-- â”€â”€â”€ 5. SERVICE REPORTS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE TABLE IF NOT EXISTS service_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID NOT NULL REFERENCES service_jobs(id) ON DELETE CASCADE,
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_type     TEXT NOT NULL DEFAULT 'inspection'
                    CHECK (report_type IN ('inspection','final','other')),
    report_no       TEXT NOT NULL,
    content_json    JSONB DEFAULT '{}'::jsonb,
    pdf_url         TEXT,
    generated_by    UUID REFERENCES auth.users(id),
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, report_no)
);

CREATE INDEX IF NOT EXISTS idx_sr_job ON service_reports(job_id);

-- â”€â”€â”€ 6. SERVICE ISSUE TEMPLATES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE TABLE IF NOT EXISTS service_issue_templates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    category        TEXT DEFAULT 'hardware',
    title           TEXT NOT NULL,
    description     TEXT,
    recommended_fix TEXT,
    default_cost    NUMERIC(14,2) DEFAULT 0,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 7. AUTO JOB NUMBER GENERATION
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_assign_service_job_no()
RETURNS TRIGGER AS $$
DECLARE
    v_counter INT;
    v_year   TEXT;
BEGIN
    IF NEW.job_no IS NULL OR NEW.job_no = '' THEN
        v_year := to_char(now(), 'YYYY');
        v_counter := get_next_counter_value(NEW.company_id, 'service_job');
        NEW.job_no := 'SV-' || v_year || '-' || lpad(v_counter::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_service_job_no ON service_jobs;
CREATE TRIGGER trg_service_job_no
    BEFORE INSERT ON service_jobs
    FOR EACH ROW EXECUTE FUNCTION trg_assign_service_job_no();

-- Auto report number
CREATE OR REPLACE FUNCTION trg_assign_service_report_no()
RETURNS TRIGGER AS $$
DECLARE
    v_counter INT;
    v_year   TEXT;
BEGIN
    IF NEW.report_no IS NULL OR NEW.report_no = '' THEN
        v_year := to_char(now(), 'YYYY');
        v_counter := get_next_counter_value(NEW.company_id, 'service_report');
        NEW.report_no := 'SR-' || v_year || '-' || lpad(v_counter::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_service_report_no ON service_reports;
CREATE TRIGGER trg_service_report_no
    BEFORE INSERT ON service_reports
    FOR EACH ROW EXECUTE FUNCTION trg_assign_service_report_no();


-- ============================================================================
-- 8. UPDATED_AT TRIGGERS
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_service_jobs_updated ON service_jobs;
CREATE TRIGGER trg_service_jobs_updated
    BEFORE UPDATE ON service_jobs
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_sdi_updated ON service_diagnosis_items;
CREATE TRIGGER trg_sdi_updated
    BEFORE UPDATE ON service_diagnosis_items
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();


-- ============================================================================
-- 9. ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE service_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_diagnosis_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_parts_used ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_issue_templates ENABLE ROW LEVEL SECURITY;

-- SERVICE JOBS
DROP POLICY IF EXISTS service_jobs_select ON service_jobs;
CREATE POLICY service_jobs_select ON service_jobs FOR SELECT
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS service_jobs_insert ON service_jobs;
CREATE POLICY service_jobs_insert ON service_jobs FOR INSERT
    WITH CHECK (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS service_jobs_update ON service_jobs;
CREATE POLICY service_jobs_update ON service_jobs FOR UPDATE
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS service_jobs_delete ON service_jobs;
CREATE POLICY service_jobs_delete ON service_jobs FOR DELETE
    USING (company_id IN (SELECT fn_user_company_ids()));

-- DIAGNOSIS ITEMS
DROP POLICY IF EXISTS sdi_select ON service_diagnosis_items;
CREATE POLICY sdi_select ON service_diagnosis_items FOR SELECT
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sdi_insert ON service_diagnosis_items;
CREATE POLICY sdi_insert ON service_diagnosis_items FOR INSERT
    WITH CHECK (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sdi_update ON service_diagnosis_items;
CREATE POLICY sdi_update ON service_diagnosis_items FOR UPDATE
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sdi_delete ON service_diagnosis_items;
CREATE POLICY sdi_delete ON service_diagnosis_items FOR DELETE
    USING (company_id IN (SELECT fn_user_company_ids()));

-- PARTS USED
DROP POLICY IF EXISTS spu_select ON service_parts_used;
CREATE POLICY spu_select ON service_parts_used FOR SELECT
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS spu_insert ON service_parts_used;
CREATE POLICY spu_insert ON service_parts_used FOR INSERT
    WITH CHECK (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS spu_update ON service_parts_used;
CREATE POLICY spu_update ON service_parts_used FOR UPDATE
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS spu_delete ON service_parts_used;
CREATE POLICY spu_delete ON service_parts_used FOR DELETE
    USING (company_id IN (SELECT fn_user_company_ids()));

-- ACTIVITY LOG
DROP POLICY IF EXISTS sal_select ON service_activity_log;
CREATE POLICY sal_select ON service_activity_log FOR SELECT
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sal_insert ON service_activity_log;
CREATE POLICY sal_insert ON service_activity_log FOR INSERT
    WITH CHECK (company_id IN (SELECT fn_user_company_ids()));

-- REPORTS
DROP POLICY IF EXISTS sr_select ON service_reports;
CREATE POLICY sr_select ON service_reports FOR SELECT
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sr_insert ON service_reports;
CREATE POLICY sr_insert ON service_reports FOR INSERT
    WITH CHECK (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sr_update ON service_reports;
CREATE POLICY sr_update ON service_reports FOR UPDATE
    USING (company_id IN (SELECT fn_user_company_ids()));

-- ISSUE TEMPLATES
DROP POLICY IF EXISTS sit_select ON service_issue_templates;
CREATE POLICY sit_select ON service_issue_templates FOR SELECT
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sit_insert ON service_issue_templates;
CREATE POLICY sit_insert ON service_issue_templates FOR INSERT
    WITH CHECK (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sit_update ON service_issue_templates;
CREATE POLICY sit_update ON service_issue_templates FOR UPDATE
    USING (company_id IN (SELECT fn_user_company_ids()));
DROP POLICY IF EXISTS sit_delete ON service_issue_templates;
CREATE POLICY sit_delete ON service_issue_templates FOR DELETE
    USING (company_id IN (SELECT fn_user_company_ids()));


-- ============================================================================
-- 10. RPC: SERVICE DASHBOARD KPIS
-- ============================================================================
CREATE OR REPLACE FUNCTION get_service_dashboard(p_company_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'open_jobs',       COALESCE(SUM(CASE WHEN status NOT IN ('delivered','closed','cancelled') THEN 1 ELSE 0 END), 0),
        'due_today',       COALESCE(SUM(CASE WHEN estimated_fix_date = CURRENT_DATE AND status NOT IN ('delivered','closed','cancelled') THEN 1 ELSE 0 END), 0),
        'overdue',         COALESCE(SUM(CASE WHEN estimated_fix_date < CURRENT_DATE AND status NOT IN ('delivered','closed','cancelled') THEN 1 ELSE 0 END), 0),
        'waiting_approval',COALESCE(SUM(CASE WHEN status = 'waiting_approval' THEN 1 ELSE 0 END), 0),
        'ready_delivery',  COALESCE(SUM(CASE WHEN status = 'ready' THEN 1 ELSE 0 END), 0),
        'delivered_month',  COALESCE(SUM(CASE WHEN status IN ('delivered','closed') AND delivered_date >= date_trunc('month', CURRENT_DATE) THEN 1 ELSE 0 END), 0),
        'revenue_month',   COALESCE(SUM(CASE WHEN status IN ('delivered','closed') AND delivered_date >= date_trunc('month', CURRENT_DATE) THEN total_final_cost ELSE 0 END), 0),
        'total_jobs',      COUNT(*)
    ) INTO v_result
    FROM service_jobs
    WHERE company_id = p_company_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;


-- ============================================================================
-- 11. SEED: Register Services module + Common Issue Templates
-- ============================================================================
INSERT INTO system_modules (company_id, code, name, description, is_enabled, icon, sort_order)
SELECT c.id, 'SERVICES', 'Services', 'Laptop/Device Repair & Service Management', true, 'build', 60
FROM companies c
WHERE NOT EXISTS (
    SELECT 1 FROM system_modules sm WHERE sm.company_id = c.id AND sm.code = 'SERVICES'
);

INSERT INTO service_issue_templates (company_id, category, title, description, recommended_fix, default_cost)
SELECT c.id, t.category, t.title, t.description, t.fix, t.cost
FROM companies c
CROSS JOIN (VALUES
    ('hardware', 'RAM Failure', 'RAM modules not detected or failing', 'Replace RAM module', 3500),
    ('hardware', 'Hard Drive Failure', 'HDD/SSD not detected or bad sectors', 'Replace storage drive', 8000),
    ('hardware', 'Overheating', 'Device overheating and shutting down', 'Clean internals + thermal paste', 2500),
    ('hardware', 'Keyboard Malfunction', 'Keys not responding or ghost typing', 'Replace keyboard assembly', 4000),
    ('hardware', 'Battery Not Charging', 'Battery not charging or draining fast', 'Replace battery', 5000),
    ('hardware', 'Screen Damage', 'Cracked or non-functional display', 'Replace LCD/LED panel', 12000),
    ('hardware', 'Fan Noise/Failure', 'Cooling fan noisy or not spinning', 'Replace cooling fan', 2000),
    ('display', 'No Display Output', 'Screen remains black', 'Check GPU/cable/inverter', 3000),
    ('display', 'Screen Flickering', 'Display flickering intermittently', 'Replace display cable', 2500),
    ('power', 'Not Powering On', 'Device does not power on', 'Check power jack/board/adapter', 3500),
    ('power', 'Charging Port Damaged', 'Charging port loose or broken', 'Replace charging port', 3000),
    ('software', 'OS Corruption', 'OS not booting properly', 'Reinstall OS + drivers', 2000),
    ('software', 'Virus/Malware', 'System infected with malware', 'Full scan + cleanup', 1500),
    ('software', 'Slow Performance', 'System running very slow', 'Cleanup + optimize', 1500),
    ('network', 'Wi-Fi Not Working', 'Cannot connect to wireless', 'Check/replace Wi-Fi card', 2000),
    ('storage', 'Data Recovery', 'Data recovery from failed drive', 'Professional data recovery', 10000)
) AS t(category, title, description, fix, cost)
WHERE NOT EXISTS (
    SELECT 1 FROM service_issue_templates sit WHERE sit.company_id = c.id AND sit.title = t.title
);


-- ============================================================================
-- 12. EXTEND GLOBAL SEARCH TO INCLUDE SERVICE JOBS
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_service_jobs_no_trgm ON service_jobs USING gin (job_no gin_trgm_ops);

DROP FUNCTION IF EXISTS global_search(UUID, TEXT, INT);

CREATE OR REPLACE FUNCTION global_search(
    p_company_id UUID,
    q TEXT,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    entity_type TEXT,
    entity_id UUID,
    title TEXT,
    subtitle TEXT,
    extra JSONB,
    rank INT
) AS $$
DECLARE
    v_query TEXT;
BEGIN
    v_query := trim(q);
    IF v_query IS NULL OR length(v_query) < 2 THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH all_results AS (
        -- ITEMS
        (SELECT 'item'::TEXT, i.id, i.name,
            'SKU: ' || i.code || COALESCE(' | Barcode: ' || i.barcode, ''),
            jsonb_build_object('code', i.code, 'url', '/inventory/items/' || i.id),
            CASE WHEN i.code = v_query OR i.barcode = v_query THEN 100 WHEN i.name ILIKE v_query THEN 90 WHEN i.name ILIKE v_query || '%' THEN 80 ELSE 50 END,
            i.updated_at
        FROM items i WHERE i.company_id = p_company_id
          AND (i.name ILIKE '%' || v_query || '%' OR i.code ILIKE v_query || '%' OR i.barcode ILIKE v_query || '%')
        ORDER BY 7 DESC LIMIT p_limit)

        UNION ALL

        -- INVOICES
        (SELECT 'invoice'::TEXT, inv.id, inv.invoice_no,
            'Date: ' || inv.invoice_date::TEXT || ' | Total: ' || inv.total::TEXT,
            jsonb_build_object('status', inv.status, 'url', '/billing/invoices/' || inv.id),
            CASE WHEN inv.invoice_no = v_query THEN 100 WHEN inv.invoice_no ILIKE v_query || '%' THEN 85 ELSE 50 END,
            inv.updated_at
        FROM invoices inv WHERE inv.company_id = p_company_id AND inv.invoice_no ILIKE '%' || v_query || '%'
        ORDER BY 7 DESC LIMIT p_limit)

        UNION ALL

        -- CUSTOMERS
        (SELECT 'customer'::TEXT, c.id, c.name,
            'Code: ' || c.customer_code || ' | Phone: ' || COALESCE(c.phone, 'N/A'),
            jsonb_build_object('phone', c.phone, 'code', c.customer_code, 'url', '/customers/' || c.id),
            CASE WHEN c.name ILIKE v_query THEN 100 WHEN c.customer_code = v_query OR c.phone = v_query THEN 95 WHEN c.name ILIKE v_query || '%' THEN 85 ELSE 50 END,
            c.updated_at
        FROM customers c WHERE c.company_id = p_company_id
          AND (c.name ILIKE '%' || v_query || '%' OR c.phone ILIKE v_query || '%' OR c.customer_code ILIKE v_query || '%')
        ORDER BY 7 DESC LIMIT p_limit)

        UNION ALL

        -- SERVICE JOBS
        (SELECT 'service_job'::TEXT, sj.id, sj.job_no,
            COALESCE(sj.brand, '') || ' ' || COALESCE(sj.model, '') || ' | S/N: ' || COALESCE(sj.serial_no, 'N/A') || ' | ' || sj.status,
            jsonb_build_object('status', sj.status, 'device_type', sj.device_type, 'serial_no', sj.serial_no, 'url', '/services/jobs/' || sj.id),
            CASE WHEN sj.job_no = v_query THEN 100 WHEN sj.serial_no = v_query THEN 95 WHEN sj.job_no ILIKE v_query || '%' THEN 85 ELSE 50 END,
            sj.updated_at
        FROM service_jobs sj WHERE sj.company_id = p_company_id
          AND (sj.job_no ILIKE '%' || v_query || '%' OR sj.serial_no ILIKE '%' || v_query || '%' OR sj.brand ILIKE '%' || v_query || '%' OR sj.model ILIKE '%' || v_query || '%')
        ORDER BY 7 DESC LIMIT p_limit)
    )
    SELECT ar.entity_type, ar.entity_id, ar.title, ar.subtitle, ar.extra, ar.rank
    FROM all_results ar
    ORDER BY ar.rank DESC, ar.updated_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;





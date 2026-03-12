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
-- ============================================================================
-- ERP MODULE: SERVICES (LAPTOP/DEVICE REPAIR & SERVICE MANAGEMENT)
-- Vision Core ERP v2
-- Date: 2026-03-03
-- ============================================================================

-- ─── 1. SERVICE JOBS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS service_jobs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    branch_id       UUID REFERENCES branches(id) ON DELETE SET NULL,
    job_no          TEXT NOT NULL,

    -- Customer
    customer_id     UUID REFERENCES customers(id) ON DELETE SET NULL,

    -- Device Info
    device_type     TEXT NOT NULL DEFAULT 'Laptop',
    brand           TEXT,
    model           TEXT,
    serial_no       TEXT,
    accessories_received JSONB DEFAULT '[]'::jsonb,   -- ["charger","bag","mouse"]

    -- Issue
    issue_reported_by_customer TEXT,
    inspection_notes TEXT,

    -- Assignment & Priority
    priority        TEXT NOT NULL DEFAULT 'normal'
                    CHECK (priority IN ('low','normal','high','urgent')),
    assigned_technician_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

    -- Status Workflow
    status          TEXT NOT NULL DEFAULT 'received'
                    CHECK (status IN (
                        'received','diagnosing','waiting_approval',
                        'approved','repairing','ready','delivered','closed','cancelled'
                    )),

    -- Dates
    received_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    estimated_fix_date  DATE,
    delivered_date      DATE,

    -- Warranty
    warranty_days   INT DEFAULT 0,

    -- Approval
    is_approved     BOOLEAN DEFAULT false,
    approved_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    approved_at     TIMESTAMPTZ,

    -- Cost
    total_estimated_cost NUMERIC(14,2) DEFAULT 0,
    total_final_cost     NUMERIC(14,2) DEFAULT 0,

    -- Payment
    payment_status  TEXT NOT NULL DEFAULT 'unpaid'
                    CHECK (payment_status IN ('unpaid','partial','paid')),

    -- Signature
    customer_signature_url TEXT,

    -- Audit
    created_by      UUID REFERENCES auth.users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(company_id, job_no)
);

-- Indexes
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

-- Reuse company_counters table (already exists from billing module)
-- counter_type = 'service_job'

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

-- Helper: get user's company IDs

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




import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from './auth'

export const useServiceStore = defineStore('services', () => {
  const authStore = useAuthStore()
  const loading = ref(false)
  const jobs = ref([])
  const currentJob = ref(null)
  const dashboardKpis = ref({})
  const diagnosisItems = ref([])
  const partsUsed = ref([])
  const activityLog = ref([])
  const reports = ref([])
  const issueTemplates = ref([])

  const getCompanyId = () => authStore.currentBranch?.company_id

  // ─── STATUS WORKFLOW ────────────────────────────────────────────────────
  const STATUS_FLOW = {
    received: ['diagnosing', 'cancelled'],
    diagnosing: ['waiting_approval', 'repairing', 'cancelled'],
    waiting_approval: ['approved', 'cancelled'],
    approved: ['repairing'],
    repairing: ['ready', 'waiting_approval'],
    ready: ['delivered'],
    delivered: ['closed'],
    closed: [],
    cancelled: ['received'], // re-open
  }

  const STATUS_LABELS = {
    received: 'Received',
    diagnosing: 'Diagnosing',
    waiting_approval: 'Waiting Approval',
    approved: 'Approved',
    repairing: 'Repairing',
    ready: 'Ready for Delivery',
    delivered: 'Delivered',
    closed: 'Closed',
    cancelled: 'Cancelled',
  }

  const STATUS_COLORS = {
    received: 'blue-grey',
    diagnosing: 'blue',
    waiting_approval: 'orange',
    approved: 'teal',
    repairing: 'purple',
    ready: 'green',
    delivered: 'positive',
    closed: 'grey',
    cancelled: 'negative',
  }

  const PRIORITY_COLORS = {
    low: 'grey',
    normal: 'blue',
    high: 'orange',
    urgent: 'red',
  }

  // ─── DASHBOARD KPIs ────────────────────────────────────────────────────
  async function fetchDashboard() {
    const companyId = getCompanyId()
    if (!companyId) return
    loading.value = true
    try {
      const { data, error } = await supabase.rpc('get_service_dashboard', {
        p_company_id: companyId,
      })
      if (error) throw error
      dashboardKpis.value = data || {}
    } catch (err) {
      console.error('[ServiceStore] Dashboard fetch failed:', JSON.stringify(err, null, 2))
    } finally {
      loading.value = false
    }
  }

  // ─── FETCH JOBS ─────────────────────────────────────────────────────────
  async function fetchJobs(filters = {}) {
    const companyId = getCompanyId()
    if (!companyId) return
    loading.value = true
    try {
      let query = supabase
        .from('service_jobs')
        .select(
          `
          *,
          customer:customers(id, name, phone, customer_code)
        `,
        )
        .eq('company_id', companyId)
        .order('created_at', { ascending: false })

      if (filters.status) query = query.eq('status', filters.status)
      if (filters.priority) query = query.eq('priority', filters.priority)
      if (filters.device_type) query = query.eq('device_type', filters.device_type)
      if (filters.technician_id) query = query.eq('assigned_technician_id', filters.technician_id)
      if (filters.from_date) query = query.gte('received_date', filters.from_date)
      if (filters.to_date) query = query.lte('received_date', filters.to_date)
      if (filters.overdue) {
        query = query
          .lt('estimated_fix_date', new Date().toISOString().split('T')[0])
          .not('status', 'in', '(delivered,closed,cancelled)')
      }
      if (filters.search) {
        const qStr = filters.search.trim()
        const q = `%${qStr}%`

        // Find matching customer IDs first
        const { data: custData } = await supabase
          .from('customers')
          .select('id')
          .eq('company_id', companyId)
          .or(`name.ilike.${q},phone.ilike.${q},customer_code.ilike.${q},email.ilike.${q}`)

        const custIds = (custData || []).map((c) => c.id)

        let orString = `job_no.ilike.${q},serial_no.ilike.${q},brand.ilike.${q},model.ilike.${q},issue_reported_by_customer.ilike.${q}`
        if (custIds.length > 0) {
          const uuidQueries = custIds.map((id) => `customer_id.eq.${id}`).join(',')
          orString += `,${uuidQueries}`
        }

        query = query.or(orString)
      }

      const { data, error } = await query
      if (error) throw error
      jobs.value = data || []
    } catch (err) {
      console.error('[ServiceStore] Fetch jobs failed:', JSON.stringify(err, null, 2))
      throw err
    } finally {
      loading.value = false
    }
  }

  // ─── FETCH SINGLE JOB ──────────────────────────────────────────────────
  async function fetchJob(jobId) {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('service_jobs')
        .select(
          `
          *,
          customer:customers(id, name, phone, email, address, customer_code)
        `,
        )
        .eq('id', jobId)
        .single()
      if (error) throw error
      currentJob.value = data
      // Also fetch related data in parallel
      await Promise.all([
        fetchDiagnosis(jobId),
        fetchParts(jobId),
        fetchActivityLog(jobId),
        fetchReports(jobId),
      ])
    } catch (err) {
      console.error('[ServiceStore] Fetch job failed:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // ─── CREATE JOB ─────────────────────────────────────────────────────────
  async function createJob(jobData) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Company ID missing')
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('service_jobs')
        .insert({
          company_id: companyId,
          branch_id: authStore.currentBranch?.id || null,
          customer_id: jobData.customer_id || null,
          device_type: jobData.device_type || 'laptop',
          brand: jobData.brand || null,
          model: jobData.model || null,
          serial_no: jobData.serial_no || null,
          accessories_received: jobData.accessories_received || [],
          issue_reported_by_customer: jobData.issue_reported || null,
          inspection_notes: jobData.inspection_notes || null,
          priority: jobData.priority || 'normal',
          assigned_technician_id: jobData.technician_id || null,
          estimated_fix_date: jobData.estimated_fix_date || null,
          warranty_days: jobData.warranty_days || 0,
          created_by: authStore.user?.id,
        })
        .select()
        .single()
      if (error) throw error

      // Log creation
      await logActivity(data.id, companyId, 'created', 'Service job created', {
        job_no: data.job_no,
      })

      return data
    } catch (err) {
      console.error('[ServiceStore] Create job failed:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // ─── UPDATE JOB ─────────────────────────────────────────────────────────
  async function updateJob(jobId, updates) {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('service_jobs')
        .update(updates)
        .eq('id', jobId)
        .select()
        .single()
      if (error) throw error
      currentJob.value = data
      return data
    } catch (err) {
      console.error('[ServiceStore] Update job failed:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // ─── UPDATE STATUS ──────────────────────────────────────────────────────
  async function updateStatus(jobId, newStatus, notes = '') {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Company ID missing')
    loading.value = true
    try {
      const updates = { status: newStatus }
      if (newStatus === 'delivered') updates.delivered_date = new Date().toISOString().split('T')[0]
      if (newStatus === 'approved') {
        updates.is_approved = true
        updates.approved_by = authStore.user?.id
        updates.approved_at = new Date().toISOString()
      }

      const { data, error } = await supabase
        .from('service_jobs')
        .update(updates)
        .eq('id', jobId)
        .select()
        .single()
      if (error) throw error
      currentJob.value = data

      await logActivity(jobId, companyId, 'status_change', `Status → ${STATUS_LABELS[newStatus]}`, {
        from: currentJob.value?.status,
        to: newStatus,
        notes,
      })

      return data
    } catch (err) {
      console.error('[ServiceStore] Status update failed:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // ─── UPDATE PAYMENT STATUS ──────────────────────────────────────────────
  async function updatePaymentStatus(jobId, newStatus) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Company ID missing')
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('service_jobs')
        .update({ payment_status: newStatus })
        .eq('id', jobId)
        .select()
        .single()
      if (error) throw error

      if (currentJob.value && currentJob.value.id === jobId) {
        currentJob.value.payment_status = newStatus
      }

      await logActivity(jobId, companyId, 'payment_update', `Payment marked as ${newStatus}`)

      return data
    } catch (err) {
      console.error('[ServiceStore] Payment status update failed:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // ─── DIAGNOSIS ITEMS ────────────────────────────────────────────────────
  async function fetchDiagnosis(jobId) {
    const { data, error } = await supabase
      .from('service_diagnosis_items')
      .select('*')
      .eq('job_id', jobId)
      .order('created_at')
    if (error) throw error
    diagnosisItems.value = data || []
  }

  async function addDiagnosis(jobId, item) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Company ID missing')
    const { data, error } = await supabase
      .from('service_diagnosis_items')
      .insert({
        job_id: jobId,
        company_id: companyId,
        ...item,
      })
      .select()
      .single()
    if (error) throw error
    diagnosisItems.value.push(data)

    await logActivity(jobId, companyId, 'diagnosis_added', `Diagnosis: ${item.error_title}`)

    // Recalculate estimated cost
    await recalcCosts(jobId)
    return data
  }

  async function updateDiagnosis(itemId, updates) {
    const { data, error } = await supabase
      .from('service_diagnosis_items')
      .update(updates)
      .eq('id', itemId)
      .select()
      .single()
    if (error) throw error
    const idx = diagnosisItems.value.findIndex((d) => d.id === itemId)
    if (idx >= 0) diagnosisItems.value[idx] = data

    // Recalculate costs
    if (data.job_id) await recalcCosts(data.job_id)
    return data
  }

  async function deleteDiagnosis(itemId) {
    const item = diagnosisItems.value.find((d) => d.id === itemId)
    const { error } = await supabase.from('service_diagnosis_items').delete().eq('id', itemId)
    if (error) throw error
    diagnosisItems.value = diagnosisItems.value.filter((d) => d.id !== itemId)
    if (item?.job_id) await recalcCosts(item.job_id)
  }

  // ─── PARTS USED ────────────────────────────────────────────────────────
  async function fetchParts(jobId) {
    const { data, error } = await supabase
      .from('service_parts_used')
      .select('*, item:items(id, name, code)')
      .eq('job_id', jobId)
      .order('created_at')
    if (error) throw error
    partsUsed.value = data || []
  }

  async function addPart(jobId, part) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Company ID missing')
    const { data, error } = await supabase
      .from('service_parts_used')
      .insert({
        job_id: jobId,
        company_id: companyId,
        item_id: part.item_id || null,
        item_name: part.item_name || part.description,
        qty: part.qty,
        unit_price: part.unit_price,
        total: part.qty * part.unit_price,
        notes: part.notes || null,
      })
      .select('*, item:items(id, name, code)')
      .single()
    if (error) throw error
    partsUsed.value.push(data)

    await logActivity(jobId, companyId, 'part_added', `Part: ${part.item_name || part.description}`)
    await recalcCosts(jobId)
    return data
  }

  async function deletePart(partId) {
    const part = partsUsed.value.find((p) => p.id === partId)
    const { error } = await supabase.from('service_parts_used').delete().eq('id', partId)
    if (error) throw error
    partsUsed.value = partsUsed.value.filter((p) => p.id !== partId)
    if (part?.job_id) await recalcCosts(part.job_id)
  }

  // ─── RECALCULATE COSTS ─────────────────────────────────────────────────
  async function recalcCosts(jobId) {
    const diagTotal = diagnosisItems.value.reduce(
      (sum, d) => sum + Number(d.estimated_cost || 0),
      0,
    )
    const diagFinal = diagnosisItems.value.reduce((sum, d) => sum + Number(d.final_cost || 0), 0)
    const partsTotal = partsUsed.value.reduce((sum, p) => sum + Number(p.total || 0), 0)

    const estimated = diagTotal + partsTotal
    const final = diagFinal + partsTotal

    await supabase
      .from('service_jobs')
      .update({
        total_estimated_cost: estimated,
        total_final_cost: final,
      })
      .eq('id', jobId)

    if (currentJob.value && currentJob.value.id === jobId) {
      currentJob.value.total_estimated_cost = estimated
      currentJob.value.total_final_cost = final
    }
  }

  // ─── ACTIVITY LOG ──────────────────────────────────────────────────────
  async function fetchActivityLog(jobId) {
    const { data, error } = await supabase
      .from('service_activity_log')
      .select('*')
      .eq('job_id', jobId)
      .order('created_at', { ascending: false })
    if (error) throw error
    activityLog.value = data || []
  }

  async function logActivity(jobId, companyId, action, description, meta = {}) {
    try {
      await supabase.from('service_activity_log').insert({
        job_id: jobId,
        company_id: companyId,
        action,
        description,
        meta,
        created_by: authStore.user?.id,
      })
    } catch (err) {
      console.warn('[ServiceStore] Activity log failed:', err)
    }
  }

  // ─── REPORTS ────────────────────────────────────────────────────────────
  async function fetchReports(jobId) {
    const { data, error } = await supabase
      .from('service_reports')
      .select('*')
      .eq('job_id', jobId)
      .order('generated_at', { ascending: false })
    if (error) throw error
    reports.value = data || []
  }

  async function createReport(jobId, reportType, contentJson) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Company ID missing')
    const { data, error } = await supabase
      .from('service_reports')
      .insert({
        job_id: jobId,
        company_id: companyId,
        report_type: reportType,
        content_json: contentJson,
        generated_by: authStore.user?.id,
      })
      .select()
      .single()
    if (error) throw error
    reports.value.unshift(data)

    await logActivity(jobId, companyId, 'report_generated', `Report: ${reportType}`, {
      report_id: data.id,
      report_no: data.report_no,
    })
    return data
  }

  // ─── ISSUE TEMPLATES ────────────────────────────────────────────────────
  async function fetchIssueTemplates() {
    const companyId = getCompanyId()
    if (!companyId) return
    const { data, error } = await supabase
      .from('service_issue_templates')
      .select('*')
      .eq('company_id', companyId)
      .eq('is_active', true)
      .order('category, title')
    if (error) throw error
    issueTemplates.value = data || []
  }

  return {
    // State
    loading,
    jobs,
    currentJob,
    dashboardKpis,
    diagnosisItems,
    partsUsed,
    activityLog,
    reports,
    issueTemplates,

    // Constants
    STATUS_FLOW,
    STATUS_LABELS,
    STATUS_COLORS,
    PRIORITY_COLORS,

    // Actions
    fetchDashboard,
    fetchJobs,
    fetchJob,
    createJob,
    updateJob,
    updateStatus,
    updatePaymentStatus,
    fetchDiagnosis,
    addDiagnosis,
    updateDiagnosis,
    deleteDiagnosis,
    fetchParts,
    addPart,
    deletePart,
    fetchActivityLog,
    logActivity,
    fetchReports,
    createReport,
    fetchIssueTemplates,
    recalcCosts,
  }
})

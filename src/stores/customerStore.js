import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from './auth'

export const useCustomerStore = defineStore('customers', () => {
  const customers = ref([])
  const categories = ref([])
  const loading = ref(false)
  const authStore = useAuthStore()

  const getCompanyId = () => authStore.currentBranch?.company_id

  async function fetchCategories() {
    const companyId = getCompanyId()
    if (!companyId) return

    const { data, error } = await supabase
      .from('customer_categories')
      .select('*')
      .eq('company_id', companyId)
      .order('name')

    if (error) throw new Error(error.message)
    categories.value = data
  }

  async function fetchCustomers(query = '', categoryId = null) {
    loading.value = true
    try {
      const companyId = getCompanyId()
      if (!companyId) {
        console.warn('[customerStore] fetchCustomers: No companyId found. Skipping.')
        customers.value = []
        return
      }

      let dbQuery = supabase.from('customers').select('*').eq('company_id', companyId)

      if (categoryId) {
        dbQuery = dbQuery.eq('category_id', categoryId)
      }

      if (query && query.trim() !== '') {
        const qPattern = `%${query.trim()}%`
        dbQuery = dbQuery.or(
          `name.ilike.${qPattern},phone.ilike.${qPattern},email.ilike.${qPattern},customer_code.ilike.${qPattern}`,
        )
      }

      const { data, error } = await dbQuery.order('created_at', { ascending: false })
      if (error) throw new Error(error.message)
      customers.value = data
    } finally {
      loading.value = false
    }
  }

  async function createCustomer(customerData) {
    const companyId = getCompanyId()
    if (!companyId) throw new Error('Company ID is missing. Please select a branch.')

    // Explicitly build the payload. Do NOT include 'id'.
    // Let the database default (gen_random_uuid) and triggers handle code generation.
    const payload = {
      company_id: companyId,
      name: customerData.name,
      phone: customerData.phone || null,
      email: customerData.email || null,
      address: customerData.address || null,
      nic_brn: customerData.nic_brn || null,
      tax_number: customerData.tax_number || null,
      category_id: customerData.category_id || null,
      status: customerData.status || 'active',
      notes: customerData.notes || null,
    }

    const { data, error } = await supabase.from('customers').insert(payload).select().single()

    if (error) throw new Error(error.message)
    customers.value.unshift(data)
    return data
  }

  async function updateCustomer(id, updates) {
    // Ensure id is not in the updates object to avoid internal PG errors
    const cleanUpdates = { ...updates }
    delete cleanUpdates.id

    const { data, error } = await supabase
      .from('customers')
      .update(cleanUpdates)
      .eq('id', id)
      .select()
      .single()

    if (error) throw new Error(error.message)
    const idx = customers.value.findIndex((c) => c.id === id)
    if (idx !== -1) customers.value[idx] = data
    return data
  }

  async function checkDuplicate(name, phone) {
    if (!name || !phone) return null
    const companyId = getCompanyId()
    const { data, error } = await supabase
      .from('customers')
      .select('*')
      .eq('company_id', companyId)
      .eq('name', name)
      .eq('phone', phone)
      .maybeSingle()

    if (error) throw new Error(error.message)
    return data
  }

  async function createCategory(name) {
    const companyId = getCompanyId()
    const { data, error } = await supabase
      .from('customer_categories')
      .insert({ name, company_id: companyId })
      .select()
      .single()

    if (error) throw new Error(error.message)
    categories.value.push(data)
    return data
  }

  return {
    customers,
    categories,
    loading,
    fetchCategories,
    fetchCustomers,
    createCustomer,
    updateCustomer,
    createCategory,
    checkDuplicate,
  }
})

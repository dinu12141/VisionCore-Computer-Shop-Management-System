import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'

config()

const url = process.env.VITE_SUPABASE_URL
const key = process.env.VITE_SUPABASE_ANON_KEY
const supabase = createClient(url, key)

async function test() {
  const { data, error } = await supabase
    .from('invoices')
    .select('id, invoice_date, created_at')
    .order('created_at', { ascending: false })
    .limit(2)
  console.log('Data:', data, 'Error:', error)
}

test()

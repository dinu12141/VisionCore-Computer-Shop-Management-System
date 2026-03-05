import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://ovdheejmgchtohnjozpn.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92ZGhlZWptZ2NodG9obmpvenBuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2NjA0MTEsImV4cCI6MjA4NzIzNjQxMX0.ZnmdfEA-N-30bKQnsU1GCsuwWVbe4neEvePF5p-wqek'
const supabase = createClient(supabaseUrl, supabaseKey)

async function run() {
  const { data, error } = await supabase
    .from('item_categories')
    .update({ name: 'Keyboards & Mouse' })
    .eq('name', 'Keyboards & Mice')
    .select()

  if (error) {
    console.error('Error:', error)
  } else {
    console.log('Success:', data)
  }
}

run()

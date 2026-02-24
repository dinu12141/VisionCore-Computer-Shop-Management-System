import { createClient } from '@supabase/supabase-js'
import { boot } from 'quasar/wrappers'
import { Database } from 'src/types/supabase' // Assumes you might have generated types, or we use 'any' for now if not generated.

// If you have generated types, use them here. Otherwise, we can use a generic client.
// export const supabase = createClient<Database>(...)
console.log('[Boot] Initializing Supabase...')
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('[Boot] Supabase URL or Anon Key missing!')
  throw new Error('Supabase URL or Anon Key not found in environment variables.')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
console.log('[Boot] Supabase client initialized')

export default boot(({ app }) => {
  app.config.globalProperties.$supabase = supabase
  app.provide('supabase', supabase)
})

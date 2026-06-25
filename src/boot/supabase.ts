import { createClient } from '@supabase/supabase-js'
import { boot } from 'quasar/wrappers'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('[VisionCore] VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be set.')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storageKey: 'visioncore-auth',
  },
  global: {
    headers: { 'x-application': 'visioncore-erp/1.0' },
    // Exponential backoff fetch: retry up to 3 times on network errors and 429s
    fetch: retryFetch,
  },
  realtime: {
    params: {
      eventsPerSecond: 10, // rate-limit realtime events to 10/s per channel
    },
  },
})

/**
 * Wraps the native fetch with up to 3 retries using exponential backoff.
 * Retries on: network errors, 429 Too Many Requests, 503 Service Unavailable.
 */
async function retryFetch(
  input: RequestInfo | URL,
  init?: RequestInit,
): Promise<Response> {
  const MAX_RETRIES = 3
  const BASE_DELAY_MS = 300

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(input, init)

      // Retry on rate limit or server errors (but not on 4xx auth errors)
      if ((response.status === 429 || response.status === 503) && attempt < MAX_RETRIES) {
        const retryAfter = response.headers.get('Retry-After')
        const delay = retryAfter
          ? parseInt(retryAfter, 10) * 1000
          : BASE_DELAY_MS * Math.pow(2, attempt)
        await sleep(delay)
        continue
      }

      return response
    } catch (err) {
      // Network-level error (offline, DNS failure, etc.)
      if (attempt === MAX_RETRIES) throw err
      await sleep(BASE_DELAY_MS * Math.pow(2, attempt))
    }
  }

  // Unreachable but satisfies TypeScript
  throw new Error('Max retries exceeded')
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

export default boot(({ app }) => {
  app.config.globalProperties.$supabase = supabase
  app.provide('supabase', supabase)
})

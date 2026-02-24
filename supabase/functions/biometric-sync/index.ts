import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseKey) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
    }

    const supabase = createClient(supabaseUrl, supabaseKey)

    // 1. Fetch Logs from Biometric Device
    console.log('Fetching logs from device...')
    const logs = await fetchBiometricLogs()
    console.log(`Fetched ${logs.length} logs`)

    // 2. Insert into attendance_logs
    if (logs.length > 0) {
      const { data, error } = await supabase.from('attendance_logs').upsert(
        logs.map((log: any) => ({
          employee_code: log.userId,
          device_id: log.deviceId,
          punch_time: new Date(log.timestamp).toISOString(),
          punch_type: log.type === 0 || log.type === 'in' ? 'in' : 'out',
          source: 'biometric',
          raw_data: log,
          is_processed: false,
        })),
        { onConflict: 'employee_code, punch_time, device_id' },
      )

      if (error) {
        console.error('Database Insert Error:', error)
        throw error
      }
    }

    // 3. Trigger Processing
    console.log('Triggering processing...')
    const { error: procError } = await supabase.rpc('process_attendance_logs')

    if (procError) {
      console.error('Processing Execution Error:', procError)
      // Don't fail the whole request if processing fails, just log it
    }

    return new Response(JSON.stringify({ success: true, count: logs.length }), {
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  } catch (error: any) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }
})

// MOCK: Replace with actual device API call
async function fetchBiometricLogs() {
  // Example: fetch('http://device-ip/api/logs')

  // Return mock data for demonstration
  return [
    {
      userId: 'EMP001',
      deviceId: 'DEV001',
      timestamp: Date.now() - 1000 * 60 * 60, // 1 hour ago
      type: 0, // Check In
    },
    {
      userId: 'EMP002',
      deviceId: 'DEV001',
      timestamp: Date.now(),
      type: 1, // Check Out
    },
  ]
}

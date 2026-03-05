const fs = require('fs')
const raw = fs.readFileSync(
  'C:\\\\Users\\\\ROG STRIX\\\\.gemini\\\\antigravity\\\\brain\\\\b9eab76b-9b68-4177-bb06-8e9acf161215\\\\.system_generated\\\\steps\\\\2514\\\\output.txt',
  'utf8',
)
const match = raw.match(/<untrusted-[^>]+>[\s\S]*?\[(.*?)\][\s\S]*?<\/untrusted-/)

// Just simple substring
let start = raw.indexOf('[{"tablename"')
let end = raw.lastIndexOf('}]') + 2
const data = JSON.parse(raw.substring(start, end))

let out = '-- ============================================================================\n'
out += '-- MIGRATION: Fix Remaining Performance Warnings (Multiple Permissive Policies)\n'
out += '-- ============================================================================\n\n'
out += 'DO $main$\nBEGIN\n\n'

data.forEach((row, idx) => {
  out += `-- ─────────────────────────────────────────────────────────────────────────────\n`
  out += `-- ${idx + 1}. TABLE ${row.tablename} (ACTION: ${row.cmd})\n`
  out += `-- ─────────────────────────────────────────────────────────────────────────────\n`

  const policies = row.policies.split(', ')
  policies.forEach((p) => {
    out += `DROP POLICY IF EXISTS "${p}" ON ${row.tablename};\n`
  })

  // Sometimes there are multiple rows for the same table (like cmd=SELECT and cmd=ALL).
  // The new policy name should reflect the cmd.
  const newName = `${row.tablename}_${row.cmd.toLowerCase()}_consolidated`
  out += `DROP POLICY IF EXISTS "${newName}" ON ${row.tablename};\n`

  let roles = row.roles // e.g. "{public}"
  if (roles === '{public}') roles = 'public'
  else if (roles === '{authenticated}') roles = 'authenticated'
  else if (roles === '{anon}') roles = 'anon'
  else roles = 'authenticated' // fallback

  out += `CREATE POLICY "${newName}" ON ${row.tablename}\n`
  out += `  FOR ${row.cmd} TO ${roles}\n`

  let needsUsing = ['SELECT', 'UPDATE', 'DELETE', 'ALL'].includes(row.cmd)
  let needsWithCheck = ['INSERT', 'UPDATE', 'ALL'].includes(row.cmd)

  if (needsUsing) {
    let q = row.qual_combined || 'true'
    out += `  USING ( ${q} )\n`
  }

  if (needsWithCheck) {
    let w = row.with_check_combined
    if (w && !w.includes('true OR true')) {
      out += `  WITH CHECK ( ${w} )\n`
    } else if (w) {
      out += `  WITH CHECK ( true )\n`
    }
  }
  out += ';\n\n'
})

out += 'END $main$;\n'

fs.writeFileSync('supabase/migrations/20260305_fix_remaining_perf.sql', out)
console.log('Done writing supabase/migrations/20260305_fix_remaining_perf.sql')

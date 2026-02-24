# Biometric Integration Setup

## Status

- ✅ **Database Schema**: Applied successfully. (`attendance_logs` updated, `process_attendance_logs` created)
- ✅ **Backend Service**: Deployed successfully. (`biometric-sync` Edge Function)
- ✅ **Cron Job**: Configured and Active. (Runs every 5 minutes)

## Configuration Details

The system is configured to automatically sync biometric data every 5 minutes.

- **Job Name**: `biometric_sync_job`
- **Schedule**: `*/5 * * * *` (Every 5 minutes)
- **Target URL**: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/biometric-sync`
- **Auth Key**: `YOUR_ANON_KEY` (Configured)

## Manual Testing

You can manually trigger the sync process at any time by running this SQL command in the Supabase SQL Editor:

```sql
select
  net.http_post(
      url:='https://YOUR_PROJECT_REF.supabase.co/functions/v1/biometric-sync',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb,
      body:='{}'::jsonb
  ) as request_id;
```

## Monitoring & Troubleshooting

### 1. Check Cron Job Execution

To see if the cron job is running successfully:

```sql
select * from cron.job_run_details order by start_time desc limit 5;
```

### 2. Check HTTP Requests

To see the status of the HTTP requests made by the cron job:

```sql
select * from net.http_request_queue order by id desc limit 5;
```

### 3. Check Data Sync

To verify that attendance logs are being populated:

```sql
select * from attendance_logs order by punch_time desc limit 10;
```

### 4. Check Processed Records

To verify that daily attendance records are being created:

```sql
select * from attendance_records order by attendance_date desc limit 10;
```

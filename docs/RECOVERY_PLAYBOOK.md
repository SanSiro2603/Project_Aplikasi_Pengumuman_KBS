# Recovery Playbook

## A. Rotate OneSignal Key
1. Generate new App API key di OneSignal Dashboard.
2. Update secret di Supabase project:
   - `ONESIGNAL_REST_API_KEY`
3. Redeploy `notify_warga`.
4. Kirim smoke notification.

## B. Notification Incident (Push Gagal)
1. Cek edge function logs (`request_id`, `provider_status`, `provider_http_status`).
2. Cek `notification_dispatch_log`:
   - `provider_status`
   - `last_error`
   - `attempt_count`
3. Jika provider outage:
   - disable DB trigger sementara.
4. Setelah pulih:
   - replay dari log:
     - cari `provider_status = 'failed'`
     - invoke ulang per `announcement_id`.

## C. DB Trigger Isolation
Disable:
```sql
alter table public.announcements disable trigger trg_notify_warga_on_publish;
```

Enable:
```sql
alter table public.announcements enable trigger trg_notify_warga_on_publish;
```

## D. Data Cleanup
Jalankan housekeeping manual:
```sql
select public.cleanup_notification_data();
```


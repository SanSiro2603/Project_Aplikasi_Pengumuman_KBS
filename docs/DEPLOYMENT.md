# Deployment Guide (dev + prod)

## 1) Local Developer Flow
1. Export runtime env:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `ONESIGNAL_APP_ID`
   - `UPDATE_MANIFEST_URL`
2. Run app with `--dart-define`.
3. Apply DB migration (dev):
   - `supabase db push --project-ref <DEV_REF> --password <DEV_DB_PASSWORD>`
4. Deploy function (dev):
   - `supabase functions deploy notify_warga --project-ref <DEV_REF>`
5. Run smoke:
   - login admin
   - publish with/without image
   - verify notification_dispatch_log and app_errors rows

## 2) GitHub Environments and Secrets
### Shared
- `SUPABASE_ACCESS_TOKEN`

### Dev environment
- `SUPABASE_PROJECT_REF_DEV`
- `SUPABASE_DB_PASSWORD_DEV`
- `SUPABASE_ANON_KEY_DEV`

### Prod environment
- `SUPABASE_PROJECT_REF_PROD`
- `SUPABASE_DB_PASSWORD_PROD`
- `SUPABASE_ANON_KEY_PROD`
- `SUPABASE_URL_PROD`
- `ONESIGNAL_APP_ID_PROD`
- Optional: `UPDATE_MANIFEST_URL_PROD`

## 3) Deployment Pipelines
### Dev (auto on main)
- Workflow: `deploy-dev.yml`
- Steps:
  1. `supabase db push` (dev)
  2. deploy `notify_warga`
  3. smoke invoke `notify_warga`

### Prod (manual approval gate)
- Workflow: `deploy-prod.yml` (`workflow_dispatch`)
- Required: GitHub Environment protection with manual approver
- Steps:
  1. `supabase db push` (prod)
  2. deploy `notify_warga`
  3. smoke invoke
  4. publish release artifact

### Self Distribution Release (manual)
- Workflow: `release-distribution.yml` (`workflow_dispatch`)
- Steps:
  1. build split APK release (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
  2. enforce setiap APK `< 40MB`
  3. generate `latest.json` + `sha256sums.txt`
  4. upload APK + manifest ke GitHub Release
  5. deploy `distribution_site` ke GitHub Pages

## 4) Rollback
1. Redeploy previous stable function revision.
2. Re-run db migration rollback script (if provided in hotfix branch).
3. Disable trigger sementara:
   - `alter table public.announcements disable trigger trg_notify_warga_on_publish;`
4. Re-enable setelah incident selesai:
   - `alter table public.announcements enable trigger trg_notify_warga_on_publish;`

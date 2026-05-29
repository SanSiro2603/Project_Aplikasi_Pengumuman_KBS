# Pengumuman Desa (Flutter + Supabase + OneSignal)

## Runtime Configuration
App tidak lagi menyimpan key sensitif di source code. Jalankan dengan:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=ONESIGNAL_APP_ID=YOUR_ONESIGNAL_APP_ID
```

## Database Migrations
Gunakan SQL versioned di `supabase/migrations`:

- `202605280001_core_hardening.sql`
- `202605280002_housekeeping.sql`
- `202605280003_publish_trigger_secure.sql`

Pastikan vault secrets berikut tersedia sebelum trigger publish dipakai:

- `supabase_project_url`
- `supabase_anon_key`

## CI/CD
Workflow GitHub Actions:

- `.github/workflows/ci.yml`
- `.github/workflows/deploy-dev.yml`
- `.github/workflows/deploy-prod.yml`
- `.github/workflows/release-distribution.yml`

Lihat panduan lengkap di `docs/DEPLOYMENT.md`.

## Distribusi Mandiri APK
- Landing page statis: `distribution_site/index.html` (untuk GitHub Pages).
- Manifest update publik: `distribution_site/latest.json`.
- App akan cek update via `UPDATE_MANIFEST_URL`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=ONESIGNAL_APP_ID=YOUR_ONESIGNAL_APP_ID \
  --dart-define=UPDATE_MANIFEST_URL=https://<owner>.github.io/<repo>/latest.json
```

- Release Android distribusi dijalankan dari workflow `Release Distribution`:
  - build split APK (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
  - enforce ukuran tiap APK `< 40MB`
  - generate `sha256` + `latest.json`
  - upload ke GitHub Releases
  - deploy/update landing page ke GitHub Pages

## QA & Recovery
Dokumentasi operasi:

- `docs/QA_SMOKE_TESTS.md`
- `docs/SECURITY_RLS_CHECKLIST.md`
- `docs/RECOVERY_PLAYBOOK.md`

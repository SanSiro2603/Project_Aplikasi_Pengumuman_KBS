# Handover Guide Pengumuman KBS

Dokumen ini untuk teman yang akan memakai project ini dengan akun Supabase dan OneSignal sendiri. Ikuti dari atas ke bawah saat setup pertama.

## 1. Gambaran Singkat

Aplikasi ini punya dua bagian:

- **Aplikasi Flutter**: berjalan di HP/emulator, membaca config dari `env/dev.json`.
- **Backend Supabase**: database, auth admin, storage gambar, realtime, dan Edge Function `notify_warga`.
- **OneSignal**: layanan push notification ke HP warga.

Yang perlu diingat:

- Rebuild APK cukup dilakukan saat config app atau kode Flutter berubah.
- Redeploy `notify_warga` hanya perlu saat setup backend pertama atau kode function berubah.
- Jika pindah akun Supabase/OneSignal, setup backend perlu dijalankan ulang untuk project baru.

## 2. Prasyarat

Install di laptop Windows:

- Flutter SDK
- Supabase CLI
- Git
- Android Studio atau device Android dengan USB debugging

Cek dari PowerShell:

```powershell
flutter --version
supabase --version
```

Login Supabase CLI:

```powershell
supabase login
```

## 3. Buat Project Supabase

1. Buka Supabase Dashboard.
2. Buat project baru.
3. Catat:
   - Project ref
   - Project URL
   - Anon key
   - Service role key
   - Database password
4. Di Authentication, buat user admin.
5. Tambahkan metadata admin:

```json
{
  "role": "admin"
}
```

Kode app membaca role dari `app_metadata.role` atau `user_metadata.role`.

## 4. Buat App OneSignal

1. Buat app baru di OneSignal.
2. Aktifkan platform Android.
3. Catat:
   - OneSignal App ID
   - REST API Key

App ID dipakai aplikasi Flutter. REST API Key dipakai Edge Function Supabase untuk mengirim push.

## 5. Siapkan File Config Lokal

Copy template:

```powershell
copy env\dev.example.json env\dev.json
```

Isi `env\dev.json` untuk run/build Flutter:

```json
{
  "SUPABASE_URL": "https://PROJECT_REF.supabase.co",
  "SUPABASE_ANON_KEY": "anon key",
  "ONESIGNAL_APP_ID": "onesignal app id",
  "UPDATE_MANIFEST_URL": "https://example.com/latest.json"
}
```

Untuk setup backend, tidak perlu file config khusus. Simpan saja nilai berikut di catatan pribadi karena akan dipakai saat menjalankan command:

- `PROJECT_REF`
- `DB_PASSWORD`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ONESIGNAL_APP_ID`
- `ONESIGNAL_REST_API_KEY`

File `env/*.json` diabaikan git, jadi secret tidak ikut masuk repo.

## 6. Setup Backend Sekali

Jalankan migration database:

```powershell
supabase db push --project-ref PROJECT_REF --password DB_PASSWORD
```

Ganti:

- `PROJECT_REF` dengan project ref Supabase.
- `DB_PASSWORD` dengan database password project Supabase.

Set secrets untuk Edge Function:

```powershell
supabase secrets set ONESIGNAL_APP_ID=ONESIGNAL_APP_ID ONESIGNAL_REST_API_KEY=ONESIGNAL_REST_API_KEY SUPABASE_URL=SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY ONESIGNAL_SOUND_ANDROID_CHANNEL_ID=announcement_channel_sound_v3 ONESIGNAL_SILENT_ANDROID_CHANNEL_ID=announcement_channel_silent_v1 --project-ref PROJECT_REF
```

Deploy function notifikasi:

```powershell
supabase functions deploy notify_warga --project-ref PROJECT_REF
```

## 7. Jalankan SQL Vault Manual

Setelah migration dan function selesai, buat Vault secret manual:

1. Buka Supabase Dashboard.
2. Masuk ke SQL Editor.
3. Paste SQL di bawah ini.
4. Klik Run.

```sql
do $$
declare
  project_url_id uuid;
  anon_key_id uuid;
begin
  select id into project_url_id
  from vault.decrypted_secrets
  where name = 'supabase_project_url'
  limit 1;

  if project_url_id is null then
    perform vault.create_secret('SUPABASE_URL', 'supabase_project_url', 'Project URL untuk trigger notify_warga');
  else
    perform vault.update_secret(project_url_id, 'SUPABASE_URL', 'supabase_project_url', 'Project URL untuk trigger notify_warga');
  end if;

  select id into anon_key_id
  from vault.decrypted_secrets
  where name = 'supabase_anon_key'
  limit 1;

  if anon_key_id is null then
    perform vault.create_secret('SUPABASE_ANON_KEY', 'supabase_anon_key', 'Anon key untuk trigger notify_warga');
  else
    perform vault.update_secret(anon_key_id, 'SUPABASE_ANON_KEY', 'supabase_anon_key', 'Anon key untuk trigger notify_warga');
  end if;
end
$$;
```

Ganti:

- `SUPABASE_URL` dengan Project URL.
- `SUPABASE_ANON_KEY` dengan anon key.

Kenapa perlu Vault?

Trigger database `trg_notify_warga_on_publish` memanggil Edge Function `notify_warga`. Trigger itu butuh `supabase_project_url` dan `supabase_anon_key` dari Vault.

Referensi: [Supabase Vault](https://supabase.com/docs/guides/database/vault/).

## 8. Run App di HP atau Emulator

```powershell
flutter run --dart-define-from-file=env/dev.json
```

Jika ada beberapa device:

```powershell
flutter devices
flutter run --dart-define-from-file=env/dev.json -d DEVICE_ID
```

Setelah app terbuka:

1. Izinkan notifikasi.
2. Buka ikon notifikasi di home.
3. Simpan pengaturan notifikasi.

Langkah ini penting agar tag OneSignal di HP tersinkron.

## 9. Build APK

Build APK release:

```powershell
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --dart-define-from-file=env/dev.json
```

Output ada di:

```text
build\app\outputs\flutter-apk
```

Untuk sebagian besar HP modern, pakai:

```text
app-arm64-v8a-release.apk
```

## 10. Kapan Perlu Redeploy

Perlu redeploy `notify_warga` jika:

- setup Supabase project baru
- kode `supabase/functions/notify_warga/index.ts` berubah
- secrets OneSignal/Supabase function berubah

Tidak perlu redeploy jika:

- hanya rebuild APK
- hanya ganti tampilan Flutter
- hanya install ulang app di HP

## 11. Smoke Test Notifikasi

1. Run/install app di HP.
2. Buka app minimal sekali.
3. Aktifkan notifikasi.
4. Simpan pengaturan suara.
5. Login admin.
6. Buat pengumuman baru dengan status `published`.
7. Cek HP menerima notifikasi.
8. Cek tabel `notification_dispatch_log`.

Untuk test suara per kategori:

1. Aktifkan `Set suara per kategori`.
2. Matikan salah satu kategori, misalnya `Keuangan`.
3. Publish pengumuman kategori `Keuangan`.
4. Notifikasi harus masuk tanpa suara.
5. Publish kategori lain yang aktif.
6. Notifikasi harus masuk dengan suara.

## 12. Troubleshooting

**Notifikasi tidak masuk**

- Pastikan app sudah dibuka sekali setelah install.
- Pastikan izin notifikasi Android aktif.
- Pastikan `ONESIGNAL_APP_ID` di `env/dev.json` benar.
- Pastikan `notify_warga` sudah dideploy ke project Supabase yang sama.
- Cek `notification_dispatch_log`.
- Buat pengumuman baru, jangan pakai row lama yang sudah pernah terkirim.

**Admin tidak bisa masuk dashboard**

- Pastikan user sudah login.
- Pastikan metadata user punya `role=admin`.

**Gambar gagal upload**

- Pastikan bucket storage `announcements` sudah dibuat dari migration.
- Pastikan file gambar bertipe `jpg`, `jpeg`, `png`, `webp`, `heic`, atau `heif`.

**Function deploy gagal**

- Jalankan `supabase login`.
- Pastikan project ref benar.
- Pastikan akun Supabase punya akses ke project.

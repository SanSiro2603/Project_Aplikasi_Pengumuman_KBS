# Code Guide Pengumuman KBS

Dokumen ini menjelaskan file penting dan alur kode supaya developer baru bisa cepat membaca project.

## 1. Entry Point Aplikasi

- `lib/main.dart`
  - Inisialisasi Flutter.
  - Validasi config dari `--dart-define`.
  - Inisialisasi Supabase.
  - Menjalankan app.
  - Menjalankan `NotificationService.initialize()` di background.
- `lib/core/config/app_config.dart`
  - Membaca `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ONESIGNAL_APP_ID`, dan `UPDATE_MANIFEST_URL`.

Run app memakai:

```powershell
flutter run --dart-define-from-file=env/dev.json
```

## 2. Routing dan Role Admin

- `lib/core/router/app_router.dart`
  - Route `/` untuk splash.
  - Route `/home` untuk warga.
  - Route `/detail/:id` untuk detail pengumuman.
  - Route `/admin/login` untuk login admin.
  - Route `/admin` untuk dashboard admin.
  - Route `/admin/form` untuk tambah/edit pengumuman.
- `lib/core/auth/admin_access.dart`
  - Mengecek `role=admin` dari Supabase Auth metadata.

Jika user login tapi bukan admin, route admin diarahkan ke `/home`.

## 3. Fitur Warga

- `lib/features/guest/presentation/screens/splash_screen.dart`
  - Layar awal.
- `lib/features/guest/presentation/screens/home_screen.dart`
  - Menampilkan daftar pengumuman published.
  - Filter kategori dan tanggal.
  - Pencarian.
  - Dialog izin notifikasi.
  - Pengaturan suara notifikasi per kategori.
- `lib/features/guest/presentation/screens/detail_screen.dart`
  - Detail pengumuman.
  - Gambar bisa dibuka lebih besar.
- `lib/features/guest/presentation/widgets/announcement_card.dart`
  - Kartu pengumuman di home.

## 4. Fitur Admin

- `lib/features/admin/presentation/screens/admin_login_screen.dart`
  - Login admin memakai Supabase Auth.
- `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`
  - Daftar semua pengumuman untuk admin.
  - Aksi edit/hapus.
- `lib/features/admin/presentation/screens/admin_form_screen.dart`
  - Membuat dan mengedit pengumuman.
  - Upload gambar ke Supabase Storage.
  - Kompres gambar jika memungkinkan.
  - Memanggil `notify_warga` saat pengumuman baru dipublish.

Status penting:

- `draft`: disimpan tapi tidak tampil ke warga.
- `published`: tampil ke warga dan memicu notifikasi jika baru pertama kali publish.

## 5. Data Pengumuman

- `lib/features/announcement/data/models/announcement_model.dart`
  - Model Dart untuk row `announcements`.
- `lib/features/announcement/data/repositories/announcement_repository.dart`
  - Query Supabase untuk warga dan admin.
  - Stream realtime untuk update daftar pengumuman.
- `lib/features/announcement/presentation/providers/announcement_provider.dart`
  - Provider Riverpod agar UI bisa membaca stream data.

Kategori valid:

- `umum`
- `kesehatan`
- `infrastruktur`
- `keuangan`
- `acara`

## 6. Notifikasi

- `lib/core/notifications/notification_service.dart`
  - Inisialisasi OneSignal.
  - Request permission Android.
  - Sync subscription id ke tabel `device_tokens`.
  - Sync tag preferensi suara ke OneSignal.
- `supabase/functions/notify_warga/index.ts`
  - Edge Function yang mengirim push via OneSignal.
  - Membagi target menjadi channel suara dan senyap.
- `android/app/src/main/kotlin/.../MainActivity.kt`
  - Membuat Android notification channel:
    - `announcement_channel_sound_v3`
    - `announcement_channel_silent_v1`

Detail alur ada di `docs/NOTIFICATION_FLOW.md`.

## 7. Backend Supabase

- `supabase/migrations/202605280001_core_hardening.sql`
  - Hardening tabel, RLS, log error, log dispatch notifikasi.
- `supabase/migrations/202605280002_housekeeping.sql`
  - Cleanup data notifikasi/log lama.
- `supabase/migrations/202605280003_publish_trigger_secure.sql`
  - Trigger database untuk memanggil `notify_warga` saat row menjadi `published`.
- `supabase/functions/notify_warga/index.ts`
  - Function pengiriman notifikasi.

Tabel penting:

- `announcements`: data pengumuman.
- `device_tokens`: subscription id OneSignal dari device.
- `notification_dispatch_log`: log hasil pengiriman notifikasi.
- `app_errors`: log error dari client.

## 8. Update APK

- `lib/core/update/app_update_service.dart`
  - Mengecek update manifest.
  - Menampilkan dialog update jika ada versi baru.
- `lib/core/update/update_manifest.dart`
  - Model manifest update.
- `distribution_site/latest.json`
  - Manifest update untuk distribusi mandiri.

Dokumen distribusi ada di `docs/DISTRIBUTION_APK.md`.

## 9. Command Developer

Setup backend:

```powershell
supabase db push --project-ref PROJECT_REF --password DB_PASSWORD
supabase functions deploy notify_warga --project-ref PROJECT_REF
```

Run app:

```powershell
flutter run --dart-define-from-file=env/dev.json
```

Build APK:

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=env/dev.json
```

File config lokal:

- `env/dev.json`: runtime Flutter.

Template aman:

- `env/dev.example.json`

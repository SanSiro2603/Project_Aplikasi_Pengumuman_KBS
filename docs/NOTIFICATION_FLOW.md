# Notification Flow

Dokumen ini menjelaskan alur notifikasi dari admin publish pengumuman sampai HP warga menerima push.

## 1. Alur Besar

```text
Admin publish pengumuman
  -> app menyimpan row announcements
  -> app memanggil Edge Function notify_warga
  -> database trigger juga bisa memanggil notify_warga saat status berubah published
  -> notify_warga mengirim request ke OneSignal
  -> OneSignal mengirim push ke device
  -> Android memilih channel bersuara atau senyap
```

## 2. Dari Admin Form

File: `lib/features/admin/presentation/screens/admin_form_screen.dart`

Saat admin menyimpan pengumuman:

- Data disimpan ke tabel `announcements`.
- Jika status `published` dan sebelumnya belum pernah published, app memanggil `notify_warga`.
- Payload berisi:
  - `id`
  - `title`
  - `category`
  - `status`
  - `image_url`

Function punya proteksi idempotent. Jika pengumuman yang sama sudah sukses dikirim, function akan skip agar warga tidak menerima duplikat.

## 3. Dari Database Trigger

File: `supabase/migrations/202605280003_publish_trigger_secure.sql`

Trigger `trg_notify_warga_on_publish` berjalan saat:

- insert row baru dengan status `published`
- update status dari bukan `published` menjadi `published`

Trigger memakai Vault secret:

- `supabase_project_url`
- `supabase_anon_key`

Secret ini perlu dibuat manual lewat SQL Editor setelah setup backend.

## 4. Tag OneSignal dari Aplikasi

File: `lib/core/notifications/notification_service.dart`

Aplikasi menyimpan preferensi notifikasi di `SharedPreferences`, lalu sync ke OneSignal sebagai tag:

- `notif_allowed`
- `sound_mode_per_category`
- `sound_default_enabled`
- `sound_category_umum`
- `sound_category_kesehatan`
- `sound_category_infrastruktur`
- `sound_category_keuangan`
- `sound_category_acara`

Contoh:

```text
notif_allowed=1
sound_mode_per_category=1
sound_category_keuangan=0
sound_category_acara=1
```

Artinya user menerima notifikasi, mode kategori aktif, kategori keuangan senyap, kategori acara bersuara.

## 5. Targeting di Edge Function

File: `supabase/functions/notify_warga/index.ts`

Function membagi target menjadi beberapa batch:

- `sound_legacy_untagged`
  - fallback untuk device yang belum punya tag
  - tetap menerima notifikasi bersuara
- `sound_per_category`
  - mode kategori aktif dan kategori ini bersuara
- `sound_default`
  - mode kategori mati dan default sound aktif
- `silent_per_category`
  - mode kategori aktif dan kategori ini senyap
- `silent_default`
  - mode kategori mati dan default sound mati

Semua request tetap mengirim notifikasi. Perbedaannya ada di channel Android:

- sound target memakai `announcement_channel_sound_v3`
- silent target memakai `announcement_channel_silent_v1`

## 6. Android Notification Channel

File: `android/app/src/main/kotlin/com/desa/pengumuman/pengumuman_desa/MainActivity.kt`

Android 8+ mengunci suara notifikasi di channel. Karena itu app membuat dua channel:

- `announcement_channel_sound_v3`
  - memakai sound custom `announcement_tone`
- `announcement_channel_silent_v1`
  - tanpa sound

Kalau suara channel lama salah, menaikkan nama/id channel adalah cara aman agar Android membuat channel baru.

## 7. Kenapa Notifikasi Bisa Tidak Masuk

Penyebab umum:

- App belum dibuka setelah install, jadi OneSignal belum register device.
- User belum mengizinkan notifikasi Android.
- Tag OneSignal belum sync karena pengaturan belum disimpan.
- `notify_warga` belum dideploy ke project Supabase yang benar.
- OneSignal App ID di app tidak sama dengan REST API Key di function.
- Pengumuman lama sudah pernah dikirim dan function melakukan idempotent skip.

## 8. Cara Test

1. Jalankan app di HP.
2. Izinkan notifikasi.
3. Buka pengaturan notifikasi dan tekan Simpan.
4. Taruh app di background.
5. Publish pengumuman baru dari admin.
6. Cek notifikasi masuk.
7. Cek `notification_dispatch_log`:
   - `provider_status`
   - `target_count`
   - `provider_response`

Jika `target_count=0`, biasanya device belum register atau tag belum cocok.

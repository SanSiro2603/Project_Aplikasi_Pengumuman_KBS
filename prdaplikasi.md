# PRD — Aplikasi Pengumuman Desa

**Product Requirements Document**
Version 1.0 | Flutter + Supabase

---

## 1. Overview Singkat

Aplikasi mobile untuk menyebarkan pengumuman resmi desa kepada warga secara real-time. Warga tidak perlu login untuk membaca pengumuman. Hanya admin desa yang memiliki akses CMS untuk membuat, mengelola, dan menghapus pengumuman. Setiap pengumuman baru akan memicu push notification ke seluruh pengguna aplikasi.

---

## 2. Requirements

### 2.1 Functional Requirements

| ID    | Requirement                                                                                      | Prioritas |
| ----- | ------------------------------------------------------------------------------------------------ | --------- |
| FR-01 | Warga dapat melihat daftar pengumuman tanpa login                                                | Wajib     |
| FR-02 | Warga dapat membaca detail pengumuman (judul, isi, gambar, tanggal)                              | Wajib     |
| FR-03 | Push notification otomatis terkirim saat admin publish pengumuman baru                           | Wajib     |
| FR-04 | Admin dapat login menggunakan email & password                                                   | Wajib     |
| FR-05 | Admin dapat membuat pengumuman baru (judul, isi, gambar, kategori)                               | Wajib     |
| FR-06 | Admin dapat mengedit pengumuman yang sudah ada                                                   | Wajib     |
| FR-07 | Admin dapat menghapus pengumuman                                                                 | Wajib     |
| FR-08 | Gambar yang diupload admin otomatis dikompres di sisi client sebelum dikirim ke Supabase Storage | Wajib     |
| FR-09 | Admin dapat memilih kategori pengumuman (Umum, Kesehatan, Infrastruktur, Keuangan, Acara)        | Penting   |
| FR-10 | Warga dapat mencari pengumuman berdasarkan kata kunci                                            | Penting   |
| FR-11 | Warga dapat memfilter pengumuman berdasarkan kategori                                            | Penting   |
| FR-12 | Admin dapat melihat jumlah view per pengumuman                                                   | Opsional  |

### 2.2 Non-Functional Requirements

| ID     | Requirement     | Detail                                                                                              |
| ------ | --------------- | --------------------------------------------------------------------------------------------------- |
| NFR-01 | Performa        | Daftar pengumuman harus termuat dalam < 2 detik pada jaringan 4G                                    |
| NFR-02 | Kompresi Gambar | Semua gambar dikompres ke maksimal 500 KB sebelum upload, tanpa perlu konfigurasi manual dari admin |
| NFR-03 | Keamanan        | Hanya user dengan role `admin` di Supabase yang dapat mengakses fitur CMS                           |
| NFR-04 | Offline         | Pengumuman terakhir yang dimuat tersimpan di cache lokal (Hive/SharedPreferences)                   |
| NFR-05 | Platform        | Android & iOS                                                                                       |
| NFR-06 | Real-time       | Daftar pengumuman diperbarui secara real-time menggunakan Supabase Realtime                         |

### 2.3 Tech Stack

| Layer              | Teknologi                                                               |
| ------------------ | ----------------------------------------------------------------------- |
| Frontend           | Flutter (Dart)                                                          |
| Backend / Database | Supabase (PostgreSQL)                                                   |
| Auth               | Supabase Auth (email + password, admin only)                            |
| Storage            | Supabase Storage (bucket `announcements`)                               |
| Push Notification  | Firebase Cloud Messaging (FCM) + Supabase Edge Function sebagai trigger |
| Kompresi Gambar    | Package `flutter_image_compress` (client-side, sebelum upload)          |
| Real-time          | Supabase Realtime (channel `announcements`)                             |
| State Management   | Riverpod / BLoC                                                         |

---

## 3. Core Features

### 3.1 Push Notification Otomatis

- Setiap kali admin menyimpan pengumuman baru (status: published), Supabase Database Webhook / Edge Function memanggil FCM API.
- Notifikasi berisi: judul pengumuman + preview isi (maks. 100 karakter).
- Tapping notifikasi langsung membuka halaman detail pengumuman yang relevan (deep link).
- Token FCM disimpan di tabel `device_tokens` di Supabase, diregistrasi saat aplikasi pertama dibuka.

### 3.2 Auto Image Compress

- Menggunakan `flutter_image_compress` di sisi Flutter sebelum file dikirim ke Supabase Storage.
- Logika kompresi:
  - Target kualitas: 70–80% (JPEG).
  - Resolusi maksimum: 1280 × 720 px (downscale jika lebih besar).
  - Ukuran output maksimum: ± 500 KB.
- Admin tidak perlu melakukan apa pun; kompresi berjalan otomatis di background saat memilih gambar.
- Format output: JPEG (konversi dari PNG/HEIC/WebP secara otomatis).

### 3.3 CMS Admin (Login-gated)

- Halaman login terpisah (`/admin/login`), tidak muncul di navigasi warga.
- Setelah login, admin masuk ke panel CMS dengan bottom navigation khusus.
- CRUD pengumuman lengkap dengan preview sebelum publish.
- Field yang tersedia: Judul, Kategori, Isi (rich text sederhana), Gambar (opsional), Status (Draft / Published).

### 3.4 Feed Pengumuman Warga (Tanpa Login)

- Infinite scroll / pagination (10 item per halaman).
- Setiap card menampilkan: thumbnail gambar, judul, kategori badge, tanggal, preview isi.
- Realtime update: pengumuman baru muncul otomatis tanpa perlu refresh manual.
- Pull-to-refresh tersedia sebagai fallback.

### 3.5 Halaman Detail Pengumuman

- Gambar full-width di bagian atas (jika ada).
- Judul, tanggal publish, badge kategori.
- Isi pengumuman lengkap.
- Tombol share (native share sheet).

---

## 4. Design & Frontend

### 4.1 Design Principles

- **Simpel & mudah dibaca** — target pengguna adalah seluruh warga desa dari berbagai usia.
- **Tipografi besar** — ukuran teks minimal 14sp untuk body, 18sp untuk judul card.
- **Warna** — palet utama mengacu warna khas pemerintahan/desa: hijau daun (`#2E7D32`) sebagai primary, putih sebagai background, abu muda untuk card.
- **Contrast tinggi** — teks hitam/gelap di atas background terang agar mudah dibaca di luar ruangan.

### 4.2 Halaman & Komponen

#### A. Splash Screen

- Logo/nama desa + loading indicator.
- Durasi: 1–2 detik, lalu navigasi ke Home.

#### B. Home — Feed Pengumuman (Warga)

```
┌─────────────────────────────┐
│  🏡 Desa [Nama Desa]        │  ← AppBar dengan nama desa & ikon notif
│─────────────────────────────│
│  [ Semua ] [ Umum ] [ Acara ] ... │  ← Filter chip kategori (horizontal scroll)
│─────────────────────────────│
│  ┌─────────────────────────┐│
│  │ [Thumbnail]             ││  ← Card pengumuman
│  │ 🏷 Kesehatan            ││
│  │ Judul Pengumuman Desa   ││
│  │ 12 Mei 2025             ││
│  │ Preview isi singkat...  ││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ ...                     ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

- Tidak ada bottom navigation bar untuk warga.
- Search bar di bawah AppBar (bisa di-collapse saat scroll).

#### C. Detail Pengumuman

```
┌─────────────────────────────┐
│ ←  Detail Pengumuman    [↗] │  ← AppBar + tombol share
│─────────────────────────────│
│ [Gambar Full-Width]         │
│─────────────────────────────│
│ 🏷 Kategori  •  12 Mei 2025 │
│                             │
│ Judul Pengumuman Lengkap    │
│─────────────────────────────│
│ Isi pengumuman lengkap...   │
│ Lorem ipsum dolor sit amet  │
│ consectetur adipiscing elit │
│ ...                         │
└─────────────────────────────┘
```

#### D. Admin Login

```
┌─────────────────────────────┐
│                             │
│  🔐 Login Admin             │
│     Panel Desa              │
│                             │
│  [Email              ]      │
│  [Password           ]      │
│                             │
│  [ Masuk ]                  │
│                             │
└─────────────────────────────┘
```

- Tombol "Masuk sebagai Admin" tersembunyi di halaman Home (misal: tap logo 3x) atau via route langsung `/admin`.

#### E. Admin — Dashboard CMS

```
┌─────────────────────────────┐
│  CMS Desa             [+ ] │  ← Tombol buat pengumuman baru
│─────────────────────────────│
│  ┌─────────────────────────┐│
│  │ Judul Pengumuman A      ││
│  │ Draft  •  10 Mei 2025   ││
│  │ [Edit]  [Hapus]         ││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ Judul Pengumuman B      ││
│  │ Published • 8 Mei 2025  ││
│  │ [Edit]  [Hapus]         ││
│  └─────────────────────────┘│
│─────────────────────────────│
│  🏠 Home   📋 Kelola   👤 Akun │  ← Bottom Nav Admin
└─────────────────────────────┘
```

#### F. Admin — Form Buat / Edit Pengumuman

```
┌─────────────────────────────┐
│ ←  Buat Pengumuman          │
│─────────────────────────────│
│  Judul *                    │
│  [________________________] │
│                             │
│  Kategori *                 │
│  [Dropdown ▼]               │
│                             │
│  Isi Pengumuman *           │
│  [                        ] │
│  [        Text Area       ] │
│  [                        ] │
│                             │
│  Gambar (Opsional)          │
│  [📷 Pilih Gambar]          │
│  → Auto-compress aktif      │
│                             │
│  Status                     │
│  ○ Draft   ● Published      │
│                             │
│  [ Simpan Pengumuman ]      │
└─────────────────────────────┘
```

### 4.3 Design System

| Elemen             | Spesifikasi              |
| ------------------ | ------------------------ |
| Primary Color      | `#2E7D32` (Hijau desa)   |
| Secondary Color    | `#A5D6A7` (Hijau muda)   |
| Background         | `#FFFFFF`                |
| Card Background    | `#F5F5F5`                |
| Text Primary       | `#212121`                |
| Text Secondary     | `#757575`                |
| Error              | `#D32F2F`                |
| Font               | `Poppins` (Google Fonts) |
| Border Radius Card | 12px                     |
| Elevation Card     | 2dp                      |
| Padding Global     | 16px                     |
| AppBar Height      | 56dp (default Material)  |

---

## 5. User Flow

### 5.1 Flow Warga (Guest)

```
Buka Aplikasi
      │
      ▼
Splash Screen (1–2 detik)
      │
      ▼
Home — Daftar Pengumuman
      │
      ├──[Tap card]──────────────────────────────► Detail Pengumuman
      │                                                    │
      │                                            [Tap share]
      │                                                    │
      │                                            Native Share Sheet
      │
      ├──[Filter kategori]───────────────────────► Daftar Difilter
      │
      ├──[Search]────────────────────────────────► Hasil Pencarian
      │                                                    │
      │                                            [Tap hasil]
      │                                                    │
      │                                            Detail Pengumuman
      │
      └──[Terima notifikasi]─────────────────────► Detail Pengumuman (deep link)
```

### 5.2 Flow Admin

```
Akses /admin atau trigger tersembunyi
      │
      ▼
Halaman Login Admin
      │
      ├──[Kredensial salah]──► Tampil pesan error, tetap di halaman login
      │
      └──[Kredensial benar]──► Dashboard CMS Admin
                                      │
                    ┌─────────────────┼──────────────────────┐
                    ▼                 ▼                       ▼
            [Tap + Buat]      [Tap Edit]                [Tap Hapus]
                    │                 │                       │
                    ▼                 ▼                       ▼
            Form Buat           Form Edit              Konfirmasi Dialog
            Pengumuman          Pengumuman             "Hapus pengumuman ini?"
                    │                 │                   │         │
                    ▼                 ▼                  [Ya]      [Batal]
            [Pilih Gambar]    [Ubah field]               │
                    │                 │                   ▼
            Auto Compress     [Simpan]             Pengumuman terhapus
                    │                 │
                    ▼                 │
            [Simpan + Publish]◄───────┘
                    │
                    ▼
            Pengumuman tersimpan di Supabase
                    │
                    ▼
            Edge Function dipicu otomatis
                    │
                    ▼
            FCM mengirim notifikasi ke semua device
                    │
                    ▼
            Warga menerima notifikasi push
```

### 5.3 Flow Kompresi Gambar (Admin Upload)

```
Admin tap [Pilih Gambar]
      │
      ▼
Image Picker — pilih dari galeri / kamera
      │
      ▼
flutter_image_compress dijalankan di isolate terpisah
      │
      ├── Resize jika > 1280×720 px
      ├── Konversi ke JPEG
      └── Kompres ke kualitas 75%
      │
      ▼
Preview gambar hasil kompres ditampilkan di form
(+ info ukuran akhir, misal "Gambar: 234 KB")
      │
      ▼
Admin tap [Simpan Pengumuman]
      │
      ▼
File terkompresi diupload ke Supabase Storage
(bucket: announcements / folder: images/)
      │
      ▼
URL publik gambar disimpan di tabel announcements
```

---

## 6. Database Schema (Referensi)

### Tabel: `announcements`

| Kolom        | Tipe        | Keterangan                                            |
| ------------ | ----------- | ----------------------------------------------------- |
| `id`         | UUID        | Primary key                                           |
| `title`      | TEXT        | Judul pengumuman                                      |
| `content`    | TEXT        | Isi lengkap                                           |
| `category`   | TEXT        | Enum: umum, kesehatan, infrastruktur, keuangan, acara |
| `image_url`  | TEXT        | URL gambar di Supabase Storage (nullable)             |
| `status`     | TEXT        | `draft` atau `published`                              |
| `created_at` | TIMESTAMPTZ | Waktu dibuat                                          |
| `updated_at` | TIMESTAMPTZ | Waktu diperbarui                                      |
| `view_count` | INTEGER     | Jumlah view (opsional)                                |

### Tabel: `device_tokens`

| Kolom        | Tipe        | Keterangan       |
| ------------ | ----------- | ---------------- |
| `id`         | UUID        | Primary key      |
| `token`      | TEXT        | FCM token device |
| `created_at` | TIMESTAMPTZ | Waktu registrasi |

---

_PRD ini mencakup: Design/Frontend, Requirements, Core Features, dan User Flow._
_Dokumen teknis lanjutan (API contract, RLS policies, Edge Function code) dibuat terpisah._

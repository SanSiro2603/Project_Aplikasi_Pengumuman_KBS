<p align="center">
  <img src="assets/icon/app_icon.png" alt="Logo Pengumuman KBS" width="120" />
</p>

# 1. Nama Project

<h1 align="center">Pengumuman KBS</h1>

<p align="center">
  <strong>Aplikasi Pengumuman Kampung Baru Sukaraja</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=0B1F1A" alt="Supabase" />
  <img src="https://img.shields.io/badge/OneSignal-E54B4D?style=for-the-badge&logo=onesignal&logoColor=white" alt="OneSignal" />
</p>

## 2. Deskripsi Singkat

Pengumuman KBS adalah aplikasi mobile untuk menyampaikan informasi resmi Kampung Baru Sukaraja kepada warga secara cepat, rapi, dan real-time. Warga dapat membaca pengumuman tanpa login, sementara admin dapat mengelola konten melalui panel khusus.

Aplikasi ini dibuat agar informasi penting seperti kegiatan warga, kesehatan, infrastruktur, keuangan, dan acara kampung bisa tersampaikan lebih mudah lewat perangkat mobile.

## 3. Problem atau Masalah yang Diselesaikan

- Pengumuman manual mudah terlewat karena hanya tersebar lewat papan informasi, grup chat, atau pesan berantai.
- Informasi tidak selalu sampai ke semua warga secara merata dan tepat waktu.
- Admin membutuhkan media terpusat untuk membuat, mengedit, mempublikasikan, dan menghapus pengumuman.
- Warga membutuhkan akses informasi yang sederhana tanpa proses login yang menyulitkan.
- Pengumuman penting perlu didukung notifikasi agar warga segera mengetahui informasi terbaru.

## 4. Fitur Utama

- Feed pengumuman warga tanpa login.
- Pencarian pengumuman berdasarkan judul, isi, atau kategori.
- Filter pengumuman berdasarkan kategori dan tanggal.
- Kategori pengumuman: umum, kesehatan, infrastruktur, keuangan, dan acara.
- Preview gambar pengumuman dan halaman detail dengan tampilan gambar yang bisa diperbesar.
- Panel admin untuk membuat, mengedit, menghapus, dan mengatur status pengumuman.
- Status pengumuman draft dan published.
- Data pengumuman real-time menggunakan Supabase Realtime.
- Push notification menggunakan OneSignal saat pengumuman baru dipublikasikan.
- Dukungan distribusi APK mandiri dengan manifest update.

## 5. Screenshot

<p align="center">
  <img src="docs/screenshots/home-portrait.png" alt="Screenshot halaman utama Pengumuman KBS" width="360" />
</p>

## 6. Tech Stack + Icon

<p>
  <img src="https://img.shields.io/badge/Flutter-Framework_UI-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-Bahasa_Aplikasi-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-Database_Realtime-3FCF8E?style=for-the-badge&logo=supabase&logoColor=0B1F1A" alt="Supabase" />
  <img src="https://img.shields.io/badge/Riverpod-State_Management-40B7FF?style=for-the-badge&logo=flutter&logoColor=white" alt="Riverpod" />
  <img src="https://img.shields.io/badge/GoRouter-Navigasi-0B57D0?style=for-the-badge&logo=googlemaps&logoColor=white" alt="GoRouter" />
  <img src="https://img.shields.io/badge/OneSignal-Push_Notification-E54B4D?style=for-the-badge&logo=onesignal&logoColor=white" alt="OneSignal" />
  <img src="https://img.shields.io/badge/Android-Mobile_APK-3DDC84?style=for-the-badge&logo=android&logoColor=0B1F1A" alt="Android" />
  <img src="https://img.shields.io/badge/GitHub_Actions-CI/CD-2088FF?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions" />
  <img src="https://img.shields.io/badge/Lottie-Animasi-00DDB3?style=for-the-badge&logo=lottie&logoColor=white" alt="Lottie" />
</p>

| Teknologi | Fungsi |
| --- | --- |
| Flutter | Framework utama untuk membangun aplikasi mobile lintas platform. |
| Dart | Bahasa pemrograman utama aplikasi. |
| Supabase | Backend untuk database, authentication, storage gambar, dan realtime stream. |
| Riverpod | State management untuk mengelola data pengumuman dan admin. |
| GoRouter | Navigasi antar halaman seperti splash, home, detail, login admin, dan dashboard admin. |
| OneSignal | Push notification untuk pengumuman baru. |
| Android | Target distribusi APK untuk pengguna mobile. |
| GitHub Actions | Workflow CI/CD, build, dan distribusi release. |
| Lottie | Animasi ringan untuk mempercantik pengalaman pengguna. |

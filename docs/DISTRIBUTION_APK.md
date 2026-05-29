# Distribusi Mandiri APK (GitHub Pages + GitHub Releases)

## 1) Arsitektur Distribusi
- Landing page publik: `distribution_site/index.html`
- File update manifest: `distribution_site/latest.json`
- File APK release: GitHub Releases (split ABI)

## 2) Policy Update
- **Force update**:
  - versi major naik (`1.x.x` -> `2.x.x`), atau
  - `version_code` client di bawah `min_supported_version_code`
- **Optional update**:
  - patch/minor lebih baru, tapi masih di atas batas minimum support.

## 3) Build Output
Workflow `Release Distribution` menghasilkan:
- `app-v<version>-arm64-v8a.apk`
- `app-v<version>-armeabi-v7a.apk`
- `app-v<version>-x86_64.apk`
- `sha256sums.txt`
- `size-summary.txt`
- `latest.json`

Semua APK wajib `< 40MB`, jika tidak workflow otomatis gagal.

## 4) Secrets Yang Dibutuhkan (GitHub Actions)
- `SUPABASE_URL_PROD`
- `SUPABASE_ANON_KEY_PROD`
- `ONESIGNAL_APP_ID_PROD`
- Opsional: `UPDATE_MANIFEST_URL_PROD`

Jika `UPDATE_MANIFEST_URL_PROD` kosong, workflow default ke:
`https://<owner>.github.io/<repo>/latest.json`

## 5) Rollback Cepat
Jika release bermasalah:
1. Jalankan ulang workflow release untuk versi stabil sebelumnya, atau
2. Edit `distribution_site/latest.json` ke versi stabil, lalu deploy halaman ulang.

## 6) Testing Checklist
- Download link sesuai ABI aktif.
- Dialog update force/optional sesuai policy.
- App tetap jalan saat fetch `latest.json` gagal (menggunakan cache lokal).

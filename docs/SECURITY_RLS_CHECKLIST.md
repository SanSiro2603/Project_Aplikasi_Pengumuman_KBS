# Security & RLS Regression Checklist

## Secrets
- [ ] Tidak ada anon/service key hardcoded di source code.
- [ ] Runtime config memakai env/secret manager.
- [ ] Vault secret tersedia:
  - `supabase_project_url`
  - `supabase_anon_key`

## Auth Guard
- [ ] User tanpa role `admin` tidak bisa akses `/admin/*`.
- [ ] Login admin menolak akun non-admin.

## RLS: announcements
- [ ] Public hanya bisa `select` data `status='published'`.
- [ ] Non-admin tidak bisa insert/update/delete.
- [ ] Admin bisa CRUD.

## RLS: device_tokens
- [ ] Public hanya bisa insert token UUID.
- [ ] Public tidak bisa select semua token.
- [ ] Admin boleh read token.

## Logs & Audit
- [ ] `app_errors` menerima error client.
- [ ] `notification_dispatch_log` terisi saat publish.
- [ ] Idempotency bekerja (publish event sama tidak double-send).


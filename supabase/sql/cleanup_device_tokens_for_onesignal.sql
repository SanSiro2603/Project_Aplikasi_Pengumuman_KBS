-- Bersihkan token FCM lama dan siapkan penyimpanan OneSignal subscription id (UUID)
-- Jalankan di Supabase SQL Editor

-- 1) Hapus token lama format FCM (...:APA91...)
delete from public.device_tokens
where token like '%:APA91%';

-- 2) Hapus token yang bukan UUID (bukan subscription id OneSignal)
delete from public.device_tokens
where token !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

-- 3) Pastikan indeks unik agar token tidak duplikat
create unique index if not exists device_tokens_token_unique
on public.device_tokens (token);


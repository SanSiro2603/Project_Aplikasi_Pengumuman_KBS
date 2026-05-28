-- Pastikan app client bisa menyimpan OneSignal subscription id ke device_tokens
-- Jalankan di Supabase SQL Editor

alter table public.device_tokens enable row level security;

grant select, insert on table public.device_tokens to anon, authenticated;

drop policy if exists "device_tokens_insert_public" on public.device_tokens;
create policy "device_tokens_insert_public"
on public.device_tokens
for insert
to anon, authenticated
with check (true);

drop policy if exists "device_tokens_select_public" on public.device_tokens;
create policy "device_tokens_select_public"
on public.device_tokens
for select
to anon, authenticated
using (true);

-- Opsional: cegah duplikasi
create unique index if not exists device_tokens_token_unique
on public.device_tokens (token);


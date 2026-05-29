-- Legacy helper script.
-- Canonical policy lives in:
-- supabase/migrations/202605280001_core_hardening.sql

alter table public.device_tokens enable row level security;

grant insert on table public.device_tokens to anon, authenticated;
grant select on table public.device_tokens to authenticated;

drop policy if exists "device_tokens_insert_public" on public.device_tokens;
create policy "device_tokens_insert_public"
on public.device_tokens
for insert
to anon, authenticated
with check (
  token ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
);

drop policy if exists "device_tokens_select_public" on public.device_tokens;
create policy "device_tokens_select_admin_only"
on public.device_tokens
for select
to authenticated
using (
  coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin',
    false
  )
);

-- Opsional: cegah duplikasi
create unique index if not exists device_tokens_token_unique
on public.device_tokens (token);

create extension if not exists pgcrypto;
create extension if not exists pg_net;
create extension if not exists vault;

create table if not exists public.app_errors (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  level text not null default 'error',
  message text not null,
  stack_trace text,
  context jsonb not null default '{}'::jsonb,
  user_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_dispatch_log (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  event_type text not null default 'published',
  request_id uuid,
  target_mode text,
  target_count integer not null default 0,
  provider_status text not null default 'pending',
  provider_http_status integer,
  provider_response jsonb,
  attempt_count integer not null default 0,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (announcement_id, event_type)
);

alter table public.announcements enable row level security;
alter table public.device_tokens enable row level security;
alter table public.app_errors enable row level security;
alter table public.notification_dispatch_log enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin',
    false
  );
$$;

drop policy if exists "Public can view published announcements" on public.announcements;
drop policy if exists "Admins can do everything on announcements" on public.announcements;

create policy "public_read_published_announcements"
on public.announcements
for select
using (status = 'published' or public.is_admin());

create policy "admin_crud_announcements"
on public.announcements
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Public can insert device tokens" on public.device_tokens;
drop policy if exists "Admins can view device tokens" on public.device_tokens;
drop policy if exists "device_tokens_insert_public" on public.device_tokens;
drop policy if exists "device_tokens_select_public" on public.device_tokens;

create policy "public_insert_device_tokens"
on public.device_tokens
for insert
to anon, authenticated
with check (
  token ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
);

create policy "admin_select_device_tokens"
on public.device_tokens
for select
to authenticated
using (public.is_admin());

create unique index if not exists device_tokens_token_unique
on public.device_tokens(token);

create policy "client_insert_app_errors"
on public.app_errors
for insert
to anon, authenticated
with check (length(message) <= 1000 and length(source) <= 120);

create policy "admin_read_app_errors"
on public.app_errors
for select
to authenticated
using (public.is_admin());

create policy "service_role_manage_dispatch_log"
on public.notification_dispatch_log
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());


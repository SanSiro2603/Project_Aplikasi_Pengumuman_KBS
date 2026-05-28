-- Auto-trigger push notifications when announcements are published
-- Run this in Supabase SQL Editor.

create extension if not exists pg_net;

create or replace function public.notify_warga_on_publish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project_url text := 'https://pmyhqrtfmqokyxhccvfh.supabase.co';
  v_anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBteWhxcnRmbXFva3l4aGNjdmZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwOTE2MzMsImV4cCI6MjA5NDY2NzYzM30.K1sEHXN_YZGHvPKi9ZRr7jLsj4mEehVF8cTNI0DDM-o';
  v_payload jsonb;
begin
  -- INSERT: only notify if the new row is published
  if tg_op = 'INSERT' and new.status is distinct from 'published' then
    return new;
  end if;

  -- UPDATE: notify only when status changes to published
  if tg_op = 'UPDATE' and (
    new.status is distinct from 'published'
    or old.status = 'published'
  ) then
    return new;
  end if;

  v_payload := jsonb_build_object(
    'record',
    jsonb_build_object(
      'id', new.id,
      'title', new.title,
      'category', new.category,
      'status', new.status
    )
  );

  perform net.http_post(
    url := v_project_url || '/functions/v1/notify_warga',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_anon_key,
      'Authorization', 'Bearer ' || v_anon_key
    ),
    body := v_payload
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_warga_on_publish on public.announcements;

create trigger trg_notify_warga_on_publish
after insert or update of status on public.announcements
for each row
execute function public.notify_warga_on_publish();

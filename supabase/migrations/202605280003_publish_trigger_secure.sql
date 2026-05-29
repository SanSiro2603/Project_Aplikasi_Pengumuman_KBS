create extension if not exists pg_net;
create extension if not exists vault;

create or replace function public.notify_warga_on_publish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project_url text;
  v_anon_key text;
  v_payload jsonb;
begin
  -- INSERT: only notify if the new row is published
  if tg_op = 'INSERT' and new.status is distinct from 'published' then
    return new;
  end if;

  -- UPDATE: notify only when status changes to published
  if tg_op = 'UPDATE' and (new.status is distinct from 'published' or old.status = 'published') then
    return new;
  end if;

  select decrypted_secret into v_project_url
  from vault.decrypted_secrets
  where name = 'supabase_project_url'
  limit 1;

  select decrypted_secret into v_anon_key
  from vault.decrypted_secrets
  where name = 'supabase_anon_key'
  limit 1;

  if v_project_url is null or v_anon_key is null then
    raise exception 'Missing vault secrets: supabase_project_url/supabase_anon_key';
  end if;

  v_payload := jsonb_build_object(
    'record',
    jsonb_build_object(
      'id', new.id,
      'title', new.title,
      'category', new.category,
      'status', new.status,
      'image_url', new.image_url
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


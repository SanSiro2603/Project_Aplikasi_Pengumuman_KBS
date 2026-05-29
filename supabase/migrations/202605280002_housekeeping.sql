create extension if not exists pg_cron;

create or replace function public.cleanup_notification_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.device_tokens
  where token !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

  delete from public.notification_dispatch_log
  where created_at < now() - interval '90 days';

  delete from public.app_errors
  where created_at < now() - interval '30 days';
end;
$$;

do $$
begin
  if not exists (
    select 1 from cron.job where jobname = 'cleanup_notification_data_daily'
  ) then
    perform cron.schedule(
      'cleanup_notification_data_daily',
      '30 2 * * *',
      $$select public.cleanup_notification_data();$$
    );
  end if;
end
$$;


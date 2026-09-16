-- Only for the existing App project. Uses its existing encrypted cron credentials.
-- One job every five minutes; SQL enforces <=20 background lookups/day within <=50 total/day.
-- Rollback: select cron.unschedule('wif-trip-worker-every-five-minutes');
do $$ begin
 if (select decrypted_secret from vault.decrypted_secrets where name='wif_project_url')
     is distinct from 'https://cdhpaujazbuppbxyhjxq.supabase.co' then raise exception 'Unexpected worker origin.'; end if;
 if not exists(select 1 from vault.secrets where name='wif_push_worker_secret')
     or not exists(select 1 from vault.secrets where name='wif_publishable_key') then raise exception 'Worker credentials missing.'; end if;
end $$;
select cron.schedule('wif-trip-worker-every-five-minutes','*/5 * * * *',$schedule$
    select net.http_post(
      url:=(select decrypted_secret from vault.decrypted_secrets where name='wif_project_url')||'/functions/v1/trip-worker',
      headers:=jsonb_build_object('Content-Type','application/json',
        'apikey',(select decrypted_secret from vault.decrypted_secrets where name='wif_publishable_key'),
        'Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='wif_push_worker_secret')),
      body:=jsonb_build_object('scheduledAt',now()), timeout_milliseconds:=45000
    );
$schedule$);

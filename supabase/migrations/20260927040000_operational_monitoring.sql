begin;

create table public.wif_ops_events (
 source text not null check(source in ('server','client')), event_id uuid not null,
 feature text not null check(feature in ('login','home','plans','trips','notifications')),
 kind text not null check(kind in ('server_error','decode_error','timeout','slow_request','push_configuration')),
 status integer not null check(status between 0 and 599), elapsed_ms integer not null check(elapsed_ms between 0 and 120000),
 app_version text not null check(app_version ~ '^[a-zA-Z0-9._+()-]{1,32}$'), actor_key text,
 received_at timestamptz not null default now(), primary key(source,event_id)
);
create index wif_ops_event_window on public.wif_ops_events(received_at desc);
create index wif_ops_actor_budget on public.wif_ops_events(actor_key,received_at) where source='client';
create table public.wif_ops_ingest_budget(bucket timestamptz primary key,events integer not null);
create table public.wif_ops_workers(worker text primary key check(worker in ('push','trip')),last_success timestamptz,last_attempt timestamptz);
create table public.wif_ops_settings(id boolean primary key default true check(id),enabled_at timestamptz not null default now(),expect_push boolean not null default false,expect_trip boolean not null default false);
insert into public.wif_ops_settings(id) values(true);
create table public.wif_ops_probe_visits(id boolean primary key default true check(id),last_probe_at timestamptz,last_external_at timestamptz,previous_external_at timestamptz,external_checks bigint not null default 0);
insert into public.wif_ops_probe_visits(id) values(true);
-- First-enqueued time survives retry backoff; older rows conservatively start at installation time.
alter table public.upcoming_deliveries add column created_at timestamptz not null default now();

create function public.wif_ops_record_event(p_source text,p_event_id uuid,p_feature text,p_kind text,p_status integer,p_elapsed_ms integer,p_version text,p_auth_id uuid default null)
returns boolean language plpgsql security definer set search_path=public,extensions as $$
declare v_actor text; v_count integer; v_bucket timestamptz:=date_trunc('minute',now());
begin
 if p_source is null or p_source not in ('server','client') or p_event_id is null or p_feature is null or p_feature not in ('login','home','plans','trips','notifications')
 or p_kind is null or p_kind not in ('server_error','decode_error','timeout','slow_request','push_configuration') or p_status is null or p_status not between 0 and 599
 or p_elapsed_ms is null or p_elapsed_ms not between 0 and 120000 or p_version is null or p_version!~'^[a-zA-Z0-9._+()-]{1,32}$' then raise exception 'Invalid operational event.';end if;
 if exists(select 1 from wif_ops_events where source=p_source and event_id=p_event_id) then return false;end if;
 if p_source='client' then
  if p_auth_id is null or not exists(select 1 from auth.users where id=p_auth_id) or p_kind not in ('server_error','decode_error','timeout') then raise exception 'Invalid client event.';end if;
  v_actor:=md5(p_auth_id::text||':'||current_date::text);
  perform pg_advisory_xact_lock(hashtextextended('ops:'||v_actor,0));
  if (select count(*) from wif_ops_events where source='client' and actor_key=v_actor and received_at>now()-interval '1 hour')>=10 then return false;end if;
 end if;
 insert into wif_ops_ingest_budget(bucket,events) values(v_bucket,1)
 on conflict(bucket) do update set events=wif_ops_ingest_budget.events+1 where wif_ops_ingest_budget.events<30 returning events into v_count;
 if v_count is null then return false;end if;
 if v_count=1 then perform wif_ops_prune();end if;
 insert into wif_ops_events(source,event_id,feature,kind,status,elapsed_ms,app_version,actor_key)
 values(p_source,p_event_id,p_feature,p_kind,p_status,p_elapsed_ms,p_version,v_actor) on conflict do nothing;
 return found;
end; $$;

create function public.wif_ops_worker_heartbeat(p_worker text,p_ok boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 if p_worker is null or p_worker not in ('push','trip') or p_ok is null then raise exception 'Invalid worker.';end if;
 insert into wif_ops_workers(worker,last_attempt,last_success) values(p_worker,now(),case when p_ok then now() end)
 on conflict(worker) do update set last_attempt=excluded.last_attempt,last_success=case when p_ok then excluded.last_success else wif_ops_workers.last_success end;
end; $$;

create function public.wif_ops_probe_seen(p_external boolean) returns void language plpgsql security definer set search_path=public as $$
begin
 if p_external is null then raise exception 'Probe source required.';end if;
 update wif_ops_probe_visits set last_probe_at=now(),
 previous_external_at=case when p_external and (last_external_at is null or last_external_at<now()-interval '4 minutes') then last_external_at else previous_external_at end,
 external_checks=external_checks+case when p_external and (last_external_at is null or last_external_at<now()-interval '4 minutes') then 1 else 0 end,
 last_external_at=case when p_external and (last_external_at is null or last_external_at<now()-interval '4 minutes') then now() else last_external_at end
 where id=true;
end; $$;

create function public.wif_ops_prune() returns void language plpgsql security definer set search_path=public as $$
begin
 delete from wif_ops_events where received_at<now()-interval '3 days' or received_at<(select received_at from wif_ops_events order by received_at desc offset 9999 limit 1);
 delete from wif_ops_ingest_budget where bucket<now()-interval '2 hours';
end; $$;

create function public.wif_ops_health() returns jsonb language sql stable security definer set search_path=public as $$
 with pending as (
  select 'booking' kind,r.created_at as queued_at from trip_booking_deliveries d join trip_booking_reminders r on r.id=d.reminder_id
   where d.status='pending' and (d.available_at<=now() or d.attempts>0) and wif_trip_booking_allowed(r.id,d.device_id)
  union all select 'upcoming',d.created_at from upcoming_deliveries d where d.status='pending' and (d.available_at<=now() or d.attempts>0) and wif_travel_delivery_allowed(d)
  union all select 'flights',e.created_at from trip_flight_deliveries d join trip_flight_events e on e.id=d.event_id
   where d.status='pending' and (d.available_at<=now() or d.attempts>0) and wif_trip_delivery_allowed(d)
  union all select 'friend_invites',a.created_at from friend_invitation_deliveries d join friend_invitation_alerts a on a.id=d.alert_id
   where d.status='pending' and (d.available_at<=now() or d.attempts>0) and wif_friend_invitation_allowed(d.alert_id,d.recipient_id,d.device_id)
  union all select 'trip_invites',a.created_at from trip_invitation_deliveries d join trip_invitation_alerts a on a.invitation_id=d.invitation_id
   where d.status='pending' and (d.available_at<=now() or d.attempts>0) and wif_trip_invitation_alert_allowed(d.invitation_id,d.recipient_id,d.device_id)
  union all select 'colocation',nd.created_at from notification_deliveries nd
   join notification_outbox o on o.id=nd.outbox_id join colocation_events e on e.id=o.event_id
   join devices d on d.id=nd.device_id and d.user_id=e.recipient_id and d.disabled_at is null
   join current_presence p on p.user_id=e.recipient_id join current_presence f on f.user_id=e.friend_id
   join user_sharing_settings ps on ps.user_id=p.user_id and ps.city_sharing_enabled
   join user_sharing_settings fs on fs.user_id=f.user_id and fs.city_sharing_enabled
   left join sharing_preferences pp on pp.owner_id=p.user_id and pp.friend_id=f.user_id
   left join sharing_preferences fp on fp.owner_id=f.user_id and fp.friend_id=p.user_id
   where nd.status='pending' and (nd.available_at<=now() or nd.attempts>0) and wif_are_friends(p.user_id,f.user_id)
    and coalesce(pp.shares_city,true) and coalesce(fp.shares_city,true) and coalesce(pp.same_city_alert,true)
    and p.sharing_state='active' and f.sharing_state='active' and p.normalized_city_id=f.normalized_city_id and p.normalized_city_id=e.normalized_city_id
    and p.client_updated_at between now()-interval '24 hours' and now()+interval '1 minute'
    and f.client_updated_at between now()-interval '24 hours' and now()+interval '1 minute' and e.created_at>now()-interval '24 hours'
    and not exists(select 1 from user_blocks b where (b.blocker_id=p.user_id and b.blocked_id=f.user_id) or (b.blocker_id=f.user_id and b.blocked_id=p.user_id))
 ), windows as (
  select feature,count(distinct event_id) filter(where kind='server_error' and received_at>now()-interval '5 minutes') server_errors,
   count(distinct event_id) filter(where source='client' and kind='decode_error' and received_at>now()-interval '10 minutes') decode_errors,
   count(*) filter(where kind='timeout' and received_at>now()-interval '5 minutes') timeouts,
   count(*) filter(where kind='push_configuration' and received_at>now()-interval '10 minutes') push_errors,
   count(*) filter(where kind='slow_request' and received_at>now()-interval '10 minutes') slow_reports,
   count(distinct date_trunc('minute',received_at)) filter(where kind='slow_request' and received_at>now()-interval '10 minutes') slow_minutes
  from wif_ops_events where received_at>now()-interval '10 minutes' group by feature
 ) select jsonb_build_object('checked_at',now(),'features',coalesce((select jsonb_agg(to_jsonb(w)) from windows w),'[]'),
 'queues',coalesce((select jsonb_agg(to_jsonb(q)) from (select kind,count(*) pending,count(*) filter(where queued_at<now()-interval '10 minutes') overdue,
  greatest(0,extract(epoch from now()-min(queued_at)))::integer oldest_seconds from pending group by kind)q),'[]'),
 'workers',(select jsonb_agg(jsonb_build_object('worker',n.name,'expected',case n.name when 'push' then s.expect_push else s.expect_trip end,
 'enabled_at',s.enabled_at,'last_success',w.last_success,'last_attempt',w.last_attempt)) from (values('push'),('trip'))n(name)
 cross join wif_ops_settings s left join wif_ops_workers w on w.worker=n.name));
$$;

do $$ declare t text; f regprocedure; r text;begin
 foreach t in array array['wif_ops_events','wif_ops_ingest_budget','wif_ops_workers','wif_ops_settings','wif_ops_probe_visits'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public',t);
  foreach r in array array['anon','authenticated'] loop
   if exists(select 1 from pg_roles where rolname=r) then execute format('revoke all on public.%I from %I',t,r);end if;
  end loop;
 end loop;
 for f in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname ~ '^wif_ops_' loop
  execute format('revoke all on function %s from public',f);
  foreach r in array array['anon','authenticated'] loop
   if exists(select 1 from pg_roles where rolname=r) then execute format('revoke all on function %s from %I',f,r);end if;
  end loop;
  if exists(select 1 from pg_roles where rolname='service_role') then execute format('grant execute on function %s to service_role',f);end if;
 end loop;
end $$;
commit;

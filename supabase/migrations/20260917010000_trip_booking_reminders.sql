begin;

-- Visiting Trips enrolls this account with the device's current IANA time zone.
-- Existing accounts are not silently assigned a guessed location/time zone.
create table public.trip_reminder_context (
 user_id uuid primary key references public.app_users(id) on delete cascade,
 time_zone text not null, locale text not null check(locale in ('en','zh-Hans')),
 updated_at timestamptz not null default now()
);
alter table public.trip_members add column planning_reminders_enabled boolean not null default true;
create table public.trip_booking_reminders (
 id uuid primary key default gen_random_uuid(), trip_id text not null,
 recipient_id uuid not null, sender_id uuid, kind text not null check(kind in ('daily','manual')),
 scheduled_day date not null, created_at timestamptz not null default now(), expires_at timestamptz not null,
 foreign key(trip_id,recipient_id) references public.trip_members(trip_id,user_id) on delete cascade,
 foreign key(trip_id,sender_id) references public.trip_members(trip_id,user_id) on delete cascade,
 unique(trip_id,recipient_id,kind,scheduled_day)
);
create table public.trip_booking_deliveries (
 id uuid primary key default gen_random_uuid(), reminder_id uuid not null references public.trip_booking_reminders(id) on delete cascade,
 device_id uuid not null references public.devices(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','delivered','failed')),
 attempts integer not null default 0, available_at timestamptz not null default now(),
 claim_token uuid, claimed_at timestamptz, last_error text, unique(reminder_id,device_id)
);
create index trip_booking_pending on public.trip_booking_deliveries(available_at) where status='pending';
create index trip_booking_recipient_history on public.trip_booking_reminders(trip_id,recipient_id,created_at desc);
alter table public.trip_reminder_context enable row level security;
alter table public.trip_booking_reminders enable row level security;
alter table public.trip_booking_deliveries enable row level security;
revoke all on public.trip_reminder_context,public.trip_booking_reminders,public.trip_booking_deliveries from public;

create function public.wif_trip_reminder_context(p_user_id uuid,p_time_zone text,p_locale text)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Trip access denied.'; end if;
 if p_time_zone is null or not exists(select 1 from pg_timezone_names where name=p_time_zone)
 or p_locale is null or p_locale not in ('en','zh-Hans') then raise exception 'Invalid reminder time zone or language.'; end if;
 insert into trip_reminder_context(user_id,time_zone,locale) values(p_user_id,p_time_zone,p_locale)
 on conflict(user_id) do update set time_zone=excluded.time_zone,locale=excluded.locale,updated_at=now();
 return true;
end; $$;

-- This is missing flight information, not proof of an unpurchased airline ticket.
create function public.wif_trip_needs_flight(p_trip text,p_user uuid,p_at timestamptz default now())
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from trips t join trip_members m on m.trip_id=t.id and m.user_id=p_user
 join app_users u on u.id=m.user_id and u.deleted_at is null
 join participants p on p.trip_id=t.id and p.user_id=m.user_id
 left join trip_reminder_context c on c.user_id=m.user_id
 where t.id=p_trip and t.completed_at is null and t.cancelled_at is null and m.planning_reminders_enabled
 and t.start_date>to_char(p_at at time zone coalesce(c.time_zone,'UTC'),'YYYY-MM-DD')
 and not exists(select 1 from flights f where f.trip_id=t.id and f.participant_id=p.id and (f.direction='outbound' or f.direction is null)));
$$;

create function public.wif_trip_planning_preferences(p_user_id uuid,p_trip_id text,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 perform wif_trip_assert_access(p_user_id,p_trip_id,true);
 if p_enabled is null then raise exception 'Invalid preference.'; end if;
 update trip_members set planning_reminders_enabled=p_enabled where trip_id=p_trip_id and user_id=p_user_id;
 if not p_enabled then
  -- Retain deduplication history so toggling off/on cannot resend today's reminder.
  update trip_booking_deliveries d set status='failed',claim_token=null,claimed_at=null
  from trip_booking_reminders r where d.reminder_id=r.id and r.trip_id=p_trip_id and r.recipient_id=p_user_id and d.status='pending';
 end if;
 return wif_trip_snapshot(p_user_id,p_trip_id);
end; $$;

create or replace function public.wif_trip_snapshot(p_user_id uuid,p_trip_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
 perform wif_trip_assert_access(p_user_id,p_trip_id);
 select (to_jsonb(t)-'source_project_ref'-'legacy_imported_at') || jsonb_build_object(
 'participants',(select coalesce(jsonb_agg(to_jsonb(p) order by p.joined_at,p.id),'[]') from participants p where p.trip_id=t.id),
 'flights',(select coalesce(jsonb_agg(to_jsonb(f) order by f.added_at,f.id),'[]') from flights f where f.trip_id=t.id),
 'notes',(select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at,n.id),'[]') from notes n where n.trip_id=t.id),
 'my_role',m.role,'flight_alerts_enabled',m.flight_alerts_enabled,'planning_reminders_enabled',m.planning_reminders_enabled
 ) into v_result from trips t join trip_members m on m.trip_id=t.id and m.user_id=p_user_id where t.id=p_trip_id;
 return v_result;
end; $$;

create function public.wif_trip_remind_member(p_user_id uuid,p_trip_id text,p_participant_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_target uuid; v_last timestamptz; v_day date; v_zone text;
begin
 perform wif_trip_assert_access(p_user_id,p_trip_id,true);
 select user_id into v_target from participants where trip_id=p_trip_id and id=p_participant_id;
 if v_target is null or v_target=p_user_id then raise exception 'Trip access denied.'; end if;
 if not wif_trip_needs_flight(p_trip_id,v_target) or exists(select 1 from user_blocks
 where (blocker_id=p_user_id and blocked_id=v_target) or (blocker_id=v_target and blocked_id=p_user_id))
 or not exists(select 1 from devices where user_id=v_target and disabled_at is null) then
  return jsonb_build_object('status','unavailable');
 end if;
 perform pg_advisory_xact_lock(hashtext('trip-reminder:'||p_trip_id||v_target::text));
 select max(created_at) into v_last from trip_booking_reminders where trip_id=p_trip_id and recipient_id=v_target and kind='manual';
 if v_last>now()-interval '24 hours' then return jsonb_build_object('status','cooldown','nextAllowedAt',v_last+interval '24 hours'); end if;
 select time_zone into v_zone from trip_reminder_context where user_id=v_target;
 v_day:=(now() at time zone coalesce(v_zone,'UTC'))::date;
 insert into trip_booking_reminders(trip_id,recipient_id,sender_id,kind,scheduled_day,expires_at)
 values(p_trip_id,v_target,p_user_id,'manual',v_day,now()+interval '24 hours') on conflict do nothing;
 if not found then return jsonb_build_object('status','cooldown'); end if;
 return jsonb_build_object('status','queued','nextAllowedAt',now()+interval '24 hours');
end; $$;

create function public.wif_trip_schedule_booking(p_at timestamptz default now())
returns integer language plpgsql security definer set search_path=public as $$
declare v_count integer;
begin
 insert into trip_booking_reminders(trip_id,recipient_id,kind,scheduled_day,created_at,expires_at)
 select m.trip_id,m.user_id,'daily',(p_at at time zone c.time_zone)::date,p_at,
   (((p_at at time zone c.time_zone)::date+time '10:00') at time zone c.time_zone)
 from trip_members m join trip_reminder_context c on c.user_id=m.user_id
 where (p_at at time zone c.time_zone)::time>=time '09:00' and (p_at at time zone c.time_zone)::time<time '10:00'
 and wif_trip_needs_flight(m.trip_id,m.user_id,p_at)
 and exists(select 1 from devices where user_id=m.user_id and disabled_at is null)
 and not exists(select 1 from trip_booking_reminders r where r.trip_id=m.trip_id and r.recipient_id=m.user_id and r.created_at>p_at-interval '20 hours')
 order by m.trip_id,m.user_id on conflict do nothing;
 get diagnostics v_count=row_count; return v_count;
end; $$;

create function public.wif_trip_booking_allowed(p_id uuid,p_device uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from trip_booking_reminders r
 join devices d on d.id=p_device and d.user_id=r.recipient_id and d.disabled_at is null
 left join trip_reminder_context c on c.user_id=r.recipient_id
 where r.id=p_id and r.expires_at>now() and wif_trip_needs_flight(r.trip_id,r.recipient_id)
 and (r.kind='manual' or (c.user_id is not null and (now() at time zone c.time_zone)::date=r.scheduled_day
 and (now() at time zone c.time_zone)::time>=time '09:00' and (now() at time zone c.time_zone)::time<time '10:00'))
 and (r.kind='daily' or (exists(select 1 from trip_members m join app_users u on u.id=m.user_id and u.deleted_at is null
 where m.trip_id=r.trip_id and m.user_id=r.sender_id) and not exists(select 1 from user_blocks b
 where (b.blocker_id=r.sender_id and b.blocked_id=r.recipient_id) or (b.blocker_id=r.recipient_id and b.blocked_id=r.sender_id)))));
$$;

create function public.wif_trip_booking_claim(p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
 if p_token is null then raise exception 'Claim token required.'; end if;
 perform wif_trip_schedule_booking();
 insert into trip_booking_deliveries(reminder_id,device_id)
 select r.id,d.id from trip_booking_reminders r join devices d on d.user_id=r.recipient_id
 where wif_trip_booking_allowed(r.id,d.id) on conflict do nothing;
 update trip_booking_deliveries d set status='failed',claim_token=null,claimed_at=null
 where status='pending' and (not wif_trip_booking_allowed(reminder_id,device_id)
 or (attempts>=5 and (claimed_at is null or claimed_at<now()-interval '2 minutes')));
 with candidates as (select id from trip_booking_deliveries where status='pending' and attempts<5 and available_at<=now()
 and (claimed_at is null or claimed_at<now()-interval '2 minutes') order by available_at,id limit 20 for update skip locked),
 claimed as (update trip_booking_deliveries d set attempts=attempts+1,claim_token=p_token,claimed_at=now()
 from candidates c where d.id=c.id returning d.id)
 select coalesce(jsonb_agg(jsonb_build_object('delivery_id',id)),'[]') into v_result from claimed;
 return v_result;
end; $$;

create function public.wif_trip_booking_prepare(p_id uuid,p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
 select jsonb_build_object('delivery_id',d.id,'device_id',dv.id,'event_id',r.id,
 'encrypted_apns_token',dv.encrypted_apns_token,'environment',dv.environment,'bundle_id',dv.bundle_id,
 'expires_at',extract(epoch from r.expires_at)::bigint,
 'deep_link',dv.url_scheme||'://trips/view/'||r.trip_id,
 'title',case when coalesce(c.locale,'en')='zh-Hans' then '机票安排小提醒' else 'A little flight reminder' end,
 'body',case when not coalesce(s.notification_preview_enabled,false) then
   case when c.locale='zh-Hans' then '有一条行程提醒，打开 Across Us 查看。' else 'Open Across Us to see your trip reminder.' end
 else case when c.locale='zh-Hans' then
   case when r.kind='manual' then u.display_name||' 提醒你：' else '准备好出发了吗？' end||'记得为「'||t.name||'」订票并添加去程航班。'
 else case when r.kind='manual' then u.display_name||' sent a nudge: ' else 'Ready for your trip? ' end||'Book and add your outbound flight for '||t.name||'.' end end)
 into v_result from trip_booking_deliveries d join trip_booking_reminders r on r.id=d.reminder_id
 join devices dv on dv.id=d.device_id join trips t on t.id=r.trip_id
 left join trip_reminder_context c on c.user_id=r.recipient_id left join app_users u on u.id=r.sender_id
 left join user_sharing_settings s on s.user_id=r.recipient_id
 where d.id=p_id and d.claim_token=p_token and d.status='pending' and d.claimed_at>now()-interval '2 minutes'
 and wif_trip_booking_allowed(r.id,d.device_id);
 return v_result;
end; $$;

create function public.wif_trip_booking_complete(p_id uuid,p_token uuid,p_outcome text,p_disable_device boolean default false)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_row public.trip_booking_deliveries; v_recipient uuid;
begin
 select * into v_row from trip_booking_deliveries where id=p_id and claim_token=p_token and status='pending' for update;
 if v_row.id is null then return false; end if;
 if p_outcome not in ('delivered','failed','retry') or p_outcome is null then raise exception 'Invalid delivery outcome.'; end if;
 select recipient_id into v_recipient from trip_booking_reminders where id=v_row.reminder_id;
 if p_disable_device then update devices set disabled_at=now() where id=v_row.device_id and user_id=v_recipient; end if;
 update trip_booking_deliveries set status=case when p_outcome='retry' and attempts<5 then 'pending'
 when p_outcome='delivered' then 'delivered' else 'failed' end,
 available_at=now()+interval '5 minutes',claim_token=null,claimed_at=null where id=p_id;
 return true;
end; $$;

do $$ declare f regprocedure; r text; begin
 foreach r in array array['anon','authenticated'] loop
  if exists(select 1 from pg_roles where rolname=r) then execute format('revoke all on public.trip_reminder_context,public.trip_booking_reminders,public.trip_booking_deliveries from %I',r); end if;
 end loop;
 for f in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and (proname like 'wif_trip_booking_%'
 or proname in ('wif_trip_reminder_context','wif_trip_needs_flight','wif_trip_planning_preferences','wif_trip_remind_member','wif_trip_schedule_booking')) loop
  execute format('revoke all on function %s from public',f);
  foreach r in array array['anon','authenticated'] loop
   if exists(select 1 from pg_roles where rolname=r) then execute format('revoke all on function %s from %I',f,r); end if;
  end loop;
  if exists(select 1 from pg_roles where rolname='service_role') then execute format('grant execute on function %s to service_role',f); end if;
 end loop;
end; $$;
commit;

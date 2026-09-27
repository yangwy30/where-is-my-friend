begin;
-- Preserve current paid-provider ceilings. Only a service-role operator can change them.
create table public.flight_lookup_policy (
 id boolean primary key default true check(id),
 daily_total integer not null default 50 check(daily_total between 0 and 100000),
 daily_background integer not null default 20 check(daily_background between 0 and daily_total),
 hourly_per_user integer not null default 10 check(hourly_per_user between 0 and 1000)
);
insert into public.flight_lookup_policy(id) values(true);
create table public.flight_lookup_requests (
 flight_number text not null, departure_date date not null, token uuid,
 lease_until timestamptz, retry_at timestamptz not null default now(),
 primary key(flight_number,departure_date)
);
alter table public.flight_lookup_policy enable row level security;
alter table public.flight_lookup_requests enable row level security;
revoke all on public.flight_lookup_policy,public.flight_lookup_requests from public;

create function public.wif_flight_reserve_budget(p_user uuid,p_background boolean)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_policy flight_lookup_policy; v_day timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
 v_hour timestamptz:=date_trunc('hour',now()); v_count integer;
begin
 if p_background is null or (not p_background and p_user is null) then raise exception 'Invalid budget reservation.'; end if;
 perform pg_advisory_xact_lock(9040901);
 select * into strict v_policy from flight_lookup_policy where id=true;
 select case when window_start=v_day then calls else 0 end into v_count from trip_flight_lookup_limits where bucket='global';
 if coalesce(v_count,0)>=v_policy.daily_total then return false; end if;
 if p_background then
  select case when window_start=v_day then calls else 0 end into v_count from trip_flight_lookup_limits where bucket='background';
  if coalesce(v_count,0)>=v_policy.daily_background then return false; end if;
 else
  select case when window_start=v_hour then calls else 0 end into v_count from trip_flight_lookup_limits where bucket=p_user::text;
  if coalesce(v_count,0)>=v_policy.hourly_per_user then return false; end if;
 end if;
 insert into trip_flight_lookup_limits(bucket,window_start,calls) values('global',v_day,1)
 on conflict(bucket) do update set calls=case when trip_flight_lookup_limits.window_start=excluded.window_start then trip_flight_lookup_limits.calls+1 else 1 end,window_start=excluded.window_start;
 insert into trip_flight_lookup_limits(bucket,window_start,calls)
 values(case when p_background then 'background' else p_user::text end,case when p_background then v_day else v_hour end,1)
 on conflict(bucket) do update set calls=case when trip_flight_lookup_limits.window_start=excluded.window_start then trip_flight_lookup_limits.calls+1 else 1 end,window_start=excluded.window_start;
 return true;
end; $$;

create function public.wif_flight_lookup_acquire(p_user_id uuid,p_trip_id text,p_number text,p_date date,p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb; v_request flight_lookup_requests;
begin
 perform wif_trip_self_participant(p_user_id,p_trip_id);
 if p_number is null or p_number !~ '^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$' or p_date is null or p_token is null then raise exception 'Invalid flight details.'; end if;
 perform pg_advisory_xact_lock(9040901);
 select result into v_result from trip_flight_lookup_cache where flight_number=p_number and departure_date=p_date and expires_at>now();
 if v_result is not null then return jsonb_build_object('cached',v_result); end if;
 insert into flight_lookup_requests(flight_number,departure_date) values(p_number,p_date) on conflict do nothing;
 select * into v_request from flight_lookup_requests where flight_number=p_number and departure_date=p_date for update;
 if v_request.lease_until>now() or v_request.retry_at>now() then return jsonb_build_object('pending',true); end if;
 if not wif_flight_reserve_budget(p_user_id,false) then raise exception 'Flight lookup limit reached.'; end if;
 update flight_lookup_requests set token=p_token,lease_until=now()+interval '45 seconds' where flight_number=p_number and departure_date=p_date;
 return jsonb_build_object('acquired',true);
end; $$;

create function public.wif_flight_lookup_finish(p_number text,p_date date,p_token uuid,p_result jsonb default null)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 perform 1 from flight_lookup_requests where flight_number=p_number and departure_date=p_date and token=p_token and lease_until>now() for update;
 if not found then return false; end if;
 if p_result is not null then perform wif_trip_flight_lookup_cache(p_number,p_date,p_result); end if;
 update flight_lookup_requests set token=null,lease_until=null,retry_at=now()+case when p_result is null then interval '30 seconds' else interval '0 seconds' end
 where flight_number=p_number and departure_date=p_date;
 return true;
end; $$;

-- Existing callers retain the original RPC and quota contract while deployment rolls out.
create or replace function public.wif_trip_flight_lookup_begin(p_user_id uuid,p_trip_id text,p_number text,p_date date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb; v_count integer;
begin
    perform public.wif_trip_self_participant(p_user_id,p_trip_id);
    if p_number is null or p_number !~ '^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$' or p_date is null then
        raise exception 'Invalid flight details.';
    end if;
    select result into v_result from trip_flight_lookup_cache where flight_number=p_number and departure_date=p_date and expires_at>now();
    if v_result is not null then return jsonb_build_object('cached',v_result); end if;
    if not wif_flight_reserve_budget(p_user_id,false) then raise exception 'Flight lookup limit reached.'; end if;
    return jsonb_build_object('cached',null);
end;
$$;

create or replace function public.wif_trip_flight_lookup_cache(p_number text,p_date date,p_result jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
begin
    if p_result->>'source' is distinct from 'aerodatabox' or p_result->>'flightNumber' is distinct from p_number
       or p_result->>'date' is distinct from to_char(p_date,'YYYY-MM-DD') then raise exception 'Invalid lookup result.'; end if;
    insert into trip_flight_lookup_cache(flight_number,departure_date,result,expires_at) values(p_number,p_date,p_result,now()+case when jsonb_array_length(coalesce(p_result->'flights','[]'::jsonb))=0 then interval '1 minute' when p_date>current_date+2 then interval '1 hour' else interval '5 minutes' end)
        on conflict(flight_number,departure_date) do update set result=excluded.result,expires_at=excluded.expires_at;
    return true;
end;
$$;
create or replace function public.wif_trip_claim_refresh(p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_cached jsonb; v_job public.trip_flight_refresh_jobs; v_calls integer; v_window timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
begin
    if p_token is null then raise exception 'Missing claim token.'; end if;
    -- Serialize budget reservations with other refresh workers; lookup quota uses the same global row.
    perform pg_advisory_xact_lock(9040901);
    insert into trip_flight_refresh_jobs(flight_number,departure_date)
      select distinct replace(upper(f.flight_number),' ',''),f.date::date from flights f
      where public.wif_trip_tracking_due(f) and f.date ~ '^\d{4}-\d{2}-\d{2}$'
      on conflict do nothing;
    select j.* into v_job from trip_flight_refresh_jobs j
      where j.available_at<=now() and (j.lease_until is null or j.lease_until<now())
      and not exists(select 1 from flight_lookup_requests r where r.flight_number=j.flight_number and r.departure_date=j.departure_date and (r.lease_until>now() or r.retry_at>now()))
      and exists(select 1 from flights f where replace(upper(f.flight_number),' ','')=j.flight_number
          and f.date=j.departure_date::text and public.wif_trip_tracking_due(f))
      order by j.available_at,j.flight_number,j.departure_date for update skip locked limit 1;
    if v_job.flight_number is null then return null; end if;
    select result into v_cached from trip_flight_lookup_cache where flight_number=v_job.flight_number and departure_date=v_job.departure_date
      and expires_at>now() and wif_trip_utc(result->>'fetchedAt')>=now()-interval '2 minutes';
    if v_cached is null and not wif_flight_reserve_budget(null,true) then
        update flights f set tracking_state='quota_limited' where public.wif_trip_tracking_due(f) and tracking_state is distinct from 'quota_limited';
        return null;
    end if;
    insert into flight_lookup_requests(flight_number,departure_date,token,lease_until) values(v_job.flight_number,v_job.departure_date,p_token,now()+interval '45 seconds')
      on conflict(flight_number,departure_date) do update set token=excluded.token,lease_until=excluded.lease_until;
    update trip_flight_refresh_jobs set claim_token=p_token,lease_until=now()+interval '45 seconds',attempts=attempts+1
      where flight_number=v_job.flight_number and departure_date=v_job.departure_date;
    return jsonb_build_object('flightNumber',v_job.flight_number,'date',v_job.departure_date,'cached',v_cached);
end;
$$;

create or replace function public.wif_trip_finish_refresh(p_token uuid,p_number text,p_date date,p_result jsonb default null)
returns integer language plpgsql security definer set search_path=public as $$
declare v_f public.flights; v_candidate jsonb; v_status text; v_kind text; v_event uuid; v_count integer:=0; v_at timestamptz;
begin
    perform 1 from trip_flight_refresh_jobs where flight_number=p_number and departure_date=p_date
      and claim_token=p_token and lease_until>now() for update;
    if not found then return 0; end if;
    v_at:=public.wif_trip_utc(p_result->>'fetchedAt');
    if p_result is not null and (p_result->>'source' is distinct from 'aerodatabox'
      or p_result->>'flightNumber' is distinct from p_number or p_result->>'date' is distinct from p_date::text
      or jsonb_typeof(p_result->'flights') is distinct from 'array' or v_at is null
      or v_at>now()+interval '1 minute' or v_at<now()-interval '2 minutes') then raise exception 'Invalid provider result.'; end if;
    for v_f in select f.* from flights f where replace(upper(f.flight_number),' ','')=p_number and f.date=p_date::text
        and public.wif_trip_tracking_due(f) order by f.id for update loop
        v_kind:=null; v_candidate:=null;
        if p_result is null then
            update flights set tracking_state='unavailable',tracking_attempt_at=now() where id=v_f.id; continue;
        end if;
        select value into v_candidate from jsonb_array_elements(p_result->'flights') where value->>'id'=v_f.candidate_id;
        -- Never substitute another leg/direction/date when the selected route disappears.
        if v_candidate is null then
            update flights set tracking_state='not_found',tracking_attempt_at=now() where id=v_f.id; continue;
        end if;
        if v_at<=v_f.verified_at then continue; end if;
        v_status:=coalesce(v_candidate->>'status','unknown');
        if v_status not in ('landed','cancelled','delayed','airborne','scheduled','boarding','diverted','unknown') then v_status:='unknown'; end if;
        if v_status in ('landed','cancelled') and v_status<>v_f.status then v_kind:=v_status;
        elsif v_status not in ('unknown','diverted','landed','cancelled') and
          coalesce(public.wif_trip_utc(v_candidate#>>'{arrival,revisedTime,utc}'),public.wif_trip_utc(v_candidate#>>'{arrival,predictedTime,utc}'))
            >=public.wif_trip_utc(v_candidate#>>'{arrival,scheduledTime,utc}')+interval '30 minutes' then
            if not coalesce(coalesce(public.wif_trip_utc(v_f.arrival#>>'{revisedTime,utc}'),public.wif_trip_utc(v_f.arrival#>>'{predictedTime,utc}'))
              >=public.wif_trip_utc(v_f.arrival#>>'{scheduledTime,utc}')+interval '30 minutes',false) then v_kind:='delayed'; end if;
            v_status:='delayed';
        end if;
        update flights set departure=v_candidate->'departure',arrival=v_candidate->'arrival',status=v_status,
          gate=coalesce(v_candidate#>>'{arrival,gate}',''),verified_at=v_at,tracking_attempt_at=now(),tracking_state='updated' where id=v_f.id;
        v_count:=v_count+1;
        -- The first lookup is a baseline. Emit once per selected flight/route/event kind, even after retries.
        if v_kind is not null then
            v_event:=null;
            insert into trip_flight_events(flight_id,candidate_id,kind) values(v_f.id,v_f.candidate_id,v_kind)
              on conflict do nothing returning id into v_event;
            if v_event is not null then
                insert into trip_flight_deliveries(event_id,device_id,recipient_id)
                  select v_event,d.id,m.user_id from trip_members m
                  join app_users u on u.id=m.user_id and u.deleted_at is null
                  join participants p on p.id=v_f.participant_id
                  join devices d on d.user_id=m.user_id and d.disabled_at is null and d.last_seen_at>now()-interval '90 days'
                  where m.trip_id=v_f.trip_id and m.flight_alerts_enabled and m.user_id<>p.user_id
                  and not exists(select 1 from user_blocks b where (b.blocker_id=m.user_id and b.blocked_id=p.user_id)
                    or (b.blocker_id=p.user_id and b.blocked_id=m.user_id)) on conflict do nothing;
            end if;
        end if;
    end loop;
    update trip_flight_refresh_jobs set claim_token=null,lease_until=null,available_at=now()+interval '30 minutes'
      where flight_number=p_number and departure_date=p_date;
    perform wif_flight_lookup_finish(p_number,p_date,p_token,p_result);
    return v_count;
end;
$$;

create or replace function public.wif_trip_schedule_booking(p_at timestamptz default now())
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
 order by m.trip_id,m.user_id limit 500 on conflict do nothing;
 get diagnostics v_count=row_count; return v_count;
end; $$;

create or replace function public.wif_trip_booking_claim(p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
 if p_token is null then raise exception 'Claim token required.'; end if;
 perform wif_trip_schedule_booking();
 insert into trip_booking_deliveries(reminder_id,device_id)
 select r.id,d.id from trip_booking_reminders r join devices d on d.user_id=r.recipient_id
 where r.expires_at>now() and d.disabled_at is null and wif_trip_booking_allowed(r.id,d.id) on conflict do nothing;
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

create index trip_booking_expiry on public.trip_booking_reminders(expires_at);

-- One scheduled lane and one interactive lane across all Edge instances.
create table public.push_worker_slots (
 lane text primary key check(lane in ('scheduled','interactive')), token uuid, lease_until timestamptz
);
insert into public.push_worker_slots(lane) values('scheduled'),('interactive');
alter table public.push_worker_slots enable row level security;
revoke all on public.push_worker_slots from public;
create function public.wif_push_worker_acquire(p_token uuid,p_lane text)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if p_token is null or p_lane is null or p_lane not in ('scheduled','interactive') then raise exception 'Invalid worker lease.'; end if;
 update push_worker_slots set token=p_token,lease_until=now()+interval '60 seconds'
 where lane=p_lane and (lease_until is null or lease_until<=now());
 return found;
end; $$;
create function public.wif_push_worker_release(p_token uuid,p_lane text)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 update push_worker_slots set token=null,lease_until=null where lane=p_lane and token=p_token;
 return found;
end; $$;
revoke all on function public.wif_push_worker_acquire(uuid,text),public.wif_push_worker_release(uuid,text) from public;

-- Aggregate operational health only; no names, tokens, cities or personal plans.
create function public.wif_capacity_health()
returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object(
 'flightPolicy',(select to_jsonb(p)-'id' from flight_lookup_policy p where id=true),
 'flightUsage',(select coalesce(jsonb_agg(jsonb_build_object('bucket',bucket,'calls',calls,'window',window_start)),'[]') from trip_flight_lookup_limits where bucket in ('global','background')),
 'queues',(select jsonb_agg(to_jsonb(q)) from (
  select 'colocation' as kind,count(*) as pending,min(available_at) as oldest_available_at from notification_deliveries where status='pending'
  union all select 'booking',count(*),min(available_at) from trip_booking_deliveries where status='pending'
  union all select 'flights',count(*),min(available_at) from trip_flight_deliveries where status='pending'
 ) q));
$$;
revoke all on function public.wif_flight_reserve_budget(uuid,boolean),public.wif_flight_lookup_acquire(uuid,text,text,date,uuid),public.wif_flight_lookup_finish(text,date,uuid,jsonb),public.wif_capacity_health() from public;
do $$ declare r text; begin
 foreach r in array array['anon','authenticated'] loop
  if exists(select 1 from pg_roles where rolname=r) then
   execute format('revoke all on public.flight_lookup_policy,public.flight_lookup_requests,public.push_worker_slots from %I',r);
   execute format('revoke all on function public.wif_push_worker_acquire(uuid,text),public.wif_push_worker_release(uuid,text) from %I',r);
   execute format('revoke all on function public.wif_flight_reserve_budget(uuid,boolean),public.wif_flight_lookup_acquire(uuid,text,text,date,uuid),public.wif_flight_lookup_finish(text,date,uuid,jsonb),public.wif_capacity_health() from %I',r);
  end if;
 end loop;
 if exists(select 1 from pg_roles where rolname='service_role') then
  grant select,update on public.flight_lookup_policy to service_role;
  grant execute on function public.wif_push_worker_acquire(uuid,text),public.wif_push_worker_release(uuid,text) to service_role;
  grant execute on function public.wif_flight_reserve_budget(uuid,boolean),public.wif_flight_lookup_acquire(uuid,text,text,date,uuid),public.wif_flight_lookup_finish(text,date,uuid,jsonb),public.wif_capacity_health() to service_role;
 end if;
end $$;
commit;

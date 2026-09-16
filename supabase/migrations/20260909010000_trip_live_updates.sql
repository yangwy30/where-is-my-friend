begin;

alter table public.trip_members add column flight_alerts_enabled boolean not null default false;
alter table public.trips add column meeting_point text not null default '' check (char_length(meeting_point)<=300);
alter table public.participants add column check_in text not null default 'not_set' check (check_in in ('not_set','landed','bags_collected','at_meeting_point'));
alter table public.participants add column check_in_at timestamptz;
alter table public.flights add column tracking_state text not null default 'pending';
alter table public.flights add column tracking_attempt_at timestamptz;

-- Provider refreshes must not invalidate a form editing the member's own flight.
create or replace function public.wif_trip_bump_revision() returns trigger
language plpgsql set search_path=public as $$
begin
    if tg_table_name='flights' then
        if row(new.trip_id,new.participant_id,new.flight_number,new.date,new.direction,new.candidate_id)
            is not distinct from row(old.trip_id,old.participant_id,old.flight_number,old.date,old.direction,old.candidate_id) then
            new.revision:=old.revision; return new;
        end if;
        new.tracking_state:='pending'; new.tracking_attempt_at:=null;
    end if;
    new.revision:=old.revision+1; return new;
end;
$$;

create or replace function public.wif_trip_snapshot(p_user_id uuid,p_trip_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id);
    select (to_jsonb(t)-'source_project_ref'-'legacy_imported_at') || jsonb_build_object(
        'participants',(select coalesce(jsonb_agg(to_jsonb(p) order by p.joined_at,p.id),'[]') from participants p where p.trip_id=t.id),
        'flights',(select coalesce(jsonb_agg(to_jsonb(f) order by f.added_at,f.id),'[]') from flights f where f.trip_id=t.id),
        'notes',(select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at,n.id),'[]') from notes n where n.trip_id=t.id),
        'my_role',m.role,'flight_alerts_enabled',m.flight_alerts_enabled
    ) into v_result from trips t join trip_members m on m.trip_id=t.id and m.user_id=p_user_id where t.id=p_trip_id;
    return v_result;
end;
$$;

create function public.wif_trip_preferences(p_user_id uuid,p_trip_id text,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id);
    if p_enabled is null then raise exception 'Invalid preference.'; end if;
    update trip_members set flight_alerts_enabled=p_enabled where trip_id=p_trip_id and user_id=p_user_id;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_meeting(p_user_id uuid,p_trip_id text,p_point text,p_revision bigint)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_revision bigint;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
    select revision into v_revision from trips where id=p_trip_id for update;
    if p_revision is distinct from v_revision then raise exception 'Trip conflict. Refresh before saving again.'; end if;
    if p_point is null or char_length(p_point)>300 then raise exception 'Invalid meeting point.'; end if;
    update trips set meeting_point=trim(p_point) where id=p_trip_id;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_check_in(p_user_id uuid,p_trip_id text,p_state text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_person uuid;
begin
    v_person:=public.wif_trip_self_participant(p_user_id,p_trip_id);
    if p_state is null or p_state not in ('not_set','landed','bags_collected','at_meeting_point') then raise exception 'Invalid check-in.'; end if;
    update participants set check_in=p_state,check_in_at=case when p_state='not_set' then null else now() end where id=v_person;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

-- Private server-only work queue, shared by flight number/date across all trips.
create table public.trip_flight_refresh_jobs (
    flight_number text not null, departure_date date not null,
    available_at timestamptz not null default now(), lease_until timestamptz,
    claim_token uuid, attempts integer not null default 0,
    primary key(flight_number,departure_date)
);
create table public.trip_flight_events (
    id uuid primary key default gen_random_uuid(), flight_id text not null references public.flights(id) on delete cascade,
    candidate_id text not null, kind text not null check(kind in ('delayed','cancelled','landed')),
    created_at timestamptz not null default now(),
    unique(flight_id,candidate_id,kind)
);
create table public.trip_flight_deliveries (
    id uuid primary key default gen_random_uuid(), event_id uuid not null references public.trip_flight_events(id) on delete cascade,
    device_id uuid not null references public.devices(id) on delete cascade,
    recipient_id uuid not null references public.app_users(id) on delete cascade,
    status text not null default 'pending' check(status in ('pending','delivered','failed')),
    attempts integer not null default 0, available_at timestamptz not null default now(),
    claim_token uuid, claimed_at timestamptz, last_error text,
    unique(event_id,device_id)
);
alter table public.trip_flight_refresh_jobs enable row level security;
alter table public.trip_flight_events enable row level security;
alter table public.trip_flight_deliveries enable row level security;

-- Provider timestamps are UTC strings (some omit Z). Malformed/absent times never become "now".
create function public.wif_trip_utc(p_value text) returns timestamptz
language plpgsql immutable set search_path=public as $$
begin
    if p_value is null or p_value !~ '^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}' then return null; end if;
    return (case when p_value ~ '(Z|[+-]\d{2}:\d{2})$' then p_value else p_value||'Z' end)::timestamptz;
exception when others then return null;
end;
$$;

create function public.wif_trip_tracking_due(p_flight public.flights) returns boolean
language sql stable set search_path=public as $$
    select p_flight.candidate_id is not null and p_flight.verified_at is not null
      and p_flight.status not in ('unverified','landed','cancelled')
      and public.wif_trip_utc(p_flight.departure#>>'{scheduledTime,utc}') <= now()+interval '24 hours'
      and greatest(public.wif_trip_utc(p_flight.arrival#>>'{revisedTime,utc}'),
                   public.wif_trip_utc(p_flight.arrival#>>'{scheduledTime,utc}')) >= now()-interval '6 hours'
      and public.wif_trip_utc(p_flight.departure#>>'{scheduledTime,utc}') >= now()-interval '48 hours'
      and exists(select 1 from trips t where t.id=p_flight.trip_id and t.completed_at is null)
      and exists(select 1 from participants p join app_users u on u.id=p.user_id and u.deleted_at is null
        join trip_members m on m.trip_id=p.trip_id and m.user_id=p.user_id where p.id=p_flight.participant_id);
$$;

create function public.wif_trip_claim_refresh(p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_job public.trip_flight_refresh_jobs; v_calls integer; v_window timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
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
      and exists(select 1 from flights f where replace(upper(f.flight_number),' ','')=j.flight_number
          and f.date=j.departure_date::text and public.wif_trip_tracking_due(f))
      order by j.available_at,j.flight_number,j.departure_date for update skip locked limit 1;
    if v_job.flight_number is null then return null; end if;
    -- Hard cap: 20 background calls/day, within the existing combined 50/day ceiling.
    insert into trip_flight_lookup_limits(bucket,window_start,calls) values('background',v_window,0),('global',v_window,0) on conflict do nothing;
    perform 1 from trip_flight_lookup_limits where bucket in ('background','global') order by bucket for update;
    if exists(select 1 from trip_flight_lookup_limits where window_start=v_window
       and ((bucket='background' and calls>=20) or (bucket='global' and calls>=50))) then
        update flights f set tracking_state='quota_limited' where public.wif_trip_tracking_due(f);
        return null;
    end if;
    update trip_flight_lookup_limits set calls=case when window_start=v_window then calls+1 else 1 end,
      window_start=v_window where bucket in ('background','global');
    update trip_flight_refresh_jobs set claim_token=p_token,lease_until=now()+interval '2 minutes',attempts=attempts+1
      where flight_number=v_job.flight_number and departure_date=v_job.departure_date;
    return jsonb_build_object('flightNumber',v_job.flight_number,'date',v_job.departure_date);
end;
$$;

create function public.wif_trip_finish_refresh(p_token uuid,p_number text,p_date date,p_result jsonb default null)
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
    return v_count;
end;
$$;

-- Evaluate access both at enqueue and immediately before delivery; stale events expire after 2 hours.
create function public.wif_trip_delivery_allowed(p_delivery public.trip_flight_deliveries) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from trip_flight_events e join flights f on f.id=e.flight_id and f.candidate_id=e.candidate_id
 join trips t on t.id=f.trip_id and t.completed_at is null
 join participants p on p.id=f.participant_id join app_users owner on owner.id=p.user_id and owner.deleted_at is null
 join trip_members om on om.trip_id=t.id and om.user_id=owner.id
 join trip_members m on m.trip_id=t.id and m.user_id=p_delivery.recipient_id and m.flight_alerts_enabled
 join app_users u on u.id=m.user_id and u.deleted_at is null
 join devices d on d.id=p_delivery.device_id and d.user_id=m.user_id and d.disabled_at is null
 where e.id=p_delivery.event_id and e.created_at>now()-interval '2 hours' and f.status=e.kind
 and not exists(select 1 from user_blocks b where (b.blocker_id=u.id and b.blocked_id=owner.id) or (b.blocker_id=owner.id and b.blocked_id=u.id)));
$$;

create function public.wif_trip_claim_deliveries(p_claim_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
    if p_claim_token is null then raise exception 'Missing claim token.'; end if;
    update trip_flight_deliveries d set status='failed',last_error='Expired or access removed.',claim_token=null,claimed_at=null
      where d.status='pending' and (d.attempts>=5 or not public.wif_trip_delivery_allowed(d));
    with candidates as (
      select d.id from trip_flight_deliveries d where d.status='pending' and d.available_at<=now()
        and (d.claimed_at is null or d.claimed_at<now()-interval '2 minutes') order by d.available_at,d.id for update skip locked limit 10
    ), claimed as (
      update trip_flight_deliveries d set claim_token=p_claim_token,claimed_at=now(),attempts=attempts+1
      from candidates c where d.id=c.id returning d.*
    ) select coalesce(jsonb_agg(jsonb_build_object('delivery_id',c.id)), '[]') into v_result from claimed c;
    return v_result;
end;
$$;

create function public.wif_trip_prepare_delivery(p_id uuid,p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_d public.trip_flight_deliveries; v_result jsonb;
begin
    select * into v_d from trip_flight_deliveries where id=p_id and claim_token=p_token and status='pending' and claimed_at>now()-interval '2 minutes';
    if v_d.id is null or not public.wif_trip_delivery_allowed(v_d) then return null; end if;
    select jsonb_build_object('delivery_id',v_d.id,'device_id',d.id,'encrypted_apns_token',d.encrypted_apns_token,
      'environment',d.environment,'bundle_id',d.bundle_id,'event_id',e.id,
      'title',case when coalesce(s.notification_preview_enabled,false) then 'Flight update' else 'Trip update' end,
      'body',case when coalesce(s.notification_preview_enabled,false) then p.name||' · '||f.flight_number||
        case e.kind when 'landed' then ' has landed.' when 'cancelled' then ' has been cancelled.' else ' is arriving at least 30 minutes late.' end
        else 'Open Across Us to see your trip update.' end,
      'deep_link',d.url_scheme||'://trips/view/'||f.trip_id)
      into v_result from trip_flight_events e join flights f on f.id=e.flight_id join participants p on p.id=f.participant_id
      join devices d on d.id=v_d.device_id left join user_sharing_settings s on s.user_id=v_d.recipient_id where e.id=v_d.event_id;
    return v_result;
end;
$$;

create function public.wif_trip_complete_delivery(p_id uuid,p_token uuid,p_outcome text,p_disable_device boolean default false)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_device uuid;
begin
    if p_outcome is null or p_outcome not in ('delivered','retry','failed') then raise exception 'Invalid outcome.'; end if;
    update trip_flight_deliveries set status=case when p_outcome='retry' then 'pending' else p_outcome end,
      claim_token=null,claimed_at=null,available_at=now()+interval '5 minutes'
      where id=p_id and claim_token=p_token and status='pending' returning device_id into v_device;
    if v_device is null then return false; end if;
    if p_disable_device then update devices set disabled_at=now(),disabled_reason='apns_permanent_error' where id=v_device; end if;
    return true;
end;
$$;

do $$ declare v_fn regprocedure; v_role text; v_table text;
begin
    foreach v_table in array array['trip_flight_refresh_jobs','trip_flight_events','trip_flight_deliveries'] loop
      execute format('revoke all on public.%I from public',v_table);
      foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then execute format('revoke all on public.%I from %I',v_table,v_role); end if;
      end loop;
    end loop;
    for v_fn in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname like 'wif_trip_%' loop
      execute format('revoke all on function %s from public',v_fn);
      foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then execute format('revoke all on function %s from %I',v_fn,v_role); end if;
      end loop;
      if exists(select 1 from pg_roles where rolname='service_role') then execute format('grant execute on function %s to service_role',v_fn); end if;
    end loop;
end; $$;
commit;

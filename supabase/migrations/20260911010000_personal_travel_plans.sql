begin;

create table public.travel_plans (
    id uuid primary key,
    owner_id uuid not null references public.app_users(id) on delete cascade,
    city text not null check (length(trim(city)) between 1 and 120),
    country_code text not null check (country_code ~ '^[A-Z]{2}$'),
    region text not null check (length(region) <= 120),
    time_zone text not null,
    city_key text not null,
    start_day date not null,
    end_day date not null,
    alerts_enabled boolean not null default false,
    revision integer not null default 1,
    updated_at timestamptz not null default now(),
    check (end_day >= start_day and end_day - start_day <= 366)
);
create index travel_plans_matching on public.travel_plans(city_key,start_day,end_day);
create index travel_plans_owner on public.travel_plans(owner_id);

create table public.travel_plan_audience (
    plan_id uuid not null references public.travel_plans(id) on delete cascade,
    friend_id uuid not null references public.app_users(id) on delete cascade,
    friendship_id uuid not null references public.friendships(id) on delete cascade,
    primary key(plan_id,friend_id)
);

-- A reciprocal grant belongs to the accepted friendship, not just two UUIDs.
-- Removing/re-adding a friendship cannot revive an old audience grant.
create view public.travel_overlaps as
with matches as (
    select a.owner_id recipient_id,b.owner_id friend_id,a.city_key,a.city,a.country_code,a.region,a.time_zone,
           greatest(a.start_day,b.start_day) start_day,least(a.end_day,b.end_day) end_day,
           a.alerts_enabled
    from travel_plans a join travel_plans b on a.city_key=b.city_key and a.owner_id<>b.owner_id
        and a.start_day<=b.end_day and b.start_day<=a.end_day
    join travel_plan_audience aa on aa.plan_id=a.id and aa.friend_id=b.owner_id
    join travel_plan_audience ba on ba.plan_id=b.id and ba.friend_id=a.owner_id and ba.friendship_id=aa.friendship_id
    join friendships f on f.id=aa.friendship_id and f.status='accepted'
        and f.pair_low_id=least(a.owner_id,b.owner_id) and f.pair_high_id=greatest(a.owner_id,b.owner_id)
    join app_users u on u.id=a.owner_id and u.deleted_at is null
    join app_users v on v.id=b.owner_id and v.deleted_at is null
    where least(a.end_day,b.end_day)>=(now() at time zone a.time_zone)::date
      and not exists(select 1 from user_blocks x where
          (x.blocker_id=a.owner_id and x.blocked_id=b.owner_id) or (x.blocker_id=b.owner_id and x.blocked_id=a.owner_id))
)
select md5(recipient_id::text||':'||friend_id::text||':'||city_key||':'||start_day::text||':'||end_day::text) id,
       recipient_id,friend_id,city_key,min(city) city,min(country_code) country_code,min(region) region,
       min(time_zone) time_zone,start_day,end_day,bool_or(alerts_enabled) alerts_enabled
from matches group by recipient_id,friend_id,city_key,start_day,end_day;

create function public.wif_travel_snapshot(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Account unavailable.'; end if;
    return jsonb_build_object(
      'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'city',p.city,'countryCode',p.country_code,
        'region',p.region,'timeZone',p.time_zone,'startDay',p.start_day,'endDay',p.end_day,
        'alertsEnabled',p.alerts_enabled,'revision',p.revision,
        'audience',coalesce((select jsonb_agg(a.friend_id order by a.friend_id) from travel_plan_audience a
          join friendships f on f.id=a.friendship_id and f.status='accepted'
          where a.plan_id=p.id and not exists(select 1 from user_blocks x where
            (x.blocker_id=p.owner_id and x.blocked_id=a.friend_id) or (x.blocker_id=a.friend_id and x.blocked_id=p.owner_id))),'[]'))
        order by p.start_day,p.id) from travel_plans p where p.owner_id=p_user_id),'[]'),
      'overlaps',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'friendID',o.friend_id,'friendName',u.display_name,
        'city',o.city,'countryCode',o.country_code,'region',o.region,'timeZone',o.time_zone,
        'startDay',o.start_day,'endDay',o.end_day) order by o.start_day,o.id)
        from travel_overlaps o join app_users u on u.id=o.friend_id where o.recipient_id=p_user_id),'[]'));
end; $$;

create function public.wif_travel_save(p_user_id uuid,p_id uuid,p_city text,p_country text,p_region text,
    p_time_zone text,p_start date,p_end date,p_audience uuid[],p_alerts boolean,p_revision integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_plan travel_plans; v_friend uuid; v_friendship uuid;
begin
    if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Account unavailable.'; end if;
    perform pg_advisory_xact_lock(hashtext('travel:'||p_user_id::text));
    -- Serialize the resource ID as well: two owners racing to create the same
    -- UUID must not reach ON CONFLICT before the ownership check can see it.
    perform pg_advisory_xact_lock(hashtext('travel-plan:'||p_id::text));
    if p_id is null or p_revision is null or p_revision<0 or p_city is null or length(trim(p_city)) not between 1 and 120
      or p_region is null or length(p_region)>120 or p_country is null or p_country!~'^[A-Z]{2}$'
      or p_time_zone is null or not exists(select 1 from pg_timezone_names where name=p_time_zone)
      or p_start is null or p_end is null or p_end<p_start or p_end-p_start>366
      or p_start>(now() at time zone p_time_zone)::date+730 or p_end<(now() at time zone p_time_zone)::date
      or p_audience is null or cardinality(p_audience)>100 or p_alerts is null
      then raise exception 'Invalid travel plan.'; end if;
    select * into v_plan from travel_plans where id=p_id for update;
    if found then
      if v_plan.owner_id<>p_user_id then raise exception 'Travel access denied.'; end if;
      if v_plan.revision<>p_revision then raise exception 'Travel plan conflict. Refresh and try again.'; end if;
    else
      if p_revision<>0 then raise exception 'Travel plan no longer available.'; end if;
      if (select count(*) from travel_plans where owner_id=p_user_id)>=100 then raise exception 'Travel plan limit reached.'; end if;
    end if;
    foreach v_friend in array p_audience loop
      if v_friend is null or v_friend=p_user_id or not exists(select 1 from friendships f
        where f.status='accepted' and f.pair_low_id=least(p_user_id,v_friend) and f.pair_high_id=greatest(p_user_id,v_friend))
        or exists(select 1 from user_blocks x where (x.blocker_id=p_user_id and x.blocked_id=v_friend)
           or (x.blocker_id=v_friend and x.blocked_id=p_user_id)) then raise exception 'Audience must contain current friends only.'; end if;
    end loop;
    insert into travel_plans(id,owner_id,city,country_code,region,time_zone,city_key,start_day,end_day,alerts_enabled)
      values(p_id,p_user_id,trim(p_city),p_country,trim(p_region),p_time_zone,
        wif_city_key(p_city,p_country)||':'||lower(trim(p_region))||':'||p_time_zone,p_start,p_end,p_alerts)
      on conflict(id) do update set city=excluded.city,country_code=excluded.country_code,region=excluded.region,
        time_zone=excluded.time_zone,city_key=excluded.city_key,start_day=excluded.start_day,end_day=excluded.end_day,
        alerts_enabled=excluded.alerts_enabled,revision=travel_plans.revision+1,updated_at=now();
    delete from travel_plan_audience where plan_id=p_id;
    insert into travel_plan_audience(plan_id,friend_id,friendship_id)
      select distinct p_id,a.id,f.id from unnest(p_audience) a(id) join friendships f
        on f.pair_low_id=least(p_user_id,a.id) and f.pair_high_id=greatest(p_user_id,a.id) and f.status='accepted';
    return wif_travel_snapshot(p_user_id);
end; $$;

create function public.wif_travel_delete(p_user_id uuid,p_id uuid,p_revision integer)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    delete from travel_plans where id=p_id and owner_id=p_user_id and revision=p_revision;
    if not found then raise exception 'Travel plan conflict or access denied. Refresh and try again.'; end if;
    return wif_travel_snapshot(p_user_id);
end; $$;

create table public.upcoming_deliveries (
    id uuid primary key default gen_random_uuid(),
    overlap_id text not null,
    recipient_id uuid not null references app_users(id) on delete cascade,
    device_id uuid not null references devices(id) on delete cascade,
    status text not null default 'pending' check(status in ('pending','delivered','failed')),
    attempts integer not null default 0,
    available_at timestamptz not null default now(),
    claimed_at timestamptz,
    claim_token uuid,
    unique(overlap_id,device_id,recipient_id)
);

create function public.wif_travel_delivery_allowed(p_delivery upcoming_deliveries)
returns boolean language sql stable security definer set search_path=public as $$
    select exists(select 1 from travel_overlaps o join devices d on d.id=p_delivery.device_id
      and d.user_id=o.recipient_id and d.disabled_at is null
      join sharing_preferences s on s.owner_id=o.recipient_id and s.friend_id=o.friend_id and s.same_city_alert
      where o.id=p_delivery.overlap_id and o.recipient_id=p_delivery.recipient_id and o.alerts_enabled
        and o.start_day between (now() at time zone o.time_zone)::date and (now() at time zone o.time_zone)::date+14)
$$;

create function public.wif_travel_claim(p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
    if p_token is null then raise exception 'Missing claim token.'; end if;
    insert into upcoming_deliveries(overlap_id,recipient_id,device_id)
      select o.id,o.recipient_id,d.id from travel_overlaps o join devices d on d.user_id=o.recipient_id and d.disabled_at is null
      join sharing_preferences s on s.owner_id=o.recipient_id and s.friend_id=o.friend_id and s.same_city_alert
      where o.alerts_enabled and o.start_day between (now() at time zone o.time_zone)::date and (now() at time zone o.time_zone)::date+14
      on conflict do nothing;
    update upcoming_deliveries d set status='failed',claim_token=null,claimed_at=null
      where d.status='pending' and (d.attempts>=5 or not wif_travel_delivery_allowed(d));
    with next as (select id from upcoming_deliveries where status='pending' and available_at<=now()
      and (claimed_at is null or claimed_at<now()-interval '2 minutes') order by available_at,id for update skip locked limit 10),
    claimed as (update upcoming_deliveries d set claim_token=p_token,claimed_at=now(),attempts=attempts+1
      from next where d.id=next.id returning d.id)
    select coalesce(jsonb_agg(jsonb_build_object('delivery_id',id)),'[]') into v_result from claimed;
    return v_result;
end; $$;

create function public.wif_travel_prepare(p_id uuid,p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_d upcoming_deliveries;
begin
    select * into v_d from upcoming_deliveries where id=p_id and claim_token=p_token and status='pending'
      and claimed_at>now()-interval '2 minutes';
    if v_d.id is null or not wif_travel_delivery_allowed(v_d) then return null; end if;
    return (select jsonb_build_object('delivery_id',v_d.id,'device_id',d.id,'encrypted_apns_token',d.encrypted_apns_token,
      'environment',d.environment,'bundle_id',d.bundle_id,'event_id',o.id,
      'title',case when s.notification_preview_enabled then 'Together soon in '||o.city else 'An upcoming overlap' end,
      'body',case when s.notification_preview_enabled then 'You and '||u.display_name||' · '||to_char(o.start_day,'Mon DD')||'–'||to_char(o.end_day,'Mon DD')
        else 'Open Across Us to see the shared dates.' end,
      'deep_link',d.url_scheme||'://upcoming/'||o.id)
      from travel_overlaps o join app_users u on u.id=o.friend_id join devices d on d.id=v_d.device_id
      join user_sharing_settings s on s.user_id=o.recipient_id where o.id=v_d.overlap_id and o.recipient_id=v_d.recipient_id);
end; $$;

create function public.wif_travel_complete(p_id uuid,p_token uuid,p_outcome text,p_disable_device boolean default false)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_device uuid;
begin
    if p_outcome is null or p_outcome not in ('delivered','retry','failed') then raise exception 'Invalid outcome.'; end if;
    update upcoming_deliveries set status=case when p_outcome='retry' then 'pending' else p_outcome end,
      claim_token=null,claimed_at=null,available_at=now()+interval '5 minutes'
      where id=p_id and claim_token=p_token and status='pending' returning device_id into v_device;
    if v_device is null then return false; end if;
    if p_disable_device then update devices set disabled_at=now(),disabled_reason='apns_permanent_error' where id=v_device; end if;
    return true;
end; $$;

alter table travel_plans enable row level security;
alter table travel_plan_audience enable row level security;
alter table upcoming_deliveries enable row level security;
do $$ declare v_fn regprocedure; v_role text; v_table text;
begin
    foreach v_table in array array['travel_plans','travel_plan_audience','travel_overlaps','upcoming_deliveries'] loop
      execute format('revoke all on public.%I from public',v_table);
      foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then execute format('revoke all on public.%I from %I',v_table,v_role); end if;
      end loop;
    end loop;
    for v_fn in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname like 'wif_travel_%' loop
      execute format('revoke all on function %s from public',v_fn);
      foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then execute format('revoke all on function %s from %I',v_fn,v_role); end if;
      end loop;
      if exists(select 1 from pg_roles where rolname='service_role') then execute format('grant execute on function %s to service_role',v_fn); end if;
    end loop;
end; $$;
commit;

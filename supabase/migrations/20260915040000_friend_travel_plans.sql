begin;

-- Existing audiences permit overlap matching, not browsing the complete plan.
-- No backfill and no new notification trigger.
alter table public.travel_plans add column allow_friend_browsing boolean not null default false;
create index travel_plan_audience_reader on public.travel_plan_audience(friend_id,plan_id);

create function public.wif_friend_travel_plans(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
    if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then
        raise exception 'Account unavailable.';
    end if;
    return coalesce((select jsonb_agg(jsonb_build_object(
        'id',p.id,'friendID',p.owner_id,'friendName',u.display_name,
        'city',p.city,'countryCode',p.country_code,'region',p.region,'timeZone',p.time_zone,
        'startDay',p.start_day,'endDay',p.end_day) order by p.start_day,p.id)
      from travel_plans p
      join travel_plan_audience a on a.plan_id=p.id and a.friend_id=p_user_id
      join friendships f on f.id=a.friendship_id and f.status='accepted'
        and f.pair_low_id=least(p.owner_id,p_user_id) and f.pair_high_id=greatest(p.owner_id,p_user_id)
      join app_users u on u.id=p.owner_id and u.deleted_at is null
      where p.owner_id<>p_user_id and p.allow_friend_browsing
        and p.end_day >= (now() at time zone p.time_zone)::date
        and not exists(select 1 from user_blocks b where
          (b.blocker_id=p_user_id and b.blocked_id=p.owner_id)
          or (b.blocker_id=p.owner_id and b.blocked_id=p_user_id))), '[]'::jsonb);
end; $$;

create or replace function public.wif_travel_snapshot(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Account unavailable.'; end if;
    return jsonb_build_object(
      'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'city',p.city,'countryCode',p.country_code,
        'region',p.region,'timeZone',p.time_zone,'startDay',p.start_day,'endDay',p.end_day,
        'alertsEnabled',p.alerts_enabled,'revision',p.revision,'allowFriendBrowsing',p.allow_friend_browsing,
        'audience',coalesce((select jsonb_agg(a.friend_id order by a.friend_id) from travel_plan_audience a
          join friendships f on f.id=a.friendship_id and f.status='accepted'
          where a.plan_id=p.id and not exists(select 1 from user_blocks x where
            (x.blocker_id=p.owner_id and x.blocked_id=a.friend_id) or (x.blocker_id=a.friend_id and x.blocked_id=p.owner_id))),'[]'))
        order by p.start_day,p.id) from travel_plans p where p.owner_id=p_user_id),'[]'),
      'overlaps',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'friendID',o.friend_id,'friendName',u.display_name,
        'city',o.city,'countryCode',o.country_code,'region',o.region,'timeZone',o.time_zone,
        'startDay',o.start_day,'endDay',o.end_day) order by o.start_day,o.id)
        from travel_overlaps o join app_users u on u.id=o.friend_id where o.recipient_id=p_user_id),'[]'),
      'friendPlans',public.wif_friend_travel_plans(p_user_id));
end; $$;


-- Legacy clients cannot silently expand browsing to a new audience.
create or replace function public.wif_travel_save(p_user_id uuid,p_id uuid,p_city text,p_country text,p_region text,
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
        allow_friend_browsing=false,alerts_enabled=excluded.alerts_enabled,revision=travel_plans.revision+1,updated_at=now();
    delete from travel_plan_audience where plan_id=p_id;
    insert into travel_plan_audience(plan_id,friend_id,friendship_id)
      select distinct p_id,a.id,f.id from unnest(p_audience) a(id) join friendships f
        on f.pair_low_id=least(p_user_id,a.id) and f.pair_high_id=greatest(p_user_id,a.id) and f.status='accepted';
    return wif_travel_snapshot(p_user_id);
end; $$;



create function public.wif_travel_save_v2(p_user_id uuid,p_id uuid,p_city text,p_country text,p_region text,
    p_time_zone text,p_start date,p_end date,p_audience uuid[],p_alerts boolean,p_revision integer,
    p_allow_friend_browsing boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    if p_allow_friend_browsing is null then raise exception 'Invalid plan visibility.'; end if;
    -- The original write validates ownership, revision, dates, friendship and blocks,
    -- and acquires the row lock. Both changes commit together in this transaction.
    perform wif_travel_save(p_user_id,p_id,p_city,p_country,p_region,p_time_zone,p_start,p_end,p_audience,p_alerts,p_revision);
    update travel_plans set allow_friend_browsing=p_allow_friend_browsing where id=p_id and owner_id=p_user_id;
    return wif_travel_snapshot(p_user_id);
end; $$;

do $$ declare v_fn regprocedure; v_role text;
begin
    for v_fn in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace
      and proname in ('wif_friend_travel_plans','wif_travel_save_v2') loop
        execute format('revoke all on function %s from public',v_fn);
        foreach v_role in array array['anon','authenticated'] loop
            if exists(select 1 from pg_roles where rolname=v_role) then
                execute format('revoke all on function %s from %I',v_fn,v_role);
            end if;
        end loop;
        if exists(select 1 from pg_roles where rolname='service_role') then
            execute format('grant execute on function %s to service_role',v_fn);
        end if;
    end loop;
end; $$;
commit;

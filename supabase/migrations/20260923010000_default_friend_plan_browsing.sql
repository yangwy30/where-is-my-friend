begin;

-- Plans already have an explicit audience. Make their full city and dates
-- visible to that audience by default, including plans created before this change.
alter table public.travel_plans alter column allow_friend_browsing set default true;
update public.travel_plans
   set allow_friend_browsing=true, revision=revision+1, updated_at=now()
 where not allow_friend_browsing;

-- Older clients omit the visibility field. Their writes should use the new
-- default for a new plan and preserve an owner's later opt-out on edits.
create or replace function public.wif_travel_save(p_user_id uuid,p_id uuid,p_city text,p_country text,p_region text,
    p_time_zone text,p_start date,p_end date,p_audience uuid[],p_alerts boolean,p_revision integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_plan travel_plans; v_friend uuid; v_friendship uuid;
begin
    if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Account unavailable.'; end if;
    perform pg_advisory_xact_lock(hashtext('travel:'||p_user_id::text));
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

commit;

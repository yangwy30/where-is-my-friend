begin;

CREATE OR REPLACE FUNCTION public.wif_ensure_app_user(p_auth_user_id uuid, p_display_name text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
    v_user_id uuid;
    v_display_name text := nullif(left(trim(p_display_name), 40), '');
    v_username text;
begin
    if p_auth_user_id is null
       or not exists (select 1 from auth.users where id = p_auth_user_id) then
        raise exception 'Authenticated user is unavailable.';
    end if;

    perform pg_advisory_xact_lock(hashtextextended('wif:bootstrap:'||p_auth_user_id::text,0));
    select id into v_user_id
    from public.app_users
    where auth_user_id = p_auth_user_id
      and deleted_at is null;

    if found then
        if v_display_name is not null then
            update public.app_users
            set display_name = v_display_name,
                updated_at = now()
            where id = v_user_id
              and display_name = 'New Friend';
        end if;
    else
        if exists (
            select 1 from public.app_users
            where auth_user_id = p_auth_user_id
              and deleted_at is not null
        ) then
            raise exception 'This account is no longer available.';
        end if;

        v_username := 'friend_' || left(replace(p_auth_user_id::text, '-', ''), 13);
        insert into public.app_users(
            auth_user_id,
            username,
            display_name,
            avatar_palette,
            is_debug
        ) values (
            p_auth_user_id,
            v_username,
            coalesce(v_display_name, 'New Friend'),
            1,
            false
        )
        on conflict (auth_user_id) where auth_user_id is not null do nothing
        returning id into v_user_id;

        if v_user_id is null then
            select id into v_user_id
            from public.app_users
            where auth_user_id = p_auth_user_id
              and deleted_at is null;
        end if;
    end if;

    if v_user_id is null then
        raise exception 'This account is no longer available.';
    end if;

    insert into public.user_sharing_settings(user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;

    return v_user_id;
end;
$function$;

create or replace function public.wif_travel_core_snapshot(p_user_id uuid,p_include_plans boolean default true)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Account unavailable.'; end if;
    return jsonb_build_object(
      'includesOwnPlans',p_include_plans,
      'plans',case when p_include_plans then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'city',p.city,'countryCode',p.country_code,
        'region',p.region,'timeZone',p.time_zone,'startDay',p.start_day,'endDay',p.end_day,
        'alertsEnabled',p.alerts_enabled,'revision',p.revision,'allowFriendBrowsing',p.allow_friend_browsing,
        'audience',coalesce((select jsonb_agg(a.friend_id order by a.friend_id) from travel_plan_audience a
          join friendships f on f.id=a.friendship_id and f.status='accepted'
          where a.plan_id=p.id and not exists(select 1 from user_blocks x where
            (x.blocker_id=p.owner_id and x.blocked_id=a.friend_id) or (x.blocker_id=a.friend_id and x.blocked_id=p.owner_id))),'[]'))
        order by p.start_day,p.id) from travel_plans p where p.owner_id=p_user_id),'[]') else '[]'::jsonb end,
      'overlaps',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'friendID',o.friend_id,'friendName',u.display_name,
        'city',o.city,'countryCode',o.country_code,'region',o.region,'timeZone',o.time_zone,
        'startDay',o.start_day,'endDay',o.end_day) order by o.start_day,o.id)
        from travel_overlaps o join app_users u on u.id=o.friend_id where o.recipient_id=p_user_id),'[]'));
end; $$;

-- This view is private. Every query keeps friendship, audience and block checks.
create view public.wif_visible_friend_plan_rows as
select a.friend_id viewer_id,p.id,p.owner_id friend_id,u.display_name friend_name,
 p.city,p.country_code,p.region,p.time_zone,p.start_day,p.end_day,p.revision,p.updated_at
from travel_plans p
join travel_plan_audience a on a.plan_id=p.id
join friendships f on f.id=a.friendship_id and f.status='accepted'
 and f.pair_low_id=least(p.owner_id,a.friend_id) and f.pair_high_id=greatest(p.owner_id,a.friend_id)
join app_users u on u.id=p.owner_id and u.deleted_at is null
where p.owner_id<>a.friend_id and p.allow_friend_browsing
 and p.end_day>=(now() at time zone p.time_zone)::date
 and not exists(select 1 from user_blocks b where
 (b.blocker_id=a.friend_id and b.blocked_id=p.owner_id) or (b.blocker_id=p.owner_id and b.blocked_id=a.friend_id));
revoke all on public.wif_visible_friend_plan_rows from public;

create function public.wif_friend_plan_json(p public.wif_visible_friend_plan_rows)
returns jsonb language sql immutable set search_path=public as $$
 select jsonb_build_object('id',p.id,'friendID',p.friend_id,'friendName',p.friend_name,
 'city',p.city,'countryCode',p.country_code,'region',p.region,'timeZone',p.time_zone,'startDay',p.start_day,'endDay',p.end_day);
$$;

create function public.wif_travel_overview(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_core jsonb; v_summaries jsonb;
begin
 v_core:=wif_travel_core_snapshot(p_user_id,false);
 with ranked as (
  select p, row_number() over(partition by p.friend_id order by p.start_day,p.id) rn,
   count(*) over(partition by p.friend_id) total
  from wif_visible_friend_plan_rows p where viewer_id=p_user_id
 ) select coalesce(jsonb_agg(jsonb_build_object('friendID',(p).friend_id,'count',total,'nextPlan',wif_friend_plan_json(p)) order by (p).friend_id),'[]')
 into v_summaries from ranked where rn=1;
 return v_core||jsonb_build_object('friendPlanSummaries',v_summaries);
end; $$;

create function public.wif_friend_plan_page(p_user_id uuid,p_limit integer default 50,p_after_day date default null,
 p_after_id uuid default null,p_version text default null,p_friend_id uuid default null,p_plan_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_version text; v_items jsonb; v_cursor jsonb;
begin
 if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Account unavailable.'; end if;
 if p_limit is null or p_limit<1 or p_limit>50 or (p_after_day is null)<>(p_after_id is null)
 or (p_after_id is not null and (p_version is null or p_version!~'^[a-f0-9]{32}$')) then raise exception 'Invalid page cursor.'; end if;
 with eligible as materialized (
  select * from wif_visible_friend_plan_rows where viewer_id=p_user_id
 ), filtered as materialized (
  select * from eligible where (p_friend_id is null or friend_id=p_friend_id) and (p_plan_id is null or id=p_plan_id)
 ), revision as (
  select md5(coalesce(string_agg(id::text||':'||revision::text||':'||updated_at::text||':'||friend_name,'|' order by id),'')) v from filtered
 ), selected as (
  select row(p.*)::wif_visible_friend_plan_rows p from filtered p
  where (p_after_id is null or (start_day,id)>(p_after_day,p_after_id))
  order by start_day,id limit p_limit+1
 ), numbered as (select p,row_number() over(order by (p).start_day,(p).id) rn from selected)
 select revision.v,coalesce(jsonb_agg(wif_friend_plan_json(p) order by (p).start_day,(p).id) filter(where rn<=p_limit),'[]'),
  case when count(rn)>p_limit then (jsonb_agg(jsonb_build_object('startDay',(p).start_day,'id',(p).id,'version',revision.v) order by rn) filter(where rn<=p_limit))->(p_limit-1) end
 into v_version,v_items,v_cursor from revision left join numbered on true group by revision.v;
 if p_after_id is not null and p_version is distinct from v_version then
  return jsonb_build_object('items','[]'::jsonb,'version',v_version,'nextCursor',null,'resetRequired',true);
 end if;
 return jsonb_build_object('items',v_items,'version',v_version,'nextCursor',v_cursor,'resetRequired',false);
end; $$;

-- Legacy endpoints keep their full response; they never silently truncate plans.
create or replace function public.wif_travel_snapshot(p_user_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
 select wif_travel_core_snapshot(p_user_id)||jsonb_build_object('friendPlans',wif_friend_travel_plans(p_user_id));
$$;

revoke all on function public.wif_travel_core_snapshot(uuid,boolean),public.wif_friend_plan_json(public.wif_visible_friend_plan_rows),
 public.wif_travel_overview(uuid),public.wif_friend_plan_page(uuid,integer,date,uuid,text,uuid,uuid) from public;
do $$ declare r text; begin
 foreach r in array array['anon','authenticated'] loop
  if exists(select 1 from pg_roles where rolname=r) then
   execute format('revoke all on public.wif_visible_friend_plan_rows from %I',r);
   execute format('revoke all on function public.wif_travel_core_snapshot(uuid,boolean),public.wif_friend_plan_json(public.wif_visible_friend_plan_rows),public.wif_travel_overview(uuid),public.wif_friend_plan_page(uuid,integer,date,uuid,text,uuid,uuid) from %I',r);
  end if;
 end loop;
 if exists(select 1 from pg_roles where rolname='service_role') then
  grant execute on function public.wif_travel_core_snapshot(uuid,boolean),public.wif_travel_overview(uuid),public.wif_friend_plan_page(uuid,integer,date,uuid,text,uuid,uuid) to service_role;
 end if;
end $$;
commit;

begin;

create function public.wif_travel_overlap_snapshot(p_user_id uuid,p_limit integer default null,p_id text default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_items jsonb; v_count integer; v_version text;
begin
 if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Account unavailable.'; end if;
 if (p_limit is not null and (p_limit<1 or p_limit>3)) or (p_id is not null and p_id!~'^[a-f0-9]{32}$') then raise exception 'Invalid overlap query.'; end if;
 with eligible as materialized (
  select o.*,u.display_name friend_name from travel_overlaps o join app_users u on u.id=o.friend_id and u.deleted_at is null
  where o.recipient_id=p_user_id
 ), totals as (
  select count(*)::integer total,md5(coalesce(string_agg(id||':'||friend_name||':'||city||':'||country_code||':'||region||':'||time_zone,'|' order by id),'')) version from eligible
 ), selected as (
  select * from eligible where p_id is null or id=p_id order by start_day,id limit p_limit
 )
 select total,version,coalesce((select jsonb_agg(jsonb_build_object('id',id,'friendID',friend_id,'friendName',friend_name,
  'city',city,'countryCode',country_code,'region',region,'timeZone',time_zone,'startDay',start_day,'endDay',end_day) order by start_day,id) from selected),'[]')
 into v_count,v_version,v_items from totals;
 return jsonb_build_object('overlaps',v_items,'overlapCount',v_count,'overlapVersion',v_version,
  'includesAllOverlaps',p_id is null and (p_limit is null or v_count<=p_limit));
end; $$;

create or replace function public.wif_travel_overview(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_overlaps jsonb; v_summaries jsonb;
begin
 v_overlaps:=wif_travel_overlap_snapshot(p_user_id,3);
 with ranked as (
  select p,row_number() over(partition by p.friend_id order by p.start_day,p.id) rn,count(*) over(partition by p.friend_id) total
  from wif_visible_friend_plan_rows p where viewer_id=p_user_id
 ) select coalesce(jsonb_agg(jsonb_build_object('friendID',(p).friend_id,'count',total,'nextPlan',wif_friend_plan_json(p)) order by (p).friend_id),'[]')
 into v_summaries from ranked where rn=1;
 return v_overlaps||jsonb_build_object('plans','[]'::jsonb,'includesOwnPlans',false,'friendPlanSummaries',v_summaries);
end; $$;

revoke all on function public.wif_travel_overlap_snapshot(uuid,integer,text) from public;
do $$ declare r text; begin
 foreach r in array array['anon','authenticated'] loop
  if exists(select 1 from pg_roles where rolname=r) then execute format('revoke all on function public.wif_travel_overlap_snapshot(uuid,integer,text) from %I',r); end if;
 end loop;
 if exists(select 1 from pg_roles where rolname='service_role') then grant execute on function public.wif_travel_overlap_snapshot(uuid,integer,text) to service_role; end if;
end $$;
commit;

begin;

-- Run when there is no active upcoming-delivery lease. Do not invalidate a
-- sender mid-flight while rewriting notification identities.
do $$ begin
 if exists(select 1 from public.upcoming_deliveries where status='pending'
   and claimed_at>now()-interval '2 minutes') then
   raise exception 'Upcoming delivery in flight; retry migration after the lease finishes.';
 end if;
end $$;

create temporary table prior_travel_overlaps on commit drop as
 select id,recipient_id,friend_id,start_day,end_day,
        public.wif_presence_key(city,country_code,region)||'|'||time_zone as next_key
 from public.travel_overlaps;

create function public.wif_travel_identity_trigger() returns trigger
language plpgsql set search_path=public as $$
begin
 new.city_key:=coalesce(public.wif_presence_key(new.city,new.country_code,new.region)||'|'||new.time_zone,
                       'unresolved|'||new.id::text);
 return new;
end; $$;
create trigger travel_plan_identity before insert or update of city,country_code,region,time_zone,city_key
 on public.travel_plans for each row execute function public.wif_travel_identity_trigger();
revoke all on function public.wif_travel_identity_trigger() from public;
do $$ declare r text; begin
 foreach r in array array['anon','authenticated'] loop
  if exists(select 1 from pg_roles where rolname=r) then
   execute format('revoke all on function public.wif_travel_identity_trigger() from %I',r);
  end if;
 end loop;
end $$;

update public.travel_plans set city_key=city_key;

-- Carry delivery state onto the new IDs. Already delivered/failed notices are
-- not replayed; pending work keeps its attempt count and backoff. Keep old rows
-- for history rather than deleting sent notifications.
insert into public.upcoming_deliveries(overlap_id,recipient_id,device_id,status,attempts,available_at)
 select current.id,d.recipient_id,d.device_id,
   case when bool_or(d.status='delivered') then 'delivered'
        when bool_or(d.status='pending') then 'pending' else 'failed' end,
   max(d.attempts),max(d.available_at)
 from public.upcoming_deliveries d
 join prior_travel_overlaps previous on previous.id=d.overlap_id and previous.recipient_id=d.recipient_id
 join public.travel_overlaps current on current.recipient_id=previous.recipient_id
   and current.friend_id=previous.friend_id and current.city_key=previous.next_key
   and current.start_day=previous.start_day and current.end_day=previous.end_day
 where current.id<>d.overlap_id
 group by current.id,d.recipient_id,d.device_id
 on conflict(overlap_id,device_id,recipient_id) do nothing;

update public.upcoming_deliveries d set status='failed',claim_token=null,claimed_at=null
 where status='pending' and not exists(select 1 from public.travel_overlaps o where o.id=d.overlap_id and o.recipient_id=d.recipient_id);

create or replace function public.wif_travel_claim(p_token uuid)
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
      where d.status='pending' and (
        (d.attempts>=5 and (d.claimed_at is null or d.claimed_at<now()-interval '2 minutes'))
        or not wif_travel_delivery_allowed(d));
    with next as (select id from upcoming_deliveries where status='pending' and available_at<=now()
      and (claimed_at is null or claimed_at<now()-interval '2 minutes') order by available_at,id for update skip locked limit 10),
    claimed as (update upcoming_deliveries d set claim_token=p_token,claimed_at=now(),attempts=attempts+1
      from next where d.id=next.id returning d.id)
    select coalesce(jsonb_agg(jsonb_build_object('delivery_id',id)),'[]') into v_result from claimed;
    return v_result;
end; $$;
commit;

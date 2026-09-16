begin;

-- New invitations only: do not surprise users by backfilling historical invites.
create table public.trip_invitation_alerts (
    invitation_id uuid primary key,
    recipient_id uuid not null references public.app_users(id) on delete cascade,
    trip_id text not null references public.trips(id) on delete cascade,
    created_at timestamptz not null default now()
);
create table public.trip_invitation_deliveries (
    id uuid primary key default gen_random_uuid(),
    invitation_id uuid not null references public.trip_invitation_alerts(invitation_id) on delete cascade,
    recipient_id uuid not null references public.app_users(id) on delete cascade,
    device_id uuid not null references public.devices(id) on delete cascade,
    status text not null default 'pending' check(status in ('pending','delivered','failed')),
    attempts integer not null default 0,
    available_at timestamptz not null default now(),
    claim_token uuid,
    claimed_at timestamptz,
    delivered_at timestamptz,
    last_error text,
    apns_id text,
    unique(invitation_id,device_id)
);
create index trip_invitation_delivery_pending on public.trip_invitation_deliveries(available_at)
    where status='pending';

create function public.wif_trip_invitation_enqueue()
returns trigger language plpgsql security definer set search_path=public as $$
begin
    if new.accepted_at is null and new.expires_at>now() then
        insert into trip_invitation_alerts(invitation_id,recipient_id,trip_id)
            values(new.id,new.invited_user_id,new.trip_id) on conflict do nothing;
    end if;
    return new;
end; $$;
create trigger trip_invitation_alert_created after insert or update of id on public.trip_invitations
    for each row execute function public.wif_trip_invitation_enqueue();

-- Repeated taps/retried requests return the same active invite, not extra pushes.
create or replace function public.wif_trip_invite(p_user_id uuid,p_trip_id text,p_username text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_target uuid; v_invite public.trip_invitations;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
    select id into v_target from app_users where username=lower(trim(leading '@' from trim(p_username))) and deleted_at is null;
    if v_target is null then raise exception 'No user has that username.'; end if;
    if exists(select 1 from user_blocks where (blocker_id=p_user_id and blocked_id=v_target) or (blocker_id=v_target and blocked_id=p_user_id)) then raise exception 'Trip access denied.'; end if;
    if exists(select 1 from trip_members where trip_id=p_trip_id and user_id=v_target) then raise exception 'Already a trip member.'; end if;
    perform pg_advisory_xact_lock(hashtext('trip-invite:'||p_trip_id||':'||v_target::text));
    select * into v_invite from trip_invitations where trip_id=p_trip_id and invited_user_id=v_target
        and accepted_at is null and expires_at>now();
    if found then return to_jsonb(v_invite); end if;
    insert into trip_invitations(trip_id,invited_user_id,invited_by) values(p_trip_id,v_target,p_user_id)
        on conflict(trip_id,invited_user_id) do update set id=gen_random_uuid(),invited_by=p_user_id,expires_at=now()+interval '7 days',accepted_at=null
        returning * into v_invite;
    return to_jsonb(v_invite);
end; $$;

create function public.wif_trip_invitation_alert_allowed(p_invitation uuid,p_recipient uuid,p_device uuid)
returns boolean language sql stable security definer set search_path=public as $$
    select exists(select 1 from trip_invitations i
      join trips t on t.id=i.trip_id
      join app_users u on u.id=i.invited_user_id and u.deleted_at is null
      join app_users sender on sender.id=i.invited_by and sender.deleted_at is null
      join devices d on d.id=p_device and d.user_id=p_recipient and d.disabled_at is null
      where i.id=p_invitation and i.invited_user_id=p_recipient and i.accepted_at is null and i.expires_at>now() and t.completed_at is null
      and exists(select 1 from trip_members m where m.trip_id=i.trip_id and m.user_id=i.invited_by and m.role='owner')
      and not exists(select 1 from trip_members m where m.trip_id=i.trip_id and m.user_id=p_recipient)
      and not exists(select 1 from user_blocks b where (b.blocker_id=i.invited_by and b.blocked_id=p_recipient)
        or (b.blocker_id=p_recipient and b.blocked_id=i.invited_by)));
$$;

create function public.wif_trip_invitation_claim(p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
    if p_token is null then raise exception 'Claim token required.'; end if;
    insert into trip_invitation_deliveries(invitation_id,recipient_id,device_id)
      select a.invitation_id,a.recipient_id,d.id from trip_invitation_alerts a
      join devices d on d.user_id=a.recipient_id
      where wif_trip_invitation_alert_allowed(a.invitation_id,a.recipient_id,d.id)
      on conflict do nothing;
    update trip_invitation_deliveries d set status='failed',claim_token=null,claimed_at=null,
      last_error='Invitation unavailable, device reassigned, or retry limit reached.'
      where d.status='pending' and ((d.attempts>=5 and (d.claimed_at is null or d.claimed_at<now()-interval '2 minutes'))
        or not wif_trip_invitation_alert_allowed(d.invitation_id,d.recipient_id,d.device_id));
    with next as (select id from trip_invitation_deliveries where status='pending' and available_at<=now()
      and (claimed_at is null or claimed_at<now()-interval '2 minutes') order by available_at,id for update skip locked limit 20),
    claimed as (update trip_invitation_deliveries d set claim_token=p_token,claimed_at=now(),attempts=attempts+1
      from next where d.id=next.id returning d.id)
    select coalesce(jsonb_agg(jsonb_build_object('delivery_id',id)),'[]') into v_result from claimed;
    return v_result;
end; $$;

create function public.wif_trip_invitation_prepare(p_id uuid,p_token uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_d trip_invitation_deliveries;
begin
    select * into v_d from trip_invitation_deliveries where id=p_id and claim_token=p_token and status='pending'
      and claimed_at>now()-interval '2 minutes';
    if v_d.id is null or not wif_trip_invitation_alert_allowed(v_d.invitation_id,v_d.recipient_id,v_d.device_id) then return null; end if;
    return (select jsonb_build_object('delivery_id',v_d.id,'device_id',d.id,'encrypted_apns_token',d.encrypted_apns_token,
      'environment',d.environment,'bundle_id',d.bundle_id,'event_id',i.id,
      'expires_at',extract(epoch from least(i.expires_at,now()+interval '1 hour'))::bigint,
      'title','Trip invitation',
      'body',case when s.notification_preview_enabled then sender.display_name||' invited you to '||t.name||'. Tap to review.'
        else 'You have a new trip invitation. Open Across Us to review.' end,
      'deep_link',d.url_scheme||'://trips/join/'||i.id::text)
      from trip_invitations i join trips t on t.id=i.trip_id join app_users sender on sender.id=i.invited_by
      join devices d on d.id=v_d.device_id join user_sharing_settings s on s.user_id=v_d.recipient_id
      where i.id=v_d.invitation_id);
end; $$;

create function public.wif_trip_invitation_complete(p_id uuid,p_token uuid,p_outcome text,
    p_error text default null,p_apns_id text default null,p_disable_device boolean default false)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_d trip_invitation_deliveries;
begin
    if p_outcome is null or p_outcome not in ('delivered','retry','failed') then raise exception 'Invalid outcome.'; end if;
    update trip_invitation_deliveries set status=case when p_outcome='retry' and attempts<5 then 'pending' when p_outcome='retry' then 'failed' else p_outcome end,
      claim_token=null,claimed_at=null,available_at=now()+interval '1 minute',
      delivered_at=case when p_outcome='delivered' then now() else delivered_at end,last_error=left(p_error,500),apns_id=p_apns_id
      where id=p_id and claim_token=p_token and status='pending' returning * into v_d;
    if v_d.id is null then return false; end if;
    if p_disable_device then update devices set disabled_at=now(),disabled_reason='apns_permanent_error'
      where id=v_d.device_id and user_id=v_d.recipient_id; end if;
    return true;
end; $$;

alter table trip_invitation_alerts enable row level security;
alter table trip_invitation_deliveries enable row level security;
revoke all on trip_invitation_alerts,trip_invitation_deliveries from public;
do $$ declare v_fn regprocedure; v_role text;
begin
    foreach v_role in array array['anon','authenticated'] loop
      if exists(select 1 from pg_roles where rolname=v_role) then
        execute format('revoke all on public.trip_invitation_alerts,public.trip_invitation_deliveries from %I',v_role);
      end if;
    end loop;
    for v_fn in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace
      and proname in ('wif_trip_invitation_enqueue','wif_trip_invitation_alert_allowed','wif_trip_invitation_claim','wif_trip_invitation_prepare','wif_trip_invitation_complete') loop
      execute format('revoke all on function %s from public',v_fn);
      foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then execute format('revoke all on function %s from %I',v_fn,v_role); end if;
      end loop;
      if exists(select 1 from pg_roles where rolname='service_role') then execute format('grant execute on function %s to service_role',v_fn); end if;
    end loop;
end; $$;
commit;

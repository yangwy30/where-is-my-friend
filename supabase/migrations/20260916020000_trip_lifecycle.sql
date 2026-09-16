begin;

alter table public.trips add column cancelled_at timestamptz;
alter table public.trips add constraint cancelled_trip_is_archived check (cancelled_at is null or completed_at is not null);

-- Minimal receipts survive deletion, so a lost response can be retried safely.
-- No itinerary or participant names are retained here.
create table public.trip_lifecycle_receipts (
    user_id uuid not null references public.app_users(id) on delete cascade,
    request_id uuid not null,
    trip_id text not null,
    action text not null,
    participant_id uuid,
    revision bigint,
    created_at timestamptz not null default now(),
    primary key(user_id,request_id)
);
alter table public.trip_lifecycle_receipts enable row level security;
revoke all on public.trip_lifecycle_receipts from public;

-- Serialize writes against removal/cancellation, then re-check membership.
create or replace function public.wif_trip_assert_access(p_user_id uuid,p_trip_id text,p_write boolean default false,p_manage boolean default false)
returns void language plpgsql security definer set search_path=public as $$
declare v_role text; v_cancelled timestamptz;
begin
    if p_write or p_manage then
        select cancelled_at into v_cancelled from trips where id=p_trip_id for update;
    end if;
    select m.role into v_role from trip_members m join app_users u on u.id=m.user_id and u.deleted_at is null
        where m.trip_id=p_trip_id and m.user_id=p_user_id;
    if v_role is null or (p_manage and v_role<>'owner') then raise exception 'Trip access denied.'; end if;
    if (p_write or p_manage) and v_cancelled is not null then raise exception 'This trip is cancelled and read-only.'; end if;
end; $$;

create or replace function public.wif_trip_self_participant(p_user_id uuid,p_trip_id text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
    perform wif_trip_assert_access(p_user_id,p_trip_id,true);
    select id into v_id from participants where trip_id=p_trip_id and user_id=p_user_id;
    if v_id is null then raise exception 'Trip access denied.'; end if;
    return v_id;
end; $$;

create or replace function public.wif_trip_preferences(p_user_id uuid,p_trip_id text,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    perform wif_trip_assert_access(p_user_id,p_trip_id,true);
    if p_enabled is null then raise exception 'Invalid preference.'; end if;
    update trip_members set flight_alerts_enabled=p_enabled where trip_id=p_trip_id and user_id=p_user_id;
    return wif_trip_snapshot(p_user_id,p_trip_id);
end; $$;

-- All invitation writes acquire the trip lock before the invitation lock.
create or replace function public.wif_trip_accept_invitation(p_user_id uuid,p_invitation_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_invite public.trip_invitations; v_name text; v_trip text;
begin
    select trip_id into v_trip from trip_invitations where id=p_invitation_id and invited_user_id=p_user_id;
    perform 1 from trips where id=v_trip for update;
    select display_name into v_name from app_users where id=p_user_id and deleted_at is null;
    select * into v_invite from trip_invitations where id=p_invitation_id and invited_user_id=p_user_id for update;
    if v_name is null or v_invite.id is null then raise exception 'Trip access denied.'; end if;
    if exists(select 1 from user_blocks where (blocker_id=p_user_id and blocked_id=v_invite.invited_by)
        or (blocker_id=v_invite.invited_by and blocked_id=p_user_id)) then raise exception 'Trip access denied.'; end if;
    if v_invite.accepted_at is not null then return wif_trip_snapshot(p_user_id,v_invite.trip_id); end if;
    if v_invite.expires_at<=now() then raise exception 'Trip access denied.'; end if;
    perform wif_trip_assert_access(v_invite.invited_by,v_invite.trip_id,true,true);
    insert into trip_members(trip_id,user_id,role) values(v_invite.trip_id,p_user_id,'member') on conflict do nothing;
    insert into participants(trip_id,name,user_id) values(v_invite.trip_id,v_name,p_user_id) on conflict do nothing;
    update trip_invitations set accepted_at=now() where id=v_invite.id;
    update trips set revision=revision where id=v_invite.trip_id;
    return wif_trip_snapshot(p_user_id,v_invite.trip_id);
end; $$;

create or replace function public.wif_trip_dismiss_invitation(p_user_id uuid,p_invitation_id uuid,p_revoke boolean default false)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_invite public.trip_invitations; v_trip text;
begin
    select trip_id into v_trip from trip_invitations where id=p_invitation_id;
    perform 1 from trips where id=v_trip for update;
    select * into v_invite from trip_invitations where id=p_invitation_id for update;
    if v_invite.id is null then raise exception 'Trip access denied.'; end if;
    if p_revoke then perform wif_trip_assert_access(p_user_id,v_invite.trip_id,true,true);
    elsif v_invite.invited_user_id<>p_user_id then raise exception 'Trip access denied.'; end if;
    if v_invite.accepted_at is not null then raise exception 'Invitation already accepted.'; end if;
    update trip_invitations set expires_at=least(expires_at,now()) where id=p_invitation_id;
    return true;
end; $$;

create function public.wif_trip_lifecycle(p_user_id uuid,p_trip_id text,p_action text,p_request_id uuid,
    p_revision bigint default null,p_participant_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_receipt public.trip_lifecycle_receipts; v_trip public.trips; v_person public.participants; v_role text;
begin
    if p_request_id is null or p_action is null or p_action not in ('leave','cancel','delete','removeMember')
        or (p_action='removeMember')<>(p_participant_id is not null) then raise exception 'Invalid trip action.'; end if;
    if not exists(select 1 from app_users where id=p_user_id and deleted_at is null) then raise exception 'Trip access denied.'; end if;
    perform pg_advisory_xact_lock(hashtext(p_user_id::text||p_request_id::text));
    select * into v_receipt from trip_lifecycle_receipts where user_id=p_user_id and request_id=p_request_id;
    select * into v_trip from trips where id=p_trip_id for update;
    if v_receipt.request_id is not null then
        if row(v_receipt.trip_id,v_receipt.action,v_receipt.participant_id,v_receipt.revision)
            is distinct from row(p_trip_id,p_action,p_participant_id,p_revision) then raise exception 'Trip request conflict.'; end if;
        return jsonb_build_object('success',true,'trip',case when exists(select 1 from trip_members where trip_id=p_trip_id and user_id=p_user_id)
            then wif_trip_snapshot(p_user_id,p_trip_id) else null end);
    end if;
    perform wif_trip_assert_access(p_user_id,p_trip_id);
    select role into v_role from trip_members where trip_id=p_trip_id and user_id=p_user_id;
    if p_action='leave' then
        if v_role='owner' then raise exception 'The creator must cancel or delete the trip instead of leaving.'; end if;
        select * into v_person from participants where trip_id=p_trip_id and user_id=p_user_id;
    else
        if v_role<>'owner' then raise exception 'Trip access denied.'; end if;
        if p_revision is distinct from v_trip.revision then raise exception 'Trip conflict. Refresh before trying again.'; end if;
    end if;
    if p_action='removeMember' then
        select * into v_person from participants where trip_id=p_trip_id and id=p_participant_id;
        if v_person.id is null or v_person.user_id=p_user_id or exists(select 1 from trip_members
            where trip_id=p_trip_id and user_id=v_person.user_id and role='owner') then raise exception 'Trip access denied.'; end if;
    end if;
    if p_action in ('leave','removeMember') then
        -- Removing itinerary data is part of withdrawing access, not editing someone else's flight.
        delete from flights where trip_id=p_trip_id and participant_id=v_person.id;
        delete from participants where trip_id=p_trip_id and id=v_person.id;
        delete from trip_members where trip_id=p_trip_id and user_id=case when p_action='leave' then p_user_id else v_person.user_id end;
        delete from trip_invitations where trip_id=p_trip_id and invited_user_id=case when p_action='leave' then p_user_id else v_person.user_id end;
        delete from trip_invitation_alerts where trip_id=p_trip_id and recipient_id=case when p_action='leave' then p_user_id else v_person.user_id end;
        delete from trip_flight_deliveries d using trip_flight_events e,flights f
            where d.event_id=e.id and e.flight_id=f.id and f.trip_id=p_trip_id
            and d.recipient_id=case when p_action='leave' then p_user_id else v_person.user_id end;
        update trips set revision=revision where id=p_trip_id;
    elsif p_action='cancel' then
        update trips set cancelled_at=coalesce(cancelled_at,now()),completed_at=coalesce(completed_at,now()) where id=p_trip_id;
        update trip_invitations set expires_at=least(expires_at,now()) where trip_id=p_trip_id and accepted_at is null;
        delete from trip_invitation_alerts where trip_id=p_trip_id;
        update trip_flight_deliveries d set status='failed',claim_token=null,claimed_at=null
            from trip_flight_events e,flights f where d.event_id=e.id and e.flight_id=f.id and f.trip_id=p_trip_id and d.status='pending';
    elsif p_action='delete' then
        -- Remove dependent flights first: their participant FK intentionally has no cascade.
        delete from flights where trip_id=p_trip_id;
        delete from trips where id=p_trip_id;
    end if;
    insert into trip_lifecycle_receipts(user_id,request_id,trip_id,action,participant_id,revision)
        values(p_user_id,p_request_id,p_trip_id,p_action,p_participant_id,p_revision);
    return jsonb_build_object('success',true,'trip',case when p_action in ('cancel','removeMember')
        then wif_trip_snapshot(p_user_id,p_trip_id) else null end);
end; $$;

revoke all on function public.wif_trip_lifecycle(uuid,text,text,uuid,bigint,uuid) from public;
do $$ declare v_role text; begin
    foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then
            execute format('revoke all on public.trip_lifecycle_receipts from %I',v_role);
            execute format('revoke all on function public.wif_trip_lifecycle(uuid,text,text,uuid,bigint,uuid) from %I',v_role);
        end if;
    end loop;
    if exists(select 1 from pg_roles where rolname='service_role') then
        grant execute on function public.wif_trip_lifecycle(uuid,text,text,uuid,bigint,uuid) to service_role;
    end if;
end; $$;
commit;

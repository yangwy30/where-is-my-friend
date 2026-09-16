-- Supersedes shared editing. Apply after the foundation; no legacy identity claims.
begin;
alter table public.trip_members drop constraint trip_members_role_check;
update public.trip_members set role='member' where role in ('editor','viewer');
alter table public.trip_members add constraint trip_members_role_check check (role in ('owner','member'));

create or replace function public.wif_trip_assert_access(p_user_id uuid, p_trip_id text, p_write boolean default false, p_manage boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare v_role text;
begin
    select m.role into v_role from public.trip_members m
    join public.app_users u on u.id=m.user_id and u.deleted_at is null
    where m.trip_id=p_trip_id and m.user_id=p_user_id;
    if v_role is null or (p_manage and v_role <> 'owner') then raise exception 'Trip access denied.'; end if;
end;
$$;

-- Remove the callable shared-editor signatures, not merely their UI entry points.
drop function public.wif_trip_add_guest(uuid,text,uuid,text);
drop function public.wif_trip_add_flight(uuid,text,text,uuid,text,date,text);

create function public.wif_trip_self_participant(p_user_id uuid, p_trip_id text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id);
    select id into v_id from public.participants where trip_id=p_trip_id and user_id=p_user_id;
    if v_id is null then raise exception 'Trip access denied.'; end if;
    return v_id;
end;
$$;

create function public.wif_trip_add_flight(p_user_id uuid, p_trip_id text, p_flight_id text,
    p_flight_number text, p_date date, p_direction text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text;
begin
    v_id := public.wif_trip_self_participant(p_user_id,p_trip_id);
    select name into v_name from public.participants where id=v_id;
    if p_flight_id is null or char_length(p_flight_id) not between 1 and 100
       or p_date is null or p_direction is null or p_direction not in ('outbound','inbound')
       or p_flight_number is null or upper(trim(p_flight_number)) !~ '^[A-Z0-9]{2,3} ?[0-9]{1,4}[A-Z]?$' then
        raise exception 'Invalid flight details.';
    end if;
    insert into public.flights(id,trip_id,participant_id,flight_number,date,direction,added_by,status)
        values(p_flight_id,p_trip_id,v_id,upper(trim(p_flight_number)),to_char(p_date,'YYYY-MM-DD'),p_direction,v_name,'unverified')
        on conflict(id) do nothing;
    if not found and not exists(select 1 from public.flights where id=p_flight_id and trip_id=p_trip_id
        and participant_id=v_id and flight_number=upper(trim(p_flight_number))
        and date=to_char(p_date,'YYYY-MM-DD') and direction=p_direction) then raise exception 'Flight conflict.'; end if;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_update_flight(p_user_id uuid, p_trip_id text, p_flight_id text,
    p_flight_number text, p_date date, p_direction text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
    v_id := public.wif_trip_self_participant(p_user_id,p_trip_id);
    if p_date is null or p_direction is null or p_direction not in ('outbound','inbound')
       or p_flight_number is null or upper(trim(p_flight_number)) !~ '^[A-Z0-9]{2,3} ?[0-9]{1,4}[A-Z]?$' then
        raise exception 'Invalid flight details.';
    end if;
    -- A changed flight must not retain the previous flight's verified schedule/status.
    update public.flights set flight_number=upper(trim(p_flight_number)),date=to_char(p_date,'YYYY-MM-DD'),
        direction=p_direction,status='unverified',departure='{}',arrival='{}',airline='',duration='',aircraft='',gate=''
        where id=p_flight_id and trip_id=p_trip_id and participant_id=v_id;
    if not found then raise exception 'Trip access denied.'; end if;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_delete_flight(p_user_id uuid, p_trip_id text, p_flight_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
    v_id := public.wif_trip_self_participant(p_user_id,p_trip_id);
    delete from public.flights where id=p_flight_id and trip_id=p_trip_id and participant_id=v_id;
    if not found then raise exception 'Trip access denied.'; end if;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

-- Membership is accepted by a registered account, never created from a guest name or PIN.
create table public.trip_invitations (
    id uuid primary key default gen_random_uuid(),
    trip_id text not null references public.trips(id) on delete cascade,
    invited_user_id uuid not null references public.app_users(id) on delete cascade,
    invited_by uuid not null references public.app_users(id) on delete cascade,
    expires_at timestamptz not null default now() + interval '7 days',
    accepted_at timestamptz,
    unique(trip_id,invited_user_id)
);
alter table public.trip_invitations enable row level security;
revoke all on public.trip_invitations from public;

create function public.wif_trip_invite(p_user_id uuid, p_trip_id text, p_username text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_target uuid; v_invite public.trip_invitations;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
    select id into v_target from public.app_users
        where username=lower(trim(leading '@' from trim(p_username))) and deleted_at is null;
    if v_target is null then raise exception 'No user has that username.'; end if;
    if exists(select 1 from public.trip_members where trip_id=p_trip_id and user_id=v_target) then
        raise exception 'Already a trip member.';
    end if;
    insert into public.trip_invitations(trip_id,invited_user_id,invited_by)
        values(p_trip_id,v_target,p_user_id)
        on conflict(trip_id,invited_user_id) do update set invited_by=p_user_id,expires_at=now()+interval '7 days',accepted_at=null
        returning * into v_invite;
    return to_jsonb(v_invite);
end;
$$;

create function public.wif_trip_invitations(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
    if not exists(select 1 from public.app_users where id=p_user_id and deleted_at is null) then
        raise exception 'Trip access denied.';
    end if;
    return (select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'trip_name',t.name,'expires_at',i.expires_at)),'[]'::jsonb)
        from public.trip_invitations i join public.trips t on t.id=i.trip_id
        where i.invited_user_id=p_user_id and i.accepted_at is null and i.expires_at>now());
end;
$$;

create function public.wif_trip_accept_invitation(p_user_id uuid, p_invitation_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_invite public.trip_invitations; v_name text;
begin
    select display_name into v_name from public.app_users where id=p_user_id and deleted_at is null;
    select * into v_invite from public.trip_invitations where id=p_invitation_id and invited_user_id=p_user_id for update;
    if v_name is null or v_invite.id is null then raise exception 'Trip access denied.'; end if;
    if v_invite.accepted_at is not null then return public.wif_trip_snapshot(p_user_id,v_invite.trip_id); end if;
    if v_invite.expires_at<=now() then raise exception 'Trip access denied.'; end if;
    perform public.wif_trip_assert_access(v_invite.invited_by,v_invite.trip_id,true,true);
    insert into public.trip_members(trip_id,user_id,role) values(v_invite.trip_id,p_user_id,'member') on conflict do nothing;
    -- New account-linked row; deliberately never UPDATE an unclaimed namesake.
    insert into public.participants(trip_id,name,user_id) values(v_invite.trip_id,v_name,p_user_id) on conflict do nothing;
    update public.trip_invitations set accepted_at=now() where id=v_invite.id;
    return public.wif_trip_snapshot(p_user_id,v_invite.trip_id);
end;
$$;

do $$
declare v_function regprocedure; v_role text;
begin
    foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then
            execute format('revoke all on public.trip_invitations from %I',v_role);
        end if;
    end loop;
    for v_function in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname like 'wif_trip_%' loop
        execute format('revoke all on function %s from public',v_function);
        foreach v_role in array array['anon','authenticated'] loop
            if exists(select 1 from pg_roles where rolname=v_role) then execute format('revoke all on function %s from %I',v_function,v_role); end if;
        end loop;
        if exists(select 1 from pg_roles where rolname='service_role') then execute format('grant execute on function %s to service_role',v_function); end if;
    end loop;
end;
$$;
commit;

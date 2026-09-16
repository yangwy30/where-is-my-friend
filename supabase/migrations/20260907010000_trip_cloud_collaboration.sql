begin;

-- Per-resource revisions prevent stale devices from overwriting newer edits.
alter table public.trips add column revision bigint not null default 1;
alter table public.flights add column revision bigint not null default 1;
alter table public.flights add column candidate_id text;
alter table public.flights add column verified_at timestamptz;
create function public.wif_trip_bump_revision() returns trigger
language plpgsql set search_path=public as $$
begin new.revision := old.revision + 1; return new; end;
$$;
create trigger trip_revision before update on public.trips for each row execute function public.wif_trip_bump_revision();
create trigger flight_revision before update on public.flights for each row execute function public.wif_trip_bump_revision();

-- One transaction: ownership, optimistic concurrency, edit, provider candidate, snapshot.
-- Only candidate IDs are accepted from clients, never provider status/route JSON.
create function public.wif_trip_mutate(p_user_id uuid,p_trip_id text,p_kind text,p_body jsonb,p_revision bigint default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_revision bigint; v_person uuid; v_flight public.flights; v_candidate jsonb; v_result jsonb;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id);
    select revision into v_revision from public.trips where id=p_trip_id for update;
    if p_kind in ('details','completion') then
        perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
        if p_revision is distinct from v_revision then raise exception 'Trip conflict. Refresh before saving again.'; end if;
        if p_kind='details' then
            return public.wif_trip_update(p_user_id,p_trip_id,p_body->>'name',p_body->>'destinationAirport',
                (p_body->>'startDate')::date,(p_body->>'endDate')::date);
        end if;
        if jsonb_typeof(p_body->'completed') is distinct from 'boolean' then raise exception 'Invalid completion.'; end if;
        return public.wif_trip_complete(p_user_id,p_trip_id,(p_body->>'completed')::boolean);
    end if;
    if p_kind not in ('addFlight','editFlight','deleteFlight') then raise exception 'Invalid trip operation.'; end if;
    v_person := public.wif_trip_self_participant(p_user_id,p_trip_id);
    select * into v_flight from public.flights where id=p_body->>'id' for update;
    if v_flight.id is not null and (v_flight.trip_id<>p_trip_id or v_flight.participant_id<>v_person) then
        raise exception 'Trip access denied.';
    end if;
    if p_kind='addFlight' and v_flight.id is not null then
        if replace(v_flight.flight_number,' ','')=replace(upper(p_body->>'flightNumber'),' ','')
            and v_flight.date=p_body->>'date' and v_flight.direction=p_body->>'direction'
            and v_flight.candidate_id is not distinct from p_body->>'candidateID' then
            return public.wif_trip_snapshot(p_user_id,p_trip_id);
        end if;
        raise exception 'Flight conflict. Refresh before saving again.';
    end if;
    if p_kind<>'addFlight' and (v_flight.id is null or p_revision is distinct from v_flight.revision) then
        raise exception 'Flight conflict. Refresh before saving again.';
    end if;
    if p_kind='deleteFlight' then return public.wif_trip_delete_flight(p_user_id,p_trip_id,p_body->>'id'); end if;
    if p_body->>'candidateID' is not null then
        select c.result into v_result from public.trip_flight_lookup_cache c
            where c.flight_number=replace(upper(p_body->>'flightNumber'),' ','')
            and c.departure_date=(p_body->>'date')::date and c.expires_at>now();
        select value into v_candidate from jsonb_array_elements(v_result->'flights')
            where value->>'id'=p_body->>'candidateID';
        if v_candidate is null then raise exception 'Flight search expired. Search again before saving.'; end if;
    end if;
    if p_kind='addFlight' then
        perform public.wif_trip_add_flight(p_user_id,p_trip_id,p_body->>'id',p_body->>'flightNumber',(p_body->>'date')::date,p_body->>'direction');
    else
        perform public.wif_trip_update_flight(p_user_id,p_trip_id,p_body->>'id',p_body->>'flightNumber',(p_body->>'date')::date,p_body->>'direction');
    end if;
    update public.flights set candidate_id=p_body->>'candidateID',verified_at=null where id=p_body->>'id';
    if v_candidate is not null then
        update public.flights set departure=v_candidate->'departure',arrival=v_candidate->'arrival',
            airline=coalesce(v_candidate->>'airline',''),status=coalesce(v_candidate->>'status','unknown'),
            aircraft=coalesce(v_candidate->>'aircraft',''),gate=coalesce(v_candidate->'arrival'->>'gate',''),
            verified_at=(v_result->>'fetchedAt')::timestamptz where id=p_body->>'id';
    end if;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

-- Forwarding a link never grants membership: the invitation stays account-bound.
-- Issuing again rotates the ID so revoked/expired links cannot become valid again.
create or replace function public.wif_trip_invite(p_user_id uuid,p_trip_id text,p_username text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_target uuid; v_invite public.trip_invitations;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
    select id into v_target from public.app_users where username=lower(trim(leading '@' from trim(p_username))) and deleted_at is null;
    if v_target is null then raise exception 'No user has that username.'; end if;
    if exists(select 1 from public.user_blocks where (blocker_id=p_user_id and blocked_id=v_target) or (blocker_id=v_target and blocked_id=p_user_id)) then
        raise exception 'Trip access denied.';
    end if;
    if exists(select 1 from public.trip_members where trip_id=p_trip_id and user_id=v_target) then raise exception 'Already a trip member.'; end if;
    insert into public.trip_invitations(trip_id,invited_user_id,invited_by) values(p_trip_id,v_target,p_user_id)
        on conflict(trip_id,invited_user_id) do update set id=gen_random_uuid(),invited_by=p_user_id,expires_at=now()+interval '7 days',accepted_at=null
        returning * into v_invite;
    return to_jsonb(v_invite);
end;
$$;

create function public.wif_trip_invitation_list(p_user_id uuid,p_trip_id text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
    if not exists(select 1 from public.app_users where id=p_user_id and deleted_at is null) then raise exception 'Trip access denied.'; end if;
    if p_trip_id is not null then perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true); end if;
    return (select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'trip_name',t.name,'trip_id',t.id,
        'destination_airport',t.destination_airport,'start_date',t.start_date,'end_date',t.end_date,
        'inviter_name',u.display_name,'recipient_name',r.display_name,'recipient_id',r.id,'expires_at',i.expires_at)
        order by i.expires_at),'[]'::jsonb)
        from public.trip_invitations i join public.trips t on t.id=i.trip_id
        join public.app_users u on u.id=i.invited_by and u.deleted_at is null
        join public.app_users r on r.id=i.invited_user_id and r.deleted_at is null
        where ((p_trip_id is null and i.invited_user_id=p_user_id) or i.trip_id=p_trip_id)
        and i.accepted_at is null and i.expires_at>now()
        and exists(select 1 from public.trip_members m where m.trip_id=i.trip_id and m.user_id=i.invited_by and m.role='owner')
        and not exists(select 1 from public.user_blocks b where (b.blocker_id=i.invited_by and b.blocked_id=i.invited_user_id)
            or (b.blocker_id=i.invited_user_id and b.blocked_id=i.invited_by)));
end;
$$;

create function public.wif_trip_dismiss_invitation(p_user_id uuid,p_invitation_id uuid,p_revoke boolean default false)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_invite public.trip_invitations;
begin
    select * into v_invite from public.trip_invitations where id=p_invitation_id for update;
    if v_invite.id is null then raise exception 'Trip access denied.'; end if;
    if p_revoke then perform public.wif_trip_assert_access(p_user_id,v_invite.trip_id,true,true);
    elsif v_invite.invited_user_id<>p_user_id then raise exception 'Trip access denied.'; end if;
    if v_invite.accepted_at is not null then raise exception 'Invitation already accepted.'; end if;
    update public.trip_invitations set expires_at=least(expires_at,now()) where id=p_invitation_id;
    return true;
end;
$$;

-- Extend acceptance with block checks without allowing callers to use the old path.
create or replace function public.wif_trip_accept_invitation(p_user_id uuid,p_invitation_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_invite public.trip_invitations; v_name text;
begin
    select display_name into v_name from public.app_users where id=p_user_id and deleted_at is null;
    select * into v_invite from public.trip_invitations where id=p_invitation_id and invited_user_id=p_user_id for update;
    if v_name is null or v_invite.id is null then raise exception 'Trip access denied.'; end if;
    if exists(select 1 from public.user_blocks where (blocker_id=p_user_id and blocked_id=v_invite.invited_by)
        or (blocker_id=v_invite.invited_by and blocked_id=p_user_id)) then raise exception 'Trip access denied.'; end if;
    if v_invite.accepted_at is not null then return public.wif_trip_snapshot(p_user_id,v_invite.trip_id); end if;
    if v_invite.expires_at<=now() then raise exception 'Trip access denied.'; end if;
    perform public.wif_trip_assert_access(v_invite.invited_by,v_invite.trip_id,true,true);
    insert into public.trip_members(trip_id,user_id,role) values(v_invite.trip_id,p_user_id,'member') on conflict do nothing;
    insert into public.participants(trip_id,name,user_id) values(v_invite.trip_id,v_name,p_user_id) on conflict do nothing;
    update public.trip_invitations set accepted_at=now() where id=v_invite.id;
    return public.wif_trip_snapshot(p_user_id,v_invite.trip_id);
end;
$$;

do $$
declare v_function regprocedure; v_role text;
begin
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

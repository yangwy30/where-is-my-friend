-- Additive destination schema. Do not apply the legacy Web SQL or copy its RLS policies.
-- This migration does not import records, assign legacy owners, issue PINs, or switch clients.
begin;

create table public.trips (
    id text primary key check (char_length(id) between 1 and 100),
    name text not null check (char_length(trim(name)) between 1 and 120),
    start_date text not null,
    end_date text not null,
    destination_airport text,
    return_airport text,
    created_at timestamptz default now(),
    completed_at timestamptz,
    source_project_ref text,
    legacy_imported_at timestamptz
);

-- Access belongs to authenticated accounts, not display names or knowledge of an old PIN.
create table public.trip_members (
    trip_id text not null references public.trips(id) on delete cascade,
    user_id uuid not null references public.app_users(id) on delete cascade,
    role text not null check (role in ('owner', 'editor', 'viewer')),
    joined_at timestamptz not null default now(),
    primary key (trip_id, user_id)
);
create index trip_members_user_id_idx on public.trip_members(user_id, trip_id);

-- Guests are itinerary participants, not automatically authenticated members.
create table public.participants (
    id uuid primary key default gen_random_uuid(),
    trip_id text not null references public.trips(id) on delete cascade,
    name text not null check (char_length(trim(name)) between 1 and 120),
    color integer default 0,
    home_airport text,
    destination_airport text,
    joined_at timestamptz default now(),
    user_id uuid references public.app_users(id) on delete set null,
    unique (trip_id, id)
);
create index trip_participants_trip_idx on public.participants(trip_id);
create unique index trip_participants_account_idx on public.participants(trip_id, user_id) where user_id is not null;

create table public.flights (
    id text primary key,
    trip_id text not null references public.trips(id) on delete cascade,
    participant_id uuid,
    flight_number text not null,
    airline text default '',
    departure jsonb default '{}',
    arrival jsonb default '{}',
    date text default '',
    duration text default '',
    status text default 'unverified',
    aircraft text default '',
    gate text default '',
    added_by text default '',
    added_at timestamptz default now(),
    direction text check (direction in ('outbound', 'inbound')),
    foreign key (trip_id, participant_id) references public.participants(trip_id, id)
);
create index trip_flights_trip_idx on public.flights(trip_id);

create table public.notes (
    id text primary key,
    trip_id text not null references public.trips(id) on delete cascade,
    content text not null,
    author text not null,
    created_at timestamptz default now()
);
create index trip_notes_trip_idx on public.notes(trip_id);

create table public.trip_import_batches (
    source_project_ref text not null,
    snapshot_sha256 text not null check (snapshot_sha256 ~ '^[a-f0-9]{64}$'),
    imported_at timestamptz not null default now(),
    counts jsonb not null,
    primary key (source_project_ref, snapshot_sha256)
);

alter table public.trips enable row level security;
alter table public.trip_members enable row level security;
alter table public.participants enable row level security;
alter table public.flights enable row level security;
alter table public.notes enable row level security;
alter table public.trip_import_batches enable row level security;
-- No direct-client policies. All access goes through the authenticated App API.
revoke all on public.trips, public.trip_members, public.participants, public.flights, public.notes, public.trip_import_batches from public;

create function public.wif_trip_assert_access(p_user_id uuid, p_trip_id text, p_write boolean default false, p_manage boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare v_role text;
begin
    select m.role into v_role from public.trip_members m
    join public.app_users u on u.id=m.user_id and u.deleted_at is null
    where m.trip_id=p_trip_id and m.user_id=p_user_id;
    if v_role is null or (p_write and v_role not in ('owner','editor')) or (p_manage and v_role <> 'owner') then
        raise exception 'Trip access denied.';
    end if;
end;
$$;

create function public.wif_trip_snapshot(p_user_id uuid, p_trip_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_result jsonb;
begin
    perform public.wif_trip_assert_access(p_user_id, p_trip_id);
    select (to_jsonb(t) - 'source_project_ref' - 'legacy_imported_at') || jsonb_build_object(
        'participants', (select coalesce(jsonb_agg(to_jsonb(p) order by p.joined_at,p.id),'[]'::jsonb) from public.participants p where p.trip_id=t.id),
        'flights', (select coalesce(jsonb_agg(to_jsonb(f) order by f.added_at,f.id),'[]'::jsonb) from public.flights f where f.trip_id=t.id),
        'notes', (select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at,n.id),'[]'::jsonb) from public.notes n where n.trip_id=t.id),
        'my_role', (select role from public.trip_members where trip_id=t.id and user_id=p_user_id)
    ) into v_result from public.trips t where t.id=p_trip_id;
    return v_result;
end;
$$;

create function public.wif_trip_list(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
    if not exists(select 1 from public.app_users where id=p_user_id and deleted_at is null) then
        raise exception 'Trip access denied.';
    end if;
    return (select coalesce(jsonb_agg(public.wif_trip_snapshot(p_user_id,t.id) order by t.start_date,t.id),'[]'::jsonb)
        from public.trips t join public.trip_members m on m.trip_id=t.id where m.user_id=p_user_id);
end;
$$;

create function public.wif_trip_create(p_user_id uuid, p_trip_id text, p_name text, p_destination text, p_start date, p_end date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
    select display_name into v_name from public.app_users where id=p_user_id and deleted_at is null;
    if v_name is null then raise exception 'Trip access denied.'; end if;
    if p_start is null or p_end is null or p_start > p_end or p_destination is null or p_destination !~ '^[A-Z]{3}$'
       or p_name is null or char_length(trim(p_name)) not between 1 and 120 then
        raise exception 'Invalid trip details.';
    end if;
    insert into public.trips(id,name,destination_airport,start_date,end_date)
        values (p_trip_id,trim(p_name),p_destination,to_char(p_start,'YYYY-MM-DD'),to_char(p_end,'YYYY-MM-DD'))
        on conflict (id) do nothing;
    if found then
        insert into public.trip_members(trip_id,user_id,role) values(p_trip_id,p_user_id,'owner');
        insert into public.participants(trip_id,name,user_id) values(p_trip_id,v_name,p_user_id);
    else
        -- Retry cannot take ownership of an existing trip or overwrite its data.
        perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
    end if;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_update(p_user_id uuid, p_trip_id text, p_name text, p_destination text, p_start date, p_end date)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
    if p_start is null or p_end is null or p_start > p_end or p_destination is null or p_destination !~ '^[A-Z]{3}$'
       or p_name is null or char_length(trim(p_name)) not between 1 and 120 then
        raise exception 'Invalid trip details.';
    end if;
    update public.trips set name=trim(p_name),destination_airport=p_destination,
        start_date=to_char(p_start,'YYYY-MM-DD'),end_date=to_char(p_end,'YYYY-MM-DD') where id=p_trip_id;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_complete(p_user_id uuid, p_trip_id text, p_completed boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true,true);
    if p_completed is null then raise exception 'Invalid completion state.'; end if;
    update public.trips set completed_at=case when p_completed then coalesce(completed_at,now()) else null end where id=p_trip_id;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_add_guest(p_user_id uuid, p_trip_id text, p_participant_id uuid, p_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true);
    if p_name is null or char_length(trim(p_name)) not between 1 and 120 then raise exception 'Invalid participant.'; end if;
    insert into public.participants(id,trip_id,name) values(p_participant_id,p_trip_id,trim(p_name)) on conflict(id) do nothing;
    if not found and not exists(select 1 from public.participants where id=p_participant_id and trip_id=p_trip_id and name=trim(p_name)) then
        raise exception 'Participant conflict.';
    end if;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

create function public.wif_trip_add_flight(p_user_id uuid, p_trip_id text, p_flight_id text, p_participant_id uuid,
    p_flight_number text, p_date date, p_direction text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
    perform public.wif_trip_assert_access(p_user_id,p_trip_id,true);
    select name into v_name from public.participants where id=p_participant_id and trip_id=p_trip_id;
    if v_name is null or p_flight_id is null or char_length(p_flight_id) not between 1 and 100
       or p_date is null or p_direction is null or p_direction not in ('outbound','inbound')
       or p_flight_number is null or upper(trim(p_flight_number)) !~ '^[A-Z0-9]{2,3} ?[0-9]{1,4}[A-Z]?$' then
        raise exception 'Invalid flight details.';
    end if;
    insert into public.flights(id,trip_id,participant_id,flight_number,date,direction,added_by,status)
        values(p_flight_id,p_trip_id,p_participant_id,upper(trim(p_flight_number)),to_char(p_date,'YYYY-MM-DD'),p_direction,v_name,'unverified')
        on conflict(id) do nothing;
    if not found and not exists(select 1 from public.flights where id=p_flight_id and trip_id=p_trip_id
        and participant_id=p_participant_id and flight_number=upper(trim(p_flight_number))
        and date=to_char(p_date,'YYYY-MM-DD') and direction=p_direction) then raise exception 'Flight conflict.'; end if;
    return public.wif_trip_snapshot(p_user_id,p_trip_id);
end;
$$;

-- Supabase supplies these roles; PGlite's existing harness may omit them.
do $$
declare v_function regprocedure; v_role text;
begin
    foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then
            execute format('revoke all on public.trips,public.trip_members,public.participants,public.flights,public.notes,public.trip_import_batches from %I',v_role);
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

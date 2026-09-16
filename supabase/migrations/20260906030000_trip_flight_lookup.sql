begin;
-- Durable quotas apply across Edge instances. Cache contains public provider data, not traveler identities.
create table public.trip_flight_lookup_cache (
    flight_number text not null,
    departure_date date not null,
    result jsonb not null,
    expires_at timestamptz not null,
    primary key (flight_number,departure_date)
);
create table public.trip_flight_lookup_limits (
    bucket text primary key,
    window_start timestamptz not null,
    calls integer not null default 0
);
alter table public.trip_flight_lookup_cache enable row level security;
alter table public.trip_flight_lookup_limits enable row level security;
revoke all on public.trip_flight_lookup_cache,public.trip_flight_lookup_limits from public;

create function public.wif_trip_flight_lookup_begin(p_user_id uuid,p_trip_id text,p_number text,p_date date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb; v_count integer;
begin
    perform public.wif_trip_self_participant(p_user_id,p_trip_id);
    if p_number is null or p_number !~ '^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$' or p_date is null then
        raise exception 'Invalid flight details.';
    end if;
    select result into v_result from trip_flight_lookup_cache where flight_number=p_number and departure_date=p_date and expires_at>now();
    if v_result is not null then return jsonb_build_object('cached',v_result); end if;
    -- Conservative launch guard: at most 50 uncached provider requests/day across the App,
    -- and 10/hour per account. Failed provider calls also consume budget; no retry loop.
    insert into trip_flight_lookup_limits(bucket,window_start,calls) values('global',date_trunc('day',now() at time zone 'UTC') at time zone 'UTC',1)
    on conflict(bucket) do update set calls=case when trip_flight_lookup_limits.window_start=excluded.window_start then trip_flight_lookup_limits.calls+1 else 1 end,
        window_start=excluded.window_start returning calls into v_count;
    if v_count>50 then raise exception 'Flight lookup limit reached.'; end if;
    insert into trip_flight_lookup_limits(bucket,window_start,calls) values(p_user_id::text,date_trunc('hour',now()),1)
    on conflict(bucket) do update set calls=case when trip_flight_lookup_limits.window_start=excluded.window_start then trip_flight_lookup_limits.calls+1 else 1 end,
        window_start=excluded.window_start returning calls into v_count;
    if v_count>10 then raise exception 'Flight lookup limit reached.'; end if;
    return jsonb_build_object('cached',null);
end;
$$;

create function public.wif_trip_flight_lookup_cache(p_number text,p_date date,p_result jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
begin
    if p_result->>'source' is distinct from 'aerodatabox' or p_result->>'flightNumber' is distinct from p_number
       or p_result->>'date' is distinct from to_char(p_date,'YYYY-MM-DD') then raise exception 'Invalid lookup result.'; end if;
    insert into trip_flight_lookup_cache(flight_number,departure_date,result,expires_at) values(p_number,p_date,p_result,now()+interval '5 minutes')
        on conflict(flight_number,departure_date) do update set result=excluded.result,expires_at=excluded.expires_at;
    return true;
end;
$$;
revoke all on function public.wif_trip_flight_lookup_begin(uuid,text,text,date),public.wif_trip_flight_lookup_cache(text,date,jsonb) from public;
do $$
declare v_role text;
begin
    foreach v_role in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=v_role) then
            execute format('revoke all on public.trip_flight_lookup_cache,public.trip_flight_lookup_limits from %I',v_role);
            execute format('revoke all on function public.wif_trip_flight_lookup_begin(uuid,text,text,date),public.wif_trip_flight_lookup_cache(text,date,jsonb) from %I',v_role);
        end if;
    end loop;
    if exists(select 1 from pg_roles where rolname='service_role') then
        grant execute on function public.wif_trip_flight_lookup_begin(uuid,text,text,date),public.wif_trip_flight_lookup_cache(text,date,jsonb) to service_role;
    end if;
end;
$$;
commit;

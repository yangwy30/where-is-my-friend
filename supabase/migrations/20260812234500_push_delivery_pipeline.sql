-- Secure APNs device registration and durable, concurrency-safe delivery.
-- Device tokens are encrypted by the Edge API before they reach Postgres.

alter table public.devices
    drop constraint if exists devices_apns_token_hash_key;

alter table public.devices
    add column if not exists installation_id uuid,
    add column if not exists platform text,
    add column if not exists bundle_id text,
    add column if not exists url_scheme text,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists disabled_reason text,
    add column if not exists last_error text;

update public.devices
set installation_id = coalesce(installation_id, id),
    platform = coalesce(platform, 'ios'),
    bundle_id = coalesce(
        bundle_id,
        case environment
            when 'sandbox' then 'com.yangwy30.whereismyfriend.staging'
            else 'com.yangwy30.whereismyfriend'
        end
    ),
    url_scheme = coalesce(
        url_scheme,
        case environment
            when 'sandbox' then 'whereismyfriend-staging'
            else 'whereismyfriend'
        end
    );

alter table public.devices
    alter column installation_id set not null,
    alter column platform set not null,
    alter column bundle_id set not null,
    alter column url_scheme set not null,
    add constraint devices_token_hash_format_check
        check (apns_token_hash ~ '^[0-9a-f]{64}$'),
    add constraint devices_encrypted_token_envelope_check
        check (encrypted_apns_token ~ '^v1:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$'),
    add constraint devices_platform_check
        check (platform = 'ios'),
    add constraint devices_bundle_id_check
        check (bundle_id ~ '^[A-Za-z0-9][A-Za-z0-9.-]{2,254}$'),
    add constraint devices_url_scheme_check
        check (url_scheme ~ '^[a-z][a-z0-9+.-]{1,63}$');

create unique index devices_installation_topic_idx
    on public.devices(installation_id, environment, bundle_id);
create unique index devices_token_topic_idx
    on public.devices(apns_token_hash, environment, bundle_id);
create index devices_active_user_idx
    on public.devices(user_id, last_seen_at desc)
    where disabled_at is null;

create table public.notification_deliveries (
    id uuid primary key default gen_random_uuid(),
    outbox_id uuid not null references public.notification_outbox(id) on delete cascade,
    device_id uuid not null references public.devices(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'delivered', 'failed')),
    attempts integer not null default 0 check (attempts >= 0),
    available_at timestamptz not null default now(),
    claimed_at timestamptz,
    claim_token uuid,
    completed_at timestamptz,
    delivered_at timestamptz,
    last_error text,
    apns_id uuid,
    created_at timestamptz not null default now(),
    unique (outbox_id, device_id),
    check ((claimed_at is null) = (claim_token is null)),
    check (delivered_at is null or status = 'delivered'),
    check (completed_at is null or status <> 'pending')
);

create index notification_deliveries_claim_idx
    on public.notification_deliveries(available_at, created_at)
    where status = 'pending';

alter table public.notification_deliveries enable row level security;

create or replace function public.wif_register_push_device(
    p_user_id uuid,
    p_installation_id uuid,
    p_token_hash text,
    p_encrypted_token text,
    p_environment text,
    p_bundle_id text,
    p_url_scheme text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_device_id uuid;
begin
    if not exists (
        select 1 from public.app_users where id = p_user_id and deleted_at is null
    ) then
        raise exception 'The account is unavailable.';
    end if;
    if p_token_hash !~ '^[0-9a-f]{64}$' then raise exception 'Invalid APNs token hash.'; end if;
    if p_encrypted_token !~ '^v1:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$' then
        raise exception 'Invalid encrypted APNs token.';
    end if;
    if p_environment not in ('sandbox', 'production') then raise exception 'Invalid APNs environment.'; end if;
    if p_bundle_id !~ '^[A-Za-z0-9][A-Za-z0-9.-]{2,254}$' then raise exception 'Invalid APNs topic.'; end if;
    if p_url_scheme !~ '^[a-z][a-z0-9+.-]{1,63}$' then raise exception 'Invalid URL scheme.'; end if;

    -- A single app installation belongs to the currently authenticated user.
    -- Removing an earlier owner prevents post-logout notifications leaking to it.
    delete from public.devices
    where environment = p_environment
      and bundle_id = p_bundle_id
      and (
          (installation_id = p_installation_id and user_id <> p_user_id)
          or (apns_token_hash = p_token_hash and installation_id <> p_installation_id)
      );

    insert into public.devices(
        user_id, installation_id, apns_token_hash, encrypted_apns_token,
        environment, platform, bundle_id, url_scheme,
        created_at, last_seen_at, disabled_at, disabled_reason, last_error
    ) values (
        p_user_id, p_installation_id, p_token_hash, p_encrypted_token,
        p_environment, 'ios', p_bundle_id, p_url_scheme,
        now(), now(), null, null, null
    )
    on conflict (installation_id, environment, bundle_id) do update
      set user_id = excluded.user_id,
          apns_token_hash = excluded.apns_token_hash,
          encrypted_apns_token = excluded.encrypted_apns_token,
          platform = excluded.platform,
          url_scheme = excluded.url_scheme,
          last_seen_at = now(),
          disabled_at = null,
          disabled_reason = null,
          last_error = null
    returning id into v_device_id;

    return v_device_id;
end;
$$;

create or replace function public.wif_disable_push_device(
    p_user_id uuid,
    p_installation_id uuid,
    p_environment text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.devices
       set disabled_at = now(),
           disabled_reason = 'signed_out'
     where user_id = p_user_id
       and installation_id = p_installation_id
       and environment = p_environment
       and disabled_at is null;
    return found;
end;
$$;

create or replace function public.wif_claim_notification_deliveries(
    p_limit integer,
    p_claim_token uuid
)
returns table (
    delivery_id uuid,
    device_id uuid,
    encrypted_apns_token text,
    environment text,
    bundle_id text,
    event_id uuid,
    title text,
    body text,
    deep_link text
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
    -- A token may be disabled after its delivery row was expanded. Retire those
    -- rows so they cannot leave an outbox permanently pending.
    update public.notification_deliveries nd
       set status = 'failed',
           completed_at = now(),
           claimed_at = null,
           claim_token = null,
           last_error = 'Device registration disabled before delivery.'
      from public.devices d
     where d.id = nd.device_id
       and d.disabled_at is not null
       and nd.status = 'pending';

    update public.notification_outbox o
       set delivered_at = now(),
           attempts = (
               select coalesce(sum(nd.attempts), 0)::integer
               from public.notification_deliveries nd where nd.outbox_id = o.id
           ),
           last_error = case when exists (
               select 1 from public.notification_deliveries nd
               where nd.outbox_id = o.id and nd.status = 'failed'
           ) then 'One or more device deliveries failed permanently.' else null end
     where o.delivered_at is null
       and exists (
           select 1 from public.notification_deliveries nd where nd.outbox_id = o.id
       )
       and not exists (
           select 1 from public.notification_deliveries nd
           where nd.outbox_id = o.id and nd.status = 'pending'
       );

    update public.colocation_events e
       set delivered_at = now()
      from public.notification_outbox o
     where o.event_id = e.id
       and o.delivered_at is not null
       and e.delivered_at is null
       and exists (
           select 1 from public.notification_deliveries nd
           where nd.outbox_id = o.id and nd.status = 'delivered'
       );

    -- Expand each recipient event into one durable row per active app install.
    insert into public.notification_deliveries(outbox_id, device_id)
    select o.id, d.id
    from public.notification_outbox o
    join public.colocation_events e on e.id = o.event_id
    join public.devices d
      on d.user_id = e.recipient_id
     and d.disabled_at is null
     and d.last_seen_at >= now() - interval '90 days'
    where o.delivered_at is null
    on conflict (outbox_id, device_id) do nothing;

    return query
    with candidates as (
        select nd.id
        from public.notification_deliveries nd
        where nd.status = 'pending'
          and nd.available_at <= now()
          and (nd.claimed_at is null or nd.claimed_at < now() - interval '5 minutes')
        order by nd.available_at, nd.created_at
        for update skip locked
        limit greatest(1, least(coalesce(p_limit, 20), 100))
    ), claimed as (
        update public.notification_deliveries nd
           set claimed_at = now(),
               claim_token = p_claim_token,
               attempts = nd.attempts + 1
          from candidates c
         where nd.id = c.id
        returning nd.*
    )
    select
        c.id,
        d.id,
        d.encrypted_apns_token,
        d.environment,
        d.bundle_id,
        e.id,
        case when s.notification_preview_enabled
            then 'You are both in ' || e.city_name
            else 'A friend is nearby'
        end,
        case when s.notification_preview_enabled
            then e.friend_name || ' is now in ' || e.city_name || ', too.'
            else 'Open Across Us to see the update.'
        end,
        d.url_scheme || '://events/' || e.id::text
    from claimed c
    join public.devices d on d.id = c.device_id and d.disabled_at is null
    join public.notification_outbox o on o.id = c.outbox_id and o.delivered_at is null
    join public.colocation_events e on e.id = o.event_id
    join public.user_sharing_settings s on s.user_id = e.recipient_id;
end;
$$;

create or replace function public.wif_complete_notification_delivery(
    p_delivery_id uuid,
    p_claim_token uuid,
    p_outcome text,
    p_error text default null,
    p_apns_id uuid default null,
    p_retry_after_seconds integer default null,
    p_disable_device boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    v_outbox_id uuid;
    v_device_id uuid;
    v_retry_seconds integer;
begin
    if p_outcome not in ('delivered', 'retry', 'failed') then
        raise exception 'Invalid delivery outcome.';
    end if;

    select outbox_id, device_id
      into v_outbox_id, v_device_id
    from public.notification_deliveries
    where id = p_delivery_id
      and status = 'pending'
      and claim_token = p_claim_token
    for update;

    if v_outbox_id is null then return false; end if;

    if p_disable_device then
        update public.devices
           set disabled_at = now(),
               disabled_reason = left(coalesce(p_error, 'apns_permanent_error'), 160),
               last_error = left(p_error, 500)
         where id = v_device_id;
    end if;

    if p_outcome = 'retry' then
        v_retry_seconds := greatest(30, least(coalesce(p_retry_after_seconds, 300), 86400));
        update public.notification_deliveries
           set available_at = now() + make_interval(secs => v_retry_seconds),
               claimed_at = null,
               claim_token = null,
               last_error = left(p_error, 500),
               apns_id = p_apns_id
         where id = p_delivery_id;
        update public.notification_outbox
           set attempts = attempts + 1,
               available_at = now() + make_interval(secs => v_retry_seconds),
               last_error = left(p_error, 500)
         where id = v_outbox_id;
        return true;
    end if;

    update public.notification_deliveries
       set status = p_outcome,
           completed_at = now(),
           delivered_at = case when p_outcome = 'delivered' then now() else null end,
           claimed_at = null,
           claim_token = null,
           last_error = left(p_error, 500),
           apns_id = p_apns_id
     where id = p_delivery_id;

    if not exists (
        select 1 from public.notification_deliveries
        where outbox_id = v_outbox_id and status = 'pending'
    ) then
        update public.notification_outbox
           set delivered_at = now(),
               attempts = (
                   select coalesce(sum(attempts), 0)::integer
                   from public.notification_deliveries where outbox_id = v_outbox_id
               ),
               last_error = case when exists (
                   select 1 from public.notification_deliveries
                   where outbox_id = v_outbox_id and status = 'failed'
               ) then 'One or more device deliveries failed permanently.' else null end
         where id = v_outbox_id;

        update public.colocation_events
           set delivered_at = now()
         where id = (select event_id from public.notification_outbox where id = v_outbox_id)
           and exists (
               select 1 from public.notification_deliveries
               where outbox_id = v_outbox_id and status = 'delivered'
           );
    end if;

    return true;
end;
$$;

-- SECURITY DEFINER functions must never retain PostgreSQL's default PUBLIC
-- execute grant. Only the Edge Functions' service-role connection may call
-- any business RPC; clients always go through the JWT-authorized API.
do $$
declare
    v_function record;
begin
    for v_function in
        select p.oid::regprocedure as signature
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname like 'wif_%'
    loop
        execute format('revoke all on function %s from public', v_function.signature);
        if exists (select 1 from pg_roles where rolname = 'anon') then
            execute format('revoke all on function %s from anon', v_function.signature);
        end if;
        if exists (select 1 from pg_roles where rolname = 'authenticated') then
            execute format('revoke all on function %s from authenticated', v_function.signature);
        end if;
        if exists (select 1 from pg_roles where rolname = 'service_role') then
            execute format('grant execute on function %s to service_role', v_function.signature);
        end if;
    end loop;
end;
$$;

do $$
begin
    if exists (select 1 from pg_roles where rolname = 'anon') then
        execute 'revoke all on public.notification_deliveries from anon';
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
        execute 'revoke all on public.notification_deliveries from authenticated';
    end if;
    if exists (select 1 from pg_roles where rolname = 'service_role') then
        execute 'grant select, insert, update, delete on public.notification_deliveries to service_role';
    end if;
end;
$$;

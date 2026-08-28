-- Across Us: first production-shaped backend schema.
-- The public schema is never exposed directly to the iOS client. The Edge API
-- uses the service role and every request is authorized from a hashed session.

create table public.app_users (
    id uuid primary key default gen_random_uuid(),
    apple_subject text unique,
    username text not null unique,
    display_name text not null,
    avatar_palette smallint not null default 1 check (avatar_palette between 0 and 6),
    is_debug boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    check (username = lower(username)),
    check (username ~ '^[a-z0-9_]{3,20}$'),
    check (char_length(display_name) between 1 and 40),
    check (apple_subject is not null or is_debug)
);

create table public.app_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.app_users(id) on delete cascade,
    token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    expires_at timestamptz not null,
    revoked_at timestamptz
);

create table public.friendships (
    id uuid primary key default gen_random_uuid(),
    requester_id uuid not null references public.app_users(id) on delete cascade,
    addressee_id uuid not null references public.app_users(id) on delete cascade,
    pair_low_id uuid generated always as (least(requester_id, addressee_id)) stored,
    pair_high_id uuid generated always as (greatest(requester_id, addressee_id)) stored,
    status text not null check (status in ('pending', 'accepted', 'declined')),
    created_at timestamptz not null default now(),
    responded_at timestamptz,
    accepted_at timestamptz,
    unique (pair_low_id, pair_high_id),
    check (requester_id <> addressee_id)
);

create table public.user_blocks (
    blocker_id uuid not null references public.app_users(id) on delete cascade,
    blocked_id uuid not null references public.app_users(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    check (blocker_id <> blocked_id)
);

create table public.sharing_preferences (
    owner_id uuid not null references public.app_users(id) on delete cascade,
    friend_id uuid not null references public.app_users(id) on delete cascade,
    shares_city boolean not null default true,
    same_city_alert boolean not null default true,
    is_favorite boolean not null default false,
    updated_at timestamptz not null default now(),
    primary key (owner_id, friend_id),
    check (owner_id <> friend_id)
);

create table public.user_sharing_settings (
    user_id uuid primary key references public.app_users(id) on delete cascade,
    city_sharing_enabled boolean not null default true,
    background_updates_enabled boolean not null default false,
    notification_preview_enabled boolean not null default true,
    updated_at timestamptz not null default now()
);

create table public.current_presence (
    user_id uuid primary key references public.app_users(id) on delete cascade,
    normalized_city_id text,
    city_name text,
    country_code text,
    source text not null check (source in ('manual', 'foregroundLocation', 'significantChange', 'visit')),
    client_updated_at timestamptz not null,
    server_updated_at timestamptz not null default now(),
    sharing_state text not null default 'active' check (sharing_state in ('active', 'paused', 'unavailable')),
    check (country_code is null or country_code ~ '^[A-Z]{2}$'),
    check (city_name is null or char_length(city_name) between 1 and 120)
);

create table public.devices (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.app_users(id) on delete cascade,
    apns_token_hash text not null unique,
    encrypted_apns_token text not null,
    environment text not null check (environment in ('sandbox', 'production')),
    last_seen_at timestamptz not null default now(),
    disabled_at timestamptz
);

create table public.colocation_sessions (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.app_users(id) on delete cascade,
    friend_id uuid not null references public.app_users(id) on delete cascade,
    normalized_city_id text not null,
    city_name text not null,
    entered_at timestamptz not null default now(),
    left_at timestamptz,
    check (recipient_id <> friend_id)
);

create unique index colocation_sessions_active_idx
    on public.colocation_sessions(recipient_id, friend_id, normalized_city_id)
    where left_at is null;

create table public.colocation_events (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.app_users(id) on delete cascade,
    friend_id uuid not null references public.app_users(id) on delete cascade,
    session_id uuid not null references public.colocation_sessions(id) on delete cascade,
    normalized_city_id text not null,
    city_name text not null,
    friend_name text not null,
    deduplication_key text not null unique,
    created_at timestamptz not null default now(),
    delivered_at timestamptz
);

create table public.notification_outbox (
    id uuid primary key default gen_random_uuid(),
    event_id uuid not null unique references public.colocation_events(id) on delete cascade,
    attempts integer not null default 0,
    available_at timestamptz not null default now(),
    delivered_at timestamptz,
    last_error text
);

create table public.deletion_requests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null,
    requested_at timestamptz not null default now(),
    completed_at timestamptz,
    apple_token_revoked_at timestamptz
);

create index app_sessions_active_idx on public.app_sessions(token_hash, expires_at) where revoked_at is null;
create index friendships_requester_status_idx on public.friendships(requester_id, status);
create index friendships_addressee_status_idx on public.friendships(addressee_id, status);
create index current_presence_city_idx on public.current_presence(normalized_city_id, client_updated_at desc);
create index user_blocks_blocked_idx on public.user_blocks(blocked_id);
create index colocation_sessions_recent_exit_idx
    on public.colocation_sessions(recipient_id, friend_id, normalized_city_id, left_at desc);
create index colocation_events_recipient_idx on public.colocation_events(recipient_id, created_at desc);
create index notification_outbox_pending_idx
    on public.notification_outbox(available_at) where delivered_at is null;

create or replace function public.wif_city_key(p_city text, p_country_code text)
returns text
language sql
immutable
strict
as $$
    select upper(trim(p_country_code)) || ':' ||
           regexp_replace(lower(trim(p_city)), '[^[:alnum:]]+', '', 'g')
$$;

create or replace function public.wif_are_friends(p_user_id uuid, p_friend_id uuid)
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from public.friendships f
        where f.status = 'accepted'
          and f.pair_low_id = least(p_user_id, p_friend_id)
          and f.pair_high_id = greatest(p_user_id, p_friend_id)
    )
$$;

create or replace function public.wif_snapshot(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with viewer as (
    select u.*
    from public.app_users u
    where u.id = p_user_id and u.deleted_at is null
),
settings as (
    select s.*
    from public.user_sharing_settings s
    where s.user_id = p_user_id
),
viewer_presence as (
    select p.*
    from public.current_presence p
    where p.user_id = p_user_id
),
friend_ids as (
    select case when f.requester_id = p_user_id then f.addressee_id else f.requester_id end as friend_id
    from public.friendships f
    where f.status = 'accepted'
      and (f.requester_id = p_user_id or f.addressee_id = p_user_id)
),
friends_json as (
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'id', u.id,
            'displayName', u.display_name,
            'username', u.username,
            'city', case
                when coalesce(other_settings.city_sharing_enabled, true)
                 and coalesce(other_pref.shares_city, true)
                 and cp.sharing_state = 'active' then cp.city_name
                else null
            end,
            'countryCode', case
                when coalesce(other_settings.city_sharing_enabled, true)
                 and coalesce(other_pref.shares_city, true)
                 and cp.sharing_state = 'active' then cp.country_code
                else null
            end,
            'updatedAt', case
                when coalesce(other_settings.city_sharing_enabled, true)
                 and coalesce(other_pref.shares_city, true)
                 and cp.sharing_state = 'active' then cp.client_updated_at
                else null
            end,
            'sharingState', case
                when not coalesce(other_settings.city_sharing_enabled, true)
                  or not coalesce(other_pref.shares_city, true)
                  or cp.sharing_state = 'paused' then 'paused'
                when cp.user_id is null or cp.sharing_state = 'unavailable' then 'unavailable'
                else 'active'
            end,
            'avatarPalette', u.avatar_palette,
            'isFavorite', coalesce(viewer_pref.is_favorite, false)
        ) order by coalesce(viewer_pref.is_favorite, false) desc, u.display_name
    ), '[]'::jsonb) as value
    from friend_ids fi
    join public.app_users u on u.id = fi.friend_id and u.deleted_at is null
    left join public.current_presence cp on cp.user_id = fi.friend_id
    left join public.user_sharing_settings other_settings on other_settings.user_id = fi.friend_id
    left join public.sharing_preferences other_pref
        on other_pref.owner_id = fi.friend_id and other_pref.friend_id = p_user_id
    left join public.sharing_preferences viewer_pref
        on viewer_pref.owner_id = p_user_id and viewer_pref.friend_id = fi.friend_id
),
requests_json as (
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'id', f.id,
            'userID', other_user.id,
            'displayName', other_user.display_name,
            'username', other_user.username,
            'direction', case when f.addressee_id = p_user_id then 'incoming' else 'outgoing' end,
            'createdAt', f.created_at,
            'avatarPalette', other_user.avatar_palette
        ) order by f.created_at desc
    ), '[]'::jsonb) as value
    from public.friendships f
    join public.app_users other_user on other_user.id = case
        when f.requester_id = p_user_id then f.addressee_id else f.requester_id end
    where f.status = 'pending'
      and (f.requester_id = p_user_id or f.addressee_id = p_user_id)
),
preferences_json as (
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'friendID', fi.friend_id,
            'sharesMyCity', coalesce(sp.shares_city, true),
            'sameCityAlertEnabled', coalesce(sp.same_city_alert, true)
        ) order by fi.friend_id
    ), '[]'::jsonb) as value
    from friend_ids fi
    left join public.sharing_preferences sp
      on sp.owner_id = p_user_id and sp.friend_id = fi.friend_id
),
events_json as (
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'deduplicationKey', e.deduplication_key,
            'city', e.city_name,
            'friendIDs', jsonb_build_array(e.friend_id),
            'friendNames', jsonb_build_array(e.friend_name),
            'createdAt', e.created_at,
            'wasNotified', e.delivered_at is not null
        ) order by e.created_at desc
    ), '[]'::jsonb) as value
    from (
        select * from public.colocation_events
        where recipient_id = p_user_id
        order by created_at desc
        limit 50
    ) e
),
sessions_json as (
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'friendID', s.friend_id,
            'cityKey', s.normalized_city_id,
            'enteredAt', s.entered_at,
            'leftAt', s.left_at
        ) order by s.entered_at desc
    ), '[]'::jsonb) as value
    from (
        select * from public.colocation_sessions
        where recipient_id = p_user_id
        order by entered_at desc
        limit 100
    ) s
),
blocked_json as (
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'id', u.id,
            'displayName', u.display_name,
            'username', u.username,
            'avatarPalette', u.avatar_palette,
            'blockedAt', b.created_at
        ) order by b.created_at desc
    ), '[]'::jsonb) as value
    from public.user_blocks b
    join public.app_users u on u.id = b.blocked_id
    where b.blocker_id = p_user_id
)
select jsonb_build_object(
    'schemaVersion', 2,
    'isAuthenticated', true,
    'currentUser', jsonb_build_object(
        'id', v.id,
        'displayName', v.display_name,
        'username', v.username,
        'appleUserID', v.apple_subject,
        'avatarPalette', v.avatar_palette
    ),
    'currentPresence', jsonb_build_object(
        'city', vp.city_name,
        'countryCode', vp.country_code,
        'updatedAt', vp.client_updated_at,
        'source', coalesce(vp.source, 'manual')
    ),
    'sharingPreferences', jsonb_build_object(
        'citySharingEnabled', coalesce(st.city_sharing_enabled, true),
        'backgroundUpdatesEnabled', coalesce(st.background_updates_enabled, false),
        'notificationPreviewEnabled', coalesce(st.notification_preview_enabled, true)
    ),
    'friends', fj.value,
    'friendRequests', rj.value,
    'friendPreferences', pj.value,
    'colocationEvents', ej.value,
    'colocationSessions', sj.value,
    'blockedPeople', bj.value,
    'lastSyncedAt', now(),
    'syncState', 'synced'
)
from viewer v
left join settings st on true
left join viewer_presence vp on true
cross join friends_json fj
cross join requests_json rj
cross join preferences_json pj
cross join events_json ej
cross join sessions_json sj
cross join blocked_json bj
$$;

create or replace function public.wif_evaluate_direction(p_recipient_id uuid, p_friend_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_city_id text;
    v_city_name text;
    v_session_id uuid;
    v_friend_name text;
    v_alert_enabled boolean;
    v_last_exit timestamptz;
begin
    select rp.normalized_city_id, rp.city_name, fu.display_name,
           coalesce(recipient_pref.same_city_alert, true)
      into v_city_id, v_city_name, v_friend_name, v_alert_enabled
    from public.current_presence rp
    join public.current_presence fp on fp.user_id = p_friend_id
    join public.app_users fu on fu.id = p_friend_id and fu.deleted_at is null
    join public.user_sharing_settings rs on rs.user_id = p_recipient_id
    join public.user_sharing_settings fs on fs.user_id = p_friend_id
    left join public.sharing_preferences recipient_pref
      on recipient_pref.owner_id = p_recipient_id and recipient_pref.friend_id = p_friend_id
    left join public.sharing_preferences friend_pref
      on friend_pref.owner_id = p_friend_id and friend_pref.friend_id = p_recipient_id
    where rp.user_id = p_recipient_id
      and public.wif_are_friends(p_recipient_id, p_friend_id)
      and not exists (
          select 1 from public.user_blocks b
          where (b.blocker_id = p_recipient_id and b.blocked_id = p_friend_id)
             or (b.blocker_id = p_friend_id and b.blocked_id = p_recipient_id)
      )
      and rs.city_sharing_enabled
      and fs.city_sharing_enabled
      and coalesce(recipient_pref.shares_city, true)
      and coalesce(friend_pref.shares_city, true)
      and rp.sharing_state = 'active'
      and fp.sharing_state = 'active'
      and rp.client_updated_at >= now() - interval '2 hours'
      and fp.client_updated_at >= now() - interval '2 hours'
      and rp.normalized_city_id is not null
      and rp.normalized_city_id = fp.normalized_city_id;

    if v_city_id is null then
        update public.colocation_sessions
           set left_at = now()
         where recipient_id = p_recipient_id
           and friend_id = p_friend_id
           and left_at is null;
        return;
    end if;

    update public.colocation_sessions
       set left_at = now()
     where recipient_id = p_recipient_id
       and friend_id = p_friend_id
       and normalized_city_id <> v_city_id
       and left_at is null;

    if exists (
        select 1 from public.colocation_sessions
        where recipient_id = p_recipient_id
          and friend_id = p_friend_id
          and normalized_city_id = v_city_id
          and left_at is null
    ) then
        return;
    end if;

    select max(left_at) into v_last_exit
    from public.colocation_sessions
    where recipient_id = p_recipient_id
      and friend_id = p_friend_id
      and normalized_city_id = v_city_id;

    if v_last_exit is not null and v_last_exit > now() - interval '6 hours' then
        return;
    end if;

    insert into public.colocation_sessions(recipient_id, friend_id, normalized_city_id, city_name)
    values (p_recipient_id, p_friend_id, v_city_id, v_city_name)
    returning id into v_session_id;

    if v_alert_enabled then
        with new_event as (
            insert into public.colocation_events(
                recipient_id, friend_id, session_id, normalized_city_id,
                city_name, friend_name, deduplication_key
            ) values (
                p_recipient_id,
                p_friend_id,
                v_session_id,
                v_city_id,
                v_city_name,
                v_friend_name,
                concat_ws(':', p_recipient_id, least(p_recipient_id, p_friend_id),
                    greatest(p_recipient_id, p_friend_id), v_city_id, v_session_id)
            )
            returning id
        )
        insert into public.notification_outbox(event_id)
        select id from new_event;
    end if;
end;
$$;

create or replace function public.wif_evaluate_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_friend_id uuid;
begin
    for v_friend_id in
        select case when requester_id = p_user_id then addressee_id else requester_id end
        from public.friendships
        where status = 'accepted'
          and (requester_id = p_user_id or addressee_id = p_user_id)
    loop
        perform public.wif_evaluate_direction(p_user_id, v_friend_id);
        perform public.wif_evaluate_direction(v_friend_id, p_user_id);
    end loop;
end;
$$;

create or replace function public.wif_send_friend_request(p_user_id uuid, p_username text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_target_id uuid;
    v_existing_status text;
begin
    select id into v_target_id
    from public.app_users
    where username = lower(trim(leading '@' from trim(p_username))) and deleted_at is null;

    if v_target_id is null then raise exception 'No user has that username.'; end if;
    if v_target_id = p_user_id then raise exception 'You cannot invite yourself.'; end if;
    if exists (
        select 1 from public.user_blocks
        where (blocker_id = p_user_id and blocked_id = v_target_id)
           or (blocker_id = v_target_id and blocked_id = p_user_id)
    ) then raise exception 'That user is unavailable.'; end if;

    select status into v_existing_status
    from public.friendships
    where pair_low_id = least(p_user_id, v_target_id)
      and pair_high_id = greatest(p_user_id, v_target_id);

    if v_existing_status = 'accepted' then raise exception 'You are already friends.'; end if;
    if v_existing_status = 'pending' then raise exception 'An invitation already exists.'; end if;

    insert into public.friendships(requester_id, addressee_id, status)
    values (p_user_id, v_target_id, 'pending')
    on conflict (pair_low_id, pair_high_id) do update
      set requester_id = excluded.requester_id,
          addressee_id = excluded.addressee_id,
          status = 'pending',
          created_at = now(),
          responded_at = null,
          accepted_at = null;

    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_respond_friend_request(
    p_user_id uuid,
    p_request_id uuid,
    p_response text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_requester_id uuid;
begin
    if p_response not in ('accept', 'decline') then raise exception 'Invalid response.'; end if;

    select requester_id into v_requester_id
    from public.friendships
    where id = p_request_id and addressee_id = p_user_id and status = 'pending'
    for update;

    if v_requester_id is null then raise exception 'That friend request no longer exists.'; end if;

    update public.friendships
       set status = case when p_response = 'accept' then 'accepted' else 'declined' end,
           responded_at = now(),
           accepted_at = case when p_response = 'accept' then now() else null end
     where id = p_request_id;

    if p_response = 'accept' then
        insert into public.sharing_preferences(owner_id, friend_id)
        values (p_user_id, v_requester_id), (v_requester_id, p_user_id)
        on conflict do nothing;
        perform public.wif_evaluate_direction(p_user_id, v_requester_id);
        perform public.wif_evaluate_direction(v_requester_id, p_user_id);
    end if;

    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_remove_friend(p_user_id uuid, p_friend_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.wif_are_friends(p_user_id, p_friend_id) then
        raise exception 'That friend is no longer available.';
    end if;
    delete from public.friendships
    where pair_low_id = least(p_user_id, p_friend_id)
      and pair_high_id = greatest(p_user_id, p_friend_id);
    delete from public.sharing_preferences
    where (owner_id = p_user_id and friend_id = p_friend_id)
       or (owner_id = p_friend_id and friend_id = p_user_id);
    update public.colocation_sessions set left_at = now()
    where ((recipient_id = p_user_id and friend_id = p_friend_id)
        or (recipient_id = p_friend_id and friend_id = p_user_id))
      and left_at is null;
    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_block_user(p_user_id uuid, p_blocked_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_user_id = p_blocked_id then raise exception 'You cannot block yourself.'; end if;
    if not exists (select 1 from public.app_users where id = p_blocked_id and deleted_at is null) then
        raise exception 'That user is unavailable.';
    end if;
    insert into public.user_blocks(blocker_id, blocked_id)
    values (p_user_id, p_blocked_id)
    on conflict do nothing;
    delete from public.friendships
    where pair_low_id = least(p_user_id, p_blocked_id)
      and pair_high_id = greatest(p_user_id, p_blocked_id);
    delete from public.sharing_preferences
    where (owner_id = p_user_id and friend_id = p_blocked_id)
       or (owner_id = p_blocked_id and friend_id = p_user_id);
    update public.colocation_sessions set left_at = now()
    where ((recipient_id = p_user_id and friend_id = p_blocked_id)
        or (recipient_id = p_blocked_id and friend_id = p_user_id))
      and left_at is null;
    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_unblock_user(p_user_id uuid, p_blocked_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.user_blocks where blocker_id = p_user_id and blocked_id = p_blocked_id;
    if not found then raise exception 'That blocked person is no longer available.'; end if;
    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_update_profile(
    p_user_id uuid,
    p_display_name text,
    p_username text,
    p_avatar_palette integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_username text := lower(trim(leading '@' from trim(p_username)));
    v_display_name text := trim(p_display_name);
begin
    if char_length(v_display_name) not between 1 and 40 then
        raise exception 'Display name must contain 1–40 characters.';
    end if;
    if v_username !~ '^[a-z0-9_]{3,20}$' then
        raise exception 'Username must contain 3–20 lowercase letters, numbers, or underscores.';
    end if;
    if p_avatar_palette not between 0 and 6 then raise exception 'Invalid avatar.'; end if;
    update public.app_users
       set display_name = v_display_name,
           username = v_username,
           avatar_palette = p_avatar_palette,
           updated_at = now()
     where id = p_user_id and deleted_at is null;
    return public.wif_snapshot(p_user_id);
exception when unique_violation then
    raise exception 'That username is already taken.';
end;
$$;

create or replace function public.wif_set_favorite(p_user_id uuid, p_friend_id uuid, p_is_favorite boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.wif_are_friends(p_user_id, p_friend_id) then
        raise exception 'That friend is no longer available.';
    end if;
    insert into public.sharing_preferences(owner_id, friend_id, is_favorite)
    values (p_user_id, p_friend_id, p_is_favorite)
    on conflict (owner_id, friend_id) do update
      set is_favorite = excluded.is_favorite, updated_at = now();
    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_set_friend_preference(
    p_user_id uuid,
    p_friend_id uuid,
    p_shares_city boolean,
    p_same_city_alert boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.wif_are_friends(p_user_id, p_friend_id) then
        raise exception 'That friend is no longer available.';
    end if;
    insert into public.sharing_preferences(owner_id, friend_id, shares_city, same_city_alert)
    values (p_user_id, p_friend_id, p_shares_city, p_same_city_alert)
    on conflict (owner_id, friend_id) do update
      set shares_city = excluded.shares_city,
          same_city_alert = excluded.same_city_alert,
          updated_at = now();
    perform public.wif_evaluate_direction(p_user_id, p_friend_id);
    perform public.wif_evaluate_direction(p_friend_id, p_user_id);
    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_set_sharing_preferences(
    p_user_id uuid,
    p_city_sharing_enabled boolean,
    p_background_updates_enabled boolean,
    p_notification_preview_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.user_sharing_settings(
        user_id, city_sharing_enabled, background_updates_enabled, notification_preview_enabled
    ) values (
        p_user_id, p_city_sharing_enabled, p_background_updates_enabled, p_notification_preview_enabled
    )
    on conflict (user_id) do update
      set city_sharing_enabled = excluded.city_sharing_enabled,
          background_updates_enabled = excluded.background_updates_enabled,
          notification_preview_enabled = excluded.notification_preview_enabled,
          updated_at = now();
    perform public.wif_evaluate_user(p_user_id);
    return public.wif_snapshot(p_user_id);
end;
$$;

create or replace function public.wif_update_presence(
    p_user_id uuid,
    p_city text,
    p_country_code text,
    p_source text,
    p_client_updated_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_city text := trim(p_city);
    v_country text := upper(trim(p_country_code));
begin
    if char_length(v_city) not between 1 and 120 then raise exception 'Invalid city.'; end if;
    if v_country !~ '^[A-Z]{2}$' then raise exception 'Invalid country code.'; end if;
    if p_source not in ('manual', 'foregroundLocation', 'significantChange', 'visit') then
        raise exception 'Invalid presence source.';
    end if;
    if p_client_updated_at > now() + interval '5 minutes' then raise exception 'Invalid update time.'; end if;

    insert into public.current_presence(
        user_id, normalized_city_id, city_name, country_code, source,
        client_updated_at, server_updated_at, sharing_state
    ) values (
        p_user_id, public.wif_city_key(v_city, v_country), v_city, v_country, p_source,
        p_client_updated_at, now(), 'active'
    )
    on conflict (user_id) do update
      set normalized_city_id = excluded.normalized_city_id,
          city_name = excluded.city_name,
          country_code = excluded.country_code,
          source = excluded.source,
          client_updated_at = excluded.client_updated_at,
          server_updated_at = now(),
          sharing_state = 'active'
      where excluded.client_updated_at >= public.current_presence.client_updated_at;

    perform public.wif_evaluate_user(p_user_id);
    return public.wif_snapshot(p_user_id);
end;
$$;

alter table public.app_users enable row level security;
alter table public.app_sessions enable row level security;
alter table public.friendships enable row level security;
alter table public.user_blocks enable row level security;
alter table public.sharing_preferences enable row level security;
alter table public.user_sharing_settings enable row level security;
alter table public.current_presence enable row level security;
alter table public.devices enable row level security;
alter table public.colocation_sessions enable row level security;
alter table public.colocation_events enable row level security;
alter table public.notification_outbox enable row level security;
alter table public.deletion_requests enable row level security;

-- Supabase creates these roles. The conditional block also lets the migration
-- execute in the lightweight PGlite verification database used by this repo.
do $$
begin
    if exists (select 1 from pg_roles where rolname = 'anon') then
        execute 'revoke all on all tables in schema public from anon';
        execute 'revoke all on all functions in schema public from anon';
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
        execute 'revoke all on all tables in schema public from authenticated';
        execute 'revoke all on all functions in schema public from authenticated';
    end if;
end;
$$;

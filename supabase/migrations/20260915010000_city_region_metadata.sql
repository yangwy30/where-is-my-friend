-- Additive metadata only. Do not rewrite city keys or generate region-arrival events.
begin;
alter table public.current_presence add column administrative_area text check (length(administrative_area) <= 120);

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
            'administrativeArea', case
                when coalesce(other_settings.city_sharing_enabled, true)
                 and coalesce(other_pref.shares_city, true)
                 and cp.sharing_state = 'active' then cp.administrative_area
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
        'administrativeArea', vp.administrative_area,
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


-- Legacy writers explicitly clear unavailable state metadata.
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
          administrative_area = null,
          source = excluded.source,
          client_updated_at = excluded.client_updated_at,
          server_updated_at = now(),
          sharing_state = 'active'
      where excluded.client_updated_at >= public.current_presence.client_updated_at;

    perform public.wif_evaluate_user(p_user_id);
    return public.wif_snapshot(p_user_id);
end;
$$;


create or replace function public.wif_update_presence_v2(
    p_user_id uuid,
    p_city text,
    p_country_code text,
    p_source text,
    p_client_updated_at timestamptz,
    p_administrative_area text default null
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
    if length(trim(p_administrative_area)) > 120 then raise exception 'Invalid administrative area.'; end if;
    if char_length(v_city) not between 1 and 120 then raise exception 'Invalid city.'; end if;
    if v_country !~ '^[A-Z]{2}$' then raise exception 'Invalid country code.'; end if;
    if p_source not in ('manual', 'foregroundLocation', 'significantChange', 'visit') then
        raise exception 'Invalid presence source.';
    end if;
    if p_client_updated_at > now() + interval '5 minutes' then raise exception 'Invalid update time.'; end if;

    insert into public.current_presence(
        user_id, normalized_city_id, city_name, country_code, administrative_area, source,
        client_updated_at, server_updated_at, sharing_state
    ) values (
        p_user_id, public.wif_city_key(v_city, v_country), v_city, v_country, nullif(trim(p_administrative_area), ''), p_source,
        p_client_updated_at, now(), 'active'
    )
    on conflict (user_id) do update
      set normalized_city_id = excluded.normalized_city_id,
          city_name = excluded.city_name,
          country_code = excluded.country_code,
          administrative_area = excluded.administrative_area,
          source = excluded.source,
          client_updated_at = excluded.client_updated_at,
          server_updated_at = now(),
          sharing_state = 'active'
      where excluded.client_updated_at >= public.current_presence.client_updated_at;

    perform public.wif_evaluate_user(p_user_id);
    return public.wif_snapshot(p_user_id);
end;
$$;


revoke all on function public.wif_update_presence_v2(uuid,text,text,text,timestamptz,text) from public;
do $$ declare role_name text; begin
    foreach role_name in array array['anon','authenticated'] loop
        if exists(select 1 from pg_roles where rolname=role_name) then
            execute format('revoke all on function public.wif_update_presence_v2(uuid,text,text,text,timestamptz,text) from %I',role_name);
        end if;
    end loop;
    if exists(select 1 from pg_roles where rolname='service_role') then
        grant execute on function public.wif_update_presence_v2(uuid,text,text,text,timestamptz,text) to service_role;
    end if;
end; $$;
commit;

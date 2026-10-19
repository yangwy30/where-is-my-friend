-- Same-city history is shown per friend, as trips. Two server changes support it:
-- 1. A road trip alerts once: arriving together in the next city within 6 hours of
--    leaving the last one records the stay but sends no new same-city alert.
-- 2. The snapshot sends each stay's city name and keeps more stays (300, was 100),
--    so history can name cities and count days without the matching alert.
begin;

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
    v_suppress boolean := false;
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
      and rp.normalized_city_id is not null
      and rp.normalized_city_id = fp.normalized_city_id;

    if v_city_id is null then
        if not public.wif_are_friends(p_recipient_id,p_friend_id) or exists(
            select 1 from current_presence p,current_presence f where p.user_id=p_recipient_id
            and f.user_id=p_friend_id and p.normalized_city_id is not null and f.normalized_city_id is not null
        ) then
            delete from colocation_identity_baselines where recipient_id=p_recipient_id and friend_id=p_friend_id;
        end if;
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

    -- Expiry hides current presence, but never manufactures a departure/re-arrival.
    if not exists(select 1 from current_presence where user_id=p_recipient_id
        and client_updated_at>now()-interval '24 hours' and client_updated_at<=now()+interval '1 minute')
      or not exists(select 1 from current_presence where user_id=p_friend_id
        and client_updated_at>now()-interval '24 hours' and client_updated_at<=now()+interval '1 minute') then return; end if;

    select exists(select 1 from colocation_identity_baselines b
      join current_presence p on p.user_id=p_recipient_id
      where b.recipient_id=p_recipient_id and b.friend_id=p_friend_id
        and b.old_city_key=public.wif_city_key(p.city_name,p.country_code)) into v_suppress;
    delete from colocation_identity_baselines where recipient_id=p_recipient_id and friend_id=p_friend_id;

    select max(left_at) into v_last_exit
    from public.colocation_sessions
    where recipient_id = p_recipient_id
      and friend_id = p_friend_id
      and normalized_city_id = v_city_id;

    if not v_suppress and v_last_exit is not null and v_last_exit > now() - interval '6 hours' then
        return;
    end if;

    insert into public.colocation_sessions(recipient_id, friend_id, normalized_city_id, city_name)
    values (p_recipient_id, p_friend_id, v_city_id, v_city_name)
    returning id into v_session_id;

    -- Arriving together in the next city of a trip is not news: only the first city alerts.
    -- The window matches the app's trip gap and the same-city re-arrival cooldown above.
    if exists (
        select 1 from public.colocation_sessions
        where recipient_id = p_recipient_id
          and friend_id = p_friend_id
          and normalized_city_id <> v_city_id
          and left_at > now() - interval '6 hours'
    ) then
        v_suppress := true;
    end if;

    if v_alert_enabled and not v_suppress then
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
            'cityKey', e.normalized_city_id,
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
            'leftAt', s.left_at,
            'cityName', s.city_name
        ) order by s.entered_at desc
    ), '[]'::jsonb) as value
    from (
        select * from public.colocation_sessions
        where recipient_id = p_user_id
        order by entered_at desc
        limit 300
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

commit;

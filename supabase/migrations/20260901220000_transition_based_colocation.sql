-- Transition-based colocation session lifecycle
-- Removes artificial 2-hour idle expiration so active stays in the same city are maintained
-- without generating duplicate "arrival" moments.

create or replace function public.recompute_colocation_for_pair(
    p_recipient_id uuid,
    p_friend_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_city_id text;
    v_city_name text;
    v_friend_name text;
    v_alert_enabled boolean;
    v_session_id uuid;
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

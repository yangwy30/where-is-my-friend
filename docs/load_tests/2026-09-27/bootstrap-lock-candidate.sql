CREATE OR REPLACE FUNCTION public.wif_ensure_app_user(p_auth_user_id uuid, p_display_name text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
    v_user_id uuid;
    v_display_name text := nullif(left(trim(p_display_name), 40), '');
    v_username text;
begin
    if p_auth_user_id is null
       or not exists (select 1 from auth.users where id = p_auth_user_id) then
        raise exception 'Authenticated user is unavailable.';
    end if;

    perform pg_advisory_xact_lock(hashtextextended('wif:bootstrap:'||p_auth_user_id::text,0));
    select id into v_user_id
    from public.app_users
    where auth_user_id = p_auth_user_id
      and deleted_at is null;

    if found then
        if v_display_name is not null then
            update public.app_users
            set display_name = v_display_name,
                updated_at = now()
            where id = v_user_id
              and display_name = 'New Friend';
        end if;
    else
        if exists (
            select 1 from public.app_users
            where auth_user_id = p_auth_user_id
              and deleted_at is not null
        ) then
            raise exception 'This account is no longer available.';
        end if;

        v_username := 'friend_' || left(replace(p_auth_user_id::text, '-', ''), 13);
        insert into public.app_users(
            auth_user_id,
            username,
            display_name,
            avatar_palette,
            is_debug
        ) values (
            p_auth_user_id,
            v_username,
            coalesce(v_display_name, 'New Friend'),
            1,
            false
        )
        on conflict (auth_user_id) where auth_user_id is not null do nothing
        returning id into v_user_id;

        if v_user_id is null then
            select id into v_user_id
            from public.app_users
            where auth_user_id = p_auth_user_id
              and deleted_at is null;
        end if;
    end if;

    if v_user_id is null then
        raise exception 'This account is no longer available.';
    end if;

    insert into public.user_sharing_settings(user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;

    return v_user_id;
end;
$function$

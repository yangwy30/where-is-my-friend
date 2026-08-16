-- Bind the app-owned profile model to Supabase Auth without exposing auth.users
-- to the iOS client. Only the service-role Edge API may call the bootstrap RPC.

alter table public.app_users
    add column auth_user_id uuid references auth.users(id) on delete cascade;

create unique index app_users_auth_user_id_key
    on public.app_users(auth_user_id)
    where auth_user_id is not null;

-- Replace the original identity check with one that also accepts a Supabase Auth
-- identity. Discovering the generated constraint name keeps this migration safe
-- across PostgreSQL and the PGlite test database.
do $$
declare
    v_constraint_name text;
begin
    for v_constraint_name in
        select c.conname
        from pg_constraint c
        where c.conrelid = 'public.app_users'::regclass
          and c.contype = 'c'
          and pg_get_constraintdef(c.oid) ilike '%apple_subject%'
          and pg_get_constraintdef(c.oid) ilike '%is_debug%'
    loop
        execute format('alter table public.app_users drop constraint %I', v_constraint_name);
    end loop;
end;
$$;

alter table public.app_users
    add constraint app_users_has_identity
    check (auth_user_id is not null or apple_subject is not null or is_debug);

create or replace function public.wif_ensure_app_user(
    p_auth_user_id uuid,
    p_display_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_user_id uuid;
    v_display_name text := nullif(left(trim(p_display_name), 40), '');
    v_username text;
begin
    if p_auth_user_id is null
       or not exists (select 1 from auth.users where id = p_auth_user_id) then
        raise exception 'Authenticated user is unavailable.';
    end if;

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
$$;

revoke all on function public.wif_ensure_app_user(uuid, text) from public;

do $$
begin
    if exists (select 1 from pg_roles where rolname = 'anon') then
        execute 'revoke all on function public.wif_ensure_app_user(uuid, text) from anon';
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
        execute 'revoke all on function public.wif_ensure_app_user(uuid, text) from authenticated';
    end if;
    if exists (select 1 from pg_roles where rolname = 'service_role') then
        execute 'grant execute on function public.wif_ensure_app_user(uuid, text) to service_role';
    end if;
end;
$$;

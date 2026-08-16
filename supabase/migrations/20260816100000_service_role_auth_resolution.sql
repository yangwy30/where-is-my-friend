-- Resolve a verified Supabase Auth identity without granting the Edge service
-- role direct SELECT access to the private app_users table.

create or replace function public.wif_resolve_app_user(
    p_auth_user_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select app_user.id
    from public.app_users app_user
    where app_user.auth_user_id = p_auth_user_id
      and app_user.deleted_at is null
    limit 1
$$;

revoke all on function public.wif_resolve_app_user(uuid) from public;

do $$
begin
    if exists (select 1 from pg_roles where rolname = 'anon') then
        execute 'revoke all on function public.wif_resolve_app_user(uuid) from anon';
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
        execute 'revoke all on function public.wif_resolve_app_user(uuid) from authenticated';
    end if;
    if exists (select 1 from pg_roles where rolname = 'service_role') then
        execute 'grant execute on function public.wif_resolve_app_user(uuid) to service_role';
    end if;
end;
$$;

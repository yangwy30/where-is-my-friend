begin;

-- Only the sender may withdraw a pending invitation. Lock the same row as
-- acceptance so a concurrent accept can never turn withdrawal into unfriend.
create or replace function public.wif_cancel_friend_request(p_user_id uuid, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
    v_request public.friendships%rowtype;
begin
    select * into v_request from public.friendships where id = p_request_id for update;
    if not found then return public.wif_snapshot(p_user_id); end if;
    if v_request.requester_id <> p_user_id or v_request.status <> 'pending' then
        raise exception 'This invitation is no longer pending or cannot be withdrawn.';
    end if;
    -- The existing foreign keys also remove queued invitation alerts/deliveries.
    delete from public.friendships where id = p_request_id;
    return public.wif_snapshot(p_user_id);
end;
$$;

revoke all on function public.wif_cancel_friend_request(uuid, uuid) from public;
do $$ declare r text; begin
    foreach r in array array['anon', 'authenticated'] loop
        if exists(select 1 from pg_roles where rolname = r) then
            execute format('revoke all on function public.wif_cancel_friend_request(uuid, uuid) from %I', r);
        end if;
    end loop;
    if exists(select 1 from pg_roles where rolname = 'service_role') then
        grant execute on function public.wif_cancel_friend_request(uuid, uuid) to service_role;
    end if;
end; $$;
commit;

-- Deterministic profiles for database-only local business-flow verification.
-- They are not Supabase Auth users and cannot sign in through the Edge API.
insert into public.app_users(id, username, display_name, avatar_palette, is_debug)
values
    ('10000000-0000-0000-0000-000000000001', 'alice', 'Alice Chen', 0, true),
    ('10000000-0000-0000-0000-000000000002', 'bob', 'Bob Rivera', 5, true)
on conflict (id) do update
set username = excluded.username,
    display_name = excluded.display_name,
    avatar_palette = excluded.avatar_palette,
    is_debug = true,
    deleted_at = null;

insert into public.user_sharing_settings(user_id)
values
    ('10000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000002')
on conflict (user_id) do nothing;

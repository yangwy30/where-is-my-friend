-- Reference PostgreSQL schema. Adapt types and migration syntax to the selected provider.
create extension if not exists pgcrypto;

create table app_users (
    id uuid primary key default gen_random_uuid(),
    apple_subject text not null unique,
    username text not null unique check (username = lower(username)),
    display_name text not null,
    avatar_palette smallint not null default 1 check (avatar_palette between 0 and 6),
    created_at timestamptz not null default now(),
    deleted_at timestamptz
);

create table friendships (
    id uuid primary key default gen_random_uuid(),
    requester_id uuid not null references app_users(id) on delete cascade,
    addressee_id uuid not null references app_users(id) on delete cascade,
    status text not null check (status in ('pending', 'accepted', 'declined')),
    created_at timestamptz not null default now(),
    accepted_at timestamptz,
    unique (requester_id, addressee_id),
    check (requester_id <> addressee_id)
);

create table user_blocks (
    blocker_id uuid not null references app_users(id) on delete cascade,
    blocked_id uuid not null references app_users(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    check (blocker_id <> blocked_id)
);

create table sharing_preferences (
    owner_id uuid not null references app_users(id) on delete cascade,
    friend_id uuid not null references app_users(id) on delete cascade,
    shares_city boolean not null default true,
    same_city_alert boolean not null default true,
    updated_at timestamptz not null default now(),
    primary key (owner_id, friend_id),
    check (owner_id <> friend_id)
);

create table current_presence (
    user_id uuid primary key references app_users(id) on delete cascade,
    normalized_city_id text,
    city_name text,
    country_code char(2),
    source text not null check (source in ('manual', 'foregroundLocation', 'significantChange', 'visit')),
    client_updated_at timestamptz not null,
    server_updated_at timestamptz not null default now(),
    sharing_state text not null default 'active' check (sharing_state in ('active', 'paused', 'unavailable'))
);

create table devices (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_users(id) on delete cascade,
    apns_token_hash text not null unique,
    encrypted_apns_token bytea not null,
    environment text not null check (environment in ('sandbox', 'production')),
    last_seen_at timestamptz not null default now()
);

create table colocation_events (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references app_users(id) on delete cascade,
    session_id uuid not null,
    normalized_city_id text not null,
    deduplication_key text not null unique,
    payload jsonb not null,
    created_at timestamptz not null default now(),
    delivered_at timestamptz
);

create table colocation_sessions (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references app_users(id) on delete cascade,
    friend_id uuid not null references app_users(id) on delete cascade,
    normalized_city_id text not null,
    entered_at timestamptz not null default now(),
    left_at timestamptz,
    check (recipient_id <> friend_id)
);

alter table colocation_events
    add constraint colocation_events_session_fk
    foreign key (session_id) references colocation_sessions(id) on delete cascade;

create table notification_outbox (
    id uuid primary key default gen_random_uuid(),
    event_id uuid not null unique references colocation_events(id) on delete cascade,
    attempts integer not null default 0,
    available_at timestamptz not null default now(),
    delivered_at timestamptz,
    last_error text
);

create index friendships_addressee_status_idx on friendships(addressee_id, status);
create index friendships_requester_status_idx on friendships(requester_id, status);
create index current_presence_city_idx on current_presence(normalized_city_id, server_updated_at);
create index user_blocks_blocked_idx on user_blocks(blocked_id);
create unique index colocation_sessions_active_idx
    on colocation_sessions(recipient_id, friend_id, normalized_city_id)
    where left_at is null;
create index colocation_sessions_recent_exit_idx
    on colocation_sessions(recipient_id, friend_id, normalized_city_id, left_at desc);
create index notification_outbox_pending_idx on notification_outbox(available_at) where delivered_at is null;

begin;

-- New requests only. Existing pending requests remain in-app, with no surprise backfill.
create table public.friend_invitation_alerts (
 id uuid primary key default gen_random_uuid(),
 request_id uuid not null references friendships(id) on delete cascade,
 request_created_at timestamptz not null,
 sender_id uuid not null references app_users(id) on delete cascade,
 recipient_id uuid not null references app_users(id) on delete cascade,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '7 days',
 unique(request_id,request_created_at,sender_id,recipient_id)
);
create table public.friend_invitation_deliveries (
 id uuid primary key default gen_random_uuid(),
 alert_id uuid not null references friend_invitation_alerts(id) on delete cascade,
 recipient_id uuid not null references app_users(id) on delete cascade,
 device_id uuid not null references devices(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','delivered','failed')),
 attempts integer not null default 0,
 available_at timestamptz not null default now(),
 claim_token uuid, claimed_at timestamptz, delivered_at timestamptz,
 last_error text, apns_id text,
 unique(alert_id,device_id)
);
create index friend_invitation_delivery_pending on public.friend_invitation_deliveries(available_at) where status='pending';

create function public.wif_friend_invitation_enqueue() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if new.status<>'pending' then return new; end if;
 if tg_op='UPDATE' and old.status='pending' and
   row(old.created_at,old.requester_id,old.addressee_id) is not distinct from row(new.created_at,new.requester_id,new.addressee_id)
 then return new; end if;
 -- A declined request is not permission to repeatedly buzz the same person.
 if exists(select 1 from friend_invitation_alerts where sender_id=new.requester_id and recipient_id=new.addressee_id
   and created_at>now()-interval '10 minutes') then raise exception 'Please wait before inviting this person again.'; end if;
 insert into friend_invitation_alerts(request_id,request_created_at,sender_id,recipient_id)
 values(new.id,new.created_at,new.requester_id,new.addressee_id) on conflict do nothing;
 return new;
end; $$;
create trigger friend_invitation_created after insert or update of status,created_at,requester_id,addressee_id on public.friendships
 for each row execute function public.wif_friend_invitation_enqueue();

create function public.wif_friend_invitation_allowed(p_alert uuid,p_recipient uuid,p_device uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from friend_invitation_alerts a
 join friendships f on f.id=a.request_id and f.created_at=a.request_created_at and f.status='pending'
   and f.requester_id=a.sender_id and f.addressee_id=a.recipient_id
 join app_users sender on sender.id=a.sender_id and sender.deleted_at is null
 join app_users recipient on recipient.id=a.recipient_id and recipient.deleted_at is null
 join devices d on d.id=p_device and d.user_id=a.recipient_id and d.disabled_at is null
 where a.id=p_alert and a.recipient_id=p_recipient and a.expires_at>now()
 and not exists(select 1 from user_blocks b where
  (b.blocker_id=a.sender_id and b.blocked_id=a.recipient_id) or (b.blocker_id=a.recipient_id and b.blocked_id=a.sender_id)));
$$;

create function public.wif_friend_invitation_claim(p_token uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 if p_token is null then raise exception 'Claim token required.'; end if;
 insert into friend_invitation_deliveries(alert_id,recipient_id,device_id)
 select a.id,a.recipient_id,d.id from friend_invitation_alerts a join devices d on d.user_id=a.recipient_id
 where wif_friend_invitation_allowed(a.id,a.recipient_id,d.id) on conflict do nothing;
 update friend_invitation_deliveries d set status='failed',claim_token=null,claimed_at=null,
 last_error='Request unavailable, device reassigned, or retry limit reached.'
 where d.status='pending' and ((d.attempts>=5 and (d.claimed_at is null or d.claimed_at<now()-interval '2 minutes'))
 or not wif_friend_invitation_allowed(d.alert_id,d.recipient_id,d.device_id));
 with next as (select id from friend_invitation_deliveries where status='pending' and available_at<=now()
   and (claimed_at is null or claimed_at<now()-interval '2 minutes') order by available_at,id for update skip locked limit 20),
 claimed as (update friend_invitation_deliveries d set claim_token=p_token,claimed_at=now(),attempts=attempts+1
   from next where d.id=next.id returning d.id)
 select coalesce(jsonb_agg(jsonb_build_object('delivery_id',id)),'[]') into result from claimed;
 return result;
end; $$;

create function public.wif_friend_invitation_prepare(p_id uuid,p_token uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare delivery friend_invitation_deliveries;
begin
 select * into delivery from friend_invitation_deliveries where id=p_id and claim_token=p_token and status='pending'
 and claimed_at>now()-interval '2 minutes';
 if delivery.id is null or not wif_friend_invitation_allowed(delivery.alert_id,delivery.recipient_id,delivery.device_id) then return null; end if;
 return (select jsonb_build_object('delivery_id',delivery.id,'device_id',d.id,'encrypted_apns_token',d.encrypted_apns_token,
  'environment',d.environment,'bundle_id',d.bundle_id,'event_id',a.id,
  'expires_at',extract(epoch from least(a.expires_at,now()+interval '1 hour'))::bigint,
  'title','Friend request',
  'body',case when s.notification_preview_enabled then sender.display_name||' wants to connect with you. Tap to review.'
    else 'You have a new friend request. Open Across Us to review.' end,
  'deep_link',d.url_scheme||'://friend-requests/'||a.request_id::text)
 from friend_invitation_alerts a join app_users sender on sender.id=a.sender_id
 join user_sharing_settings s on s.user_id=a.recipient_id
 join devices d on d.id=delivery.device_id where a.id=delivery.alert_id);
end; $$;

create function public.wif_friend_invitation_complete(p_id uuid,p_token uuid,p_outcome text,
 p_error text default null,p_apns_id text default null,p_disable_device boolean default false) returns boolean
language plpgsql security definer set search_path=public as $$
declare delivery friend_invitation_deliveries;
begin
 if p_outcome is null or p_outcome not in ('delivered','retry','failed') then raise exception 'Invalid outcome.'; end if;
 update friend_invitation_deliveries set status=case when p_outcome='retry' and attempts<5 then 'pending'
   when p_outcome='retry' then 'failed' else p_outcome end,
 claim_token=null,claimed_at=null,available_at=now()+interval '1 minute',
 delivered_at=case when p_outcome='delivered' then now() else delivered_at end,last_error=left(p_error,500),apns_id=p_apns_id
 where id=p_id and claim_token=p_token and status='pending' returning * into delivery;
 if delivery.id is null then return false; end if;
 if p_disable_device then update devices set disabled_at=now(),disabled_reason='apns_permanent_error'
 where id=delivery.device_id and user_id=delivery.recipient_id; end if;
 return true;
end; $$;

alter table friend_invitation_alerts enable row level security;
alter table friend_invitation_deliveries enable row level security;
revoke all on friend_invitation_alerts,friend_invitation_deliveries from public;
do $$ declare fn regprocedure; r text; begin
 foreach r in array array['anon','authenticated'] loop
  if exists(select 1 from pg_roles where rolname=r) then
   execute format('revoke all on public.friend_invitation_alerts,public.friend_invitation_deliveries from %I',r);
  end if;
 end loop;
 for fn in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname like 'wif_friend_invitation_%' loop
  execute format('revoke all on function %s from public',fn);
  foreach r in array array['anon','authenticated'] loop
   if exists(select 1 from pg_roles where rolname=r) then execute format('revoke all on function %s from %I',fn,r); end if;
  end loop;
  if exists(select 1 from pg_roles where rolname='service_role') then execute format('grant execute on function %s to service_role',fn); end if;
 end loop;
end; $$;
commit;

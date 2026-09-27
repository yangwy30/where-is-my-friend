-- Synthetic accounts only. Run on the ephemeral cluster created by run.mjs.
create table public.load_accounts (n integer primary key, id uuid not null, auth_id uuid not null);
insert into public.load_accounts select n,gen_random_uuid(),gen_random_uuid() from generate_series(1,1000) n;
insert into auth.users(id,email) select auth_id,'load-'||n||'@example.invalid' from load_accounts;
insert into app_users(id,auth_user_id,username,display_name) select id,auth_id,'load_'||n,'Load User '||n from load_accounts;
insert into user_sharing_settings(user_id) select id from load_accounts;
insert into current_presence(user_id,normalized_city_id,city_name,country_code,source,client_updated_at,sharing_state,administrative_area)
select id,'US:loadcity'||(n%5),'Load City '||(n%5),'US','manual',now(),'active','CA' from load_accounts;
-- A ring graph gives every account 20 accepted friends, including wraparound.
insert into friendships(requester_id,addressee_id,status,responded_at,accepted_at)
select a.id,b.id,'accepted',now(),now() from load_accounts a cross join generate_series(1,10) d
join load_accounts b on b.n=((a.n+d-1)%1000)+1;
insert into travel_plans(id,owner_id,city,country_code,region,time_zone,city_key,start_day,end_day,allow_friend_browsing)
select gen_random_uuid(),a.id,'Load City '||(a.n%5),'US','CA','UTC','load:'||(a.n%5),current_date+7+(p*20),current_date+10+(p*20),true
from load_accounts a cross join generate_series(0,2) p;
insert into travel_plan_audience(plan_id,friend_id,friendship_id)
select p.id,case when f.requester_id=p.owner_id then f.addressee_id else f.requester_id end,f.id
from travel_plans p join friendships f on f.requester_id=p.owner_id or f.addressee_id=p.owner_id;
-- 3 trips per account, 5 participants per trip; one is historical.
insert into trips(id,name,start_date,end_date,destination_airport,completed_at)
select 'load-trip-'||g||'-'||t,'Load Trip '||g||'-'||t,
to_char(current_date+case when t=0 then -60 else t*20 end,'YYYY-MM-DD'),
to_char(current_date+case when t=0 then -55 else t*20+5 end,'YYYY-MM-DD'),'LAX',case when t=0 then now()-interval '50 days' end
from generate_series(0,199) g cross join generate_series(0,2) t;
insert into trip_members(trip_id,user_id,role)
select 'load-trip-'||((a.n-1)/5)||'-'||t,a.id,case when (a.n-1)%5=0 then 'owner' else 'member' end
from load_accounts a cross join generate_series(0,2) t;
insert into participants(id,trip_id,user_id,name)
select gen_random_uuid(),m.trip_id,m.user_id,u.display_name from trip_members m join app_users u on u.id=m.user_id;
insert into flights(id,trip_id,participant_id,flight_number,date,direction,status,departure,arrival)
select 'load-flight-'||p.id,p.trip_id,p.id,'UA100',t.start_date,'outbound','unverified',
'{"code":"SFO"}'::jsonb,'{"code":"LAX"}'::jsonb from participants p join trips t on t.id=p.trip_id;
insert into devices(user_id,apns_token_hash,encrypted_apns_token,environment,installation_id,platform,bundle_id,url_scheme)
select id,md5(id::text)||md5(id::text),'v1:synthetic:only','sandbox',gen_random_uuid(),'ios','test.across.load','acrossload' from load_accounts;
insert into trip_reminder_context(user_id,time_zone,locale) select id,'UTC','en' from load_accounts;
-- Recent sessions/events exercise the real snapshot's history joins too.
insert into colocation_sessions(recipient_id,friend_id,normalized_city_id,city_name,entered_at,left_at)
select a.id,b.id,'US:loadcity'||(a.n%5),'Load City '||(a.n%5),now()-interval '2 days',now()-interval '1 day'
from load_accounts a cross join generate_series(1,5) d join load_accounts b on b.n=((a.n+d-1)%1000)+1;
insert into colocation_events(recipient_id,friend_id,session_id,normalized_city_id,city_name,friend_name,deduplication_key,delivered_at)
select s.recipient_id,s.friend_id,s.id,s.normalized_city_id,s.city_name,u.display_name,s.id::text,now()
from colocation_sessions s join app_users u on u.id=s.friend_id;
analyze;

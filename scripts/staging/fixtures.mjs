export function migrationSQL(name,source){
 if(!/^\d{14}_[a-z0-9_]+\.sql$/.test(name))throw Error('Invalid migration filename');
 const version=name.slice(0,14);
 const body=source.replace(/^(?:\s|--[^\n]*(?:\n|$))*/,'').replace(/^begin;\s*/i,'').replace(/commit;\s*$/i,'');
 const tag='$staging_migration_source$';if(source.includes(tag))throw Error('Migration delimiter collision');
 return `begin;set local lock_timeout='5s';set local statement_timeout='60s';\n${body}\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','${name.slice(15,-4)}',array[${tag}${source}${tag}]);\ncommit;`;
}
export function seedSQL(session){
 if(!/^[a-f0-9-]{36}$/.test(session.runID??''))throw Error('Invalid run ID');
const values=session.accounts.map((a,n)=>`(${n+1},'${a.appID}'::uuid)`).join(',');
const run=session.runID;
return `begin;
 set local statement_timeout='30s';set local lock_timeout='5s';
 do $$ begin
 if exists(select 1 from public.travel_plans) or exists(select 1 from public.friendships) or exists(select 1 from public.trips) then raise exception 'Fixture needs an empty test dataset';end if;
 end $$;
 create temporary table actors(n integer,id uuid) on commit drop;
 insert into actors values ${values};
 insert into public.friendships(requester_id,addressee_id,status,responded_at,accepted_at)
 select a.id,b.id,'accepted',now(),now() from actors a join actors b on a.n<b.n;
 insert into public.travel_plans(id,owner_id,city,country_code,region,time_zone,city_key,start_day,end_day,allow_friend_browsing,alerts_enabled)
 select gen_random_uuid(),a.id,'Palm Springs','US','CA','America/Los_Angeles','staging:palmsprings',current_date+7+p*20,current_date+10+p*20,true,false from actors a cross join generate_series(0,2)p;
 insert into public.travel_plan_audience(plan_id,friend_id,friendship_id)
 select p.id,case when f.requester_id=p.owner_id then f.addressee_id else f.requester_id end,f.id from travel_plans p join friendships f on f.requester_id=p.owner_id or f.addressee_id=p.owner_id;
 insert into public.trips(id,name,start_date,end_date,destination_airport)
 select 'staging-${run}-'||g,'Staging Trip',to_char(current_date+7,'YYYY-MM-DD'),to_char(current_date+10,'YYYY-MM-DD'),'LAX' from generate_series(0,${Math.ceil(session.accounts.length/5)-1})g;
 insert into public.trip_members(trip_id,user_id,role)
 select 'staging-${run}-'||((n-1)/5),id,case when (n-1)%5=0 then 'owner' else 'member' end from actors;
 insert into public.participants(id,trip_id,user_id,name)
 select gen_random_uuid(),m.trip_id,m.user_id,'Staging traveler' from public.trip_members m;
 analyze public.travel_plans;analyze public.travel_plan_audience;analyze public.friendships;
 commit;`;
}

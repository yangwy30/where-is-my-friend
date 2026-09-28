import test from 'node:test';import assert from 'node:assert/strict';import {randomUUID} from 'node:crypto';
import {readFile,readdir} from 'node:fs/promises';import {PGlite} from '@electric-sql/pglite';
import {apiObservation,clientObservation,featureForPath,postObservation,pushConfigurationReasons} from '../functions/_shared/observability.mjs';
import {evaluateHealth,healthHTML,boundedJSON,equalSecret} from '../functions/_shared/ops-health.mjs';
const actor='10000000-0000-0000-0000-000000000001';
async function fixture(skipUnreleased=false){const db=new PGlite();await db.exec('create schema auth;create table auth.users(id uuid primary key,email text);create role anon;create role authenticated;create role service_role');for(const f of (await readdir(new URL('../migrations/',import.meta.url))).filter(x=>x.endsWith('.sql')&&(!skipUnreleased||!/^202609270[23]0000/.test(x))).sort())await db.exec(await readFile(new URL('../migrations/'+f,import.meta.url),'utf8'));await db.query('insert into auth.users values($1,$2)',[actor,'synthetic@example.invalid']);return db;}
const value=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const event=(overrides={})=>({eventID:randomUUID(),feature:'plans',kind:'decode_error',status:200,elapsedMs:100,version:'1.0.4(24)',...overrides});
const record=(db,e,source='server',auth=null)=>value(db,'select wif_ops_record_event($1,$2,$3,$4,$5,$6,$7,$8)',[source,e.eventID,e.feature,e.kind,e.status,e.elapsedMs,e.version,auth]);
// Eight arguments include the optional authenticated actor; never take one from client JSON.
test('error observations omit personal paths and normal responses, and throttle per isolate',()=>{
 const id=randomUUID(),request=new Request('https://test.supabase.co/functions/v1/api/v2/friend-plans?friendID=private',{headers:{'x-wif-request-id':id,'x-wif-app-version':'1.0.4(24)'}}),limiter=new Map();
 for(const status of [200,401,403,404,409])assert.equal(apiObservation(request,status,50,{limiter}),null);
 const result=apiObservation(request,503,500,{limiter,now:10000});assert.equal(result.feature,'plans');assert.equal(result.eventID,id);
 assert.doesNotMatch(JSON.stringify(result),/private|friendID|https/);
 assert.equal(apiObservation(request,503,500,{limiter,now:10001}),null);
 assert.ok(apiObservation(request,503,500,{limiter,now:16000}));
 assert.equal(featureForPath('/v1/devices/push-token'),null);
 assert.equal(pushConfigurationReasons.has('BadDeviceToken'),false);assert.equal(pushConfigurationReasons.has('InvalidProviderToken'),true);
});
test('client event schema rejects raw text, identities and ordinary permission failures',async()=>{
 assert.equal(clientObservation(event()).feature,'plans');
 for(const extra of [{message:'private city'},{token:'secret'},{authID:actor},{source:'server'}])assert.throws(()=>clientObservation({...event(),...extra}));
 for(const change of [{kind:'push_configuration'},{kind:'server_error',status:401},{feature:'/v2/plans?secret'},{elapsedMs:Infinity},{version:'x'.repeat(33)}])assert.throws(()=>clientObservation(event(change)));
 await assert.rejects(boundedJSON(new Request('https://test.invalid',{method:'POST',body:'x'.repeat(2049)})),/large/);
 assert.equal(equalSecret('abc','abd'),false);assert.equal(equalSecret('abc','abc'),true);
 let options;await postObservation('https://test.invalid','synthetic-key',event(),{fetcher:async(_,o)=>{options=o;return new Response('true');}});assert.equal(options.redirect,'error');assert.ok(options.signal);
});
test('incidents require repeated failures and eligible queue delay; recovery is quiet when the window clears',()=>{
 assert.equal(evaluateHealth({features:[{feature:'plans',server_errors:4}],queues:[],workers:[]}).status,'ok');
 const down=evaluateHealth({features:[{feature:'plans',server_errors:5}],queues:[{kind:'booking',overdue:1}],workers:[]});assert.equal(down.status,'degraded');assert.equal(down.issues.length,2);
 assert.match(healthHTML(down),/Friend plans/);assert.doesNotMatch(healthHTML(down),/Bearer|supabase/);
 assert.equal(evaluateHealth({features:[],queues:[],workers:[]}).status,'ok');
 const now=Date.now();const workers=[{worker:'push',expected:true,enabled_at:new Date(now-11*60000).toISOString(),last_success:null}];
 assert.equal(evaluateHealth({workers},{now}).issues[0].code,'worker_stale');workers[0].last_success=new Date(now).toISOString();assert.equal(evaluateHealth({workers},{now}).status,'ok');
});
test('event storage is private, deduplicated, bounded and counts a request once across server/client',async()=>{
 const db=await fixture();try{
  const e=event({kind:'server_error',status:503});assert.equal(await record(db,e),true);assert.equal(await record(db,e),false);
  assert.equal(await record(db,e,'client',actor),true);
  let health=await value(db,'select wif_ops_health()');assert.equal(health.features[0].server_errors,1);
  for(let i=0;i<9;i++)assert.equal(await record(db,event(),'client',actor),true);
  assert.equal(await record(db,event(),'client',actor),false);
  for(let i=0;i<19;i++)await record(db,event({kind:'server_error',status:503}));
  assert.equal(await record(db,event({kind:'server_error',status:503})),false);
  assert.equal(await value(db,'select count(*)::integer from wif_ops_events'),30);
  await db.exec('set role authenticated');await assert.rejects(value(db,'select wif_ops_health()'),/permission denied/);await assert.rejects(value(db,'select count(*) from wif_ops_events'),/permission denied/);
 }finally{await db.close();}
});
test('worker heartbeat detects stalled processing even with no deliveries, and event retention expires',async()=>{
 const db=await fixture();try{
  await db.exec("update wif_ops_settings set expect_push=true,enabled_at=now()-interval '11 minutes'");
  assert.equal(evaluateHealth(await value(db,'select wif_ops_health()')).status,'degraded');
  await value(db,"select wif_ops_worker_heartbeat('push',true)");assert.equal(evaluateHealth(await value(db,'select wif_ops_health()')).status,'ok');
  await record(db,event());await db.exec("update wif_ops_events set received_at=now()-interval '4 days'");await value(db,'select wif_ops_prune()');assert.equal(await value(db,'select count(*)::integer from wif_ops_events'),0);
 }finally{await db.close();}
});

test('monitor endpoints require the probe secret or a verified user and retain healthy/error status',async()=>{
 const {stripTypeScriptTypes}=await import('node:module'),vm=await import('node:vm');
 const {authFailureStatus}=await import('../functions/_shared/upstream-policy.mjs');
 const raw=(await readFile(new URL('../functions/ops-monitor/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
 let handler,reads=0,stored=0;
 const waits=[];const secret='a'.repeat(48);
 const database={auth:{getUser:async t=>t==='valid'?{data:{user:{id:actor}},error:null}:{data:{user:null},error:{status:401}}},rpc:async name=>{if(name==='wif_ops_health')reads++;return {data:{features:[],queues:[],workers:[]},error:null};}};
 vm.runInNewContext(stripTypeScriptTypes(raw,{mode:'transform'}),{Request,Response,URL,Date,AbortSignal,console,
  boundedJSON,equalSecret,evaluateHealth,healthHTML,clientObservation,authFailureStatus,
  postObservation:async(_,__,event,options)=>{assert.equal(options.source,'client');assert.equal(options.authID,actor);stored++;return true;},
  fetch:async()=>new Response('{"message":"The session expired."}',{status:401,headers:{'x-wif-request-id':randomUUID()}}),createClient:()=>database,
  EdgeRuntime:{waitUntil:p=>waits.push(p)},Deno:{env:{get:n=>({SUPABASE_URL:'https://test.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'synthetic',SUPABASE_ANON_KEY:'synthetic',OPS_PROBE_TOKEN:secret})[n]},serve:f=>handler=f}});
 const req=(path,method='GET',body,token)=>handler(new Request('https://test.supabase.co/functions/v1/ops-monitor/'+path,{method,headers:{...(token?{Authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body)}));
 assert.equal((await req('status/bad')).status,404);assert.equal(reads,0);
 assert.equal((await req('status/'+secret)).status,200);assert.equal((await req('status/'+secret,'HEAD')).status,200);assert.equal(reads,1);
 assert.equal((await req('client-events','POST',event())).status,401);
 assert.equal((await req('client-events','POST',event({authID:actor}),'valid')).status,400);assert.equal(stored,0);
 assert.equal((await req('client-events','POST',event(),'valid')).status,204);assert.equal(stored,1);
 await Promise.all(waits);
});

test('notification backoff retains original age and opted-out or disabled recipients do not alert',async()=>{
 const db=await fixture();try{
  const other='20000000-0000-0000-0000-000000000001';await db.query('insert into auth.users values($1,$2)',[other,'other@example.invalid']);
  const a=await value(db,'select wif_ensure_app_user($1)',[actor]),b=await value(db,'select wif_ensure_app_user($1)',[other]);
  await db.query("insert into trips(id,name,start_date,end_date,destination_airport) values('ops-test','Synthetic',to_char(current_date+7,'YYYY-MM-DD'),to_char(current_date+9,'YYYY-MM-DD'),'LAX')");
  await db.query("insert into trip_members(trip_id,user_id,role) values('ops-test',$1,'owner'),('ops-test',$2,'member')",[a,b]);
  await db.query("insert into participants(id,trip_id,user_id,name) values(gen_random_uuid(),'ops-test',$1,'A'),(gen_random_uuid(),'ops-test',$2,'B')",[a,b]);
  const device=await value(db,"insert into devices(user_id,apns_token_hash,encrypted_apns_token,environment,installation_id,platform,bundle_id,url_scheme) values($1,repeat('a',64),'v1:test:only','sandbox',gen_random_uuid(),'ios','com.test.staging','testapp') returning id",[b]);
  const reminder=await value(db,"insert into trip_booking_reminders(trip_id,recipient_id,sender_id,kind,scheduled_day,created_at,expires_at) values('ops-test',$1,$2,'manual',current_date,now()-interval '20 minutes',now()+interval '1 day') returning id",[b,a]);
  await db.query("insert into trip_booking_deliveries(reminder_id,device_id,attempts,available_at) values($1,$2,1,now()+interval '3 minutes')",[reminder,device]);
  let h=await value(db,'select wif_ops_health()');assert.equal(h.queues[0].overdue,1);assert.ok(h.queues[0].oldest_seconds>=1200);
  await db.query('update devices set disabled_at=now() where id=$1',[device]);h=await value(db,'select wif_ops_health()');assert.equal(h.queues.length,0);
  await db.query('update devices set disabled_at=null where id=$1',[device]);
  await db.query("update trip_members set planning_reminders_enabled=false where user_id=$1",[b]);h=await value(db,'select wif_ops_health()');assert.equal(h.queues.length,0);
 }finally{await db.close();}
});

test('monitoring installs on the actual production baseline without the unreleased pagination migrations',async()=>{
 const db=await fixture(true);try{
  assert.equal(await value(db,"select to_regprocedure('public.wif_travel_overview(uuid)') is null"),true);
  assert.equal(await record(db,event({kind:'server_error',status:503})),true);
  const health=await value(db,'select wif_ops_health()');assert.equal(health.features[0].server_errors,1);assert.ok(Array.isArray(health.queues));
  // Production installed 0400 first. Upgrade in the actual release order as well.
  for(const name of ['20260927020000_plan_pagination_and_bootstrap.sql','20260927030000_home_overlap_summary.sql'])await db.exec(await readFile(new URL('../migrations/'+name,import.meta.url),'utf8'));
  const appID=await value(db,'select wif_ensure_app_user($1)',[actor]);
  const overview=await value(db,'select wif_travel_overview($1)',[appID]);assert.equal(overview.overlapCount,0);assert.equal(overview.includesAllOverlaps,true);
  const legacy=await value(db,'select wif_travel_snapshot($1)',[appID]);assert.ok(Array.isArray(legacy.friendPlans));assert.ok(Array.isArray(legacy.plans));
  assert.equal((await value(db,'select wif_friend_plan_page($1)',[appID])).items.length,0);
  assert.equal((await value(db,'select wif_ops_health()')).features[0].server_errors,1);
 }finally{await db.close();}
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {deliveryGate, drainQueues, settleBatch} from '../functions/_shared/queue-drain.mjs';
import {sharedFlightLookup} from '../functions/_shared/shared-flight-lookup.mjs';
const alice='10000000-0000-0000-0000-000000000001',bob='10000000-0000-0000-0000-000000000002';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function fixture(){
 const db=new PGlite();
 await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role');
 for(const f of (await readdir(new URL('../migrations/',import.meta.url))).filter(x=>x.endsWith('.sql')).sort()) await db.exec(await readFile(new URL('../migrations/'+f,import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await scalar(db,"select wif_trip_create($1,'scale-trip','Together','LAX','2035-01-01','2035-01-03')",[alice]);
 const acquire=(token,actor=alice,number='UA353')=>scalar(db,"select wif_flight_lookup_acquire($1,'scale-trip',$2,'2035-01-01',$3)",[actor,number,token]);
 const finish=(token,result=null)=>scalar(db,"select wif_flight_lookup_finish('UA353','2035-01-01',$1,$2)",[token,result]);
 return {db,acquire,finish};
}

test('a busy queue drains multiple batches while other kinds also progress, under a shared concurrency cap',async()=>{
 let active=0,peak=0;
 const run=deliveryGate({concurrency:6,deadline:Date.now()+10000});
 const sizes={colocation:1000,booking:230,invitations:1};
 const queues=Object.fromEntries(Object.entries(sizes).map(([kind,size])=>[kind,async()=>{
  const count=Math.min(sizes[kind],20);sizes[kind]-=count;
  return Promise.all(Array.from({length:count},()=>run(async()=>{active++;peak=Math.max(peak,active);await new Promise(resolve=>setImmediate(resolve));active--;return 'delivered';})));
 }]));
 const result=await drainQueues(queues,{deadline:Date.now()+10000,maxRounds:10});
 assert.equal(result.colocation.delivered,200); assert.equal(result.booking.delivered,200);assert.equal(result.invitations.delivered,1);
 assert.equal(result.colocation.rounds,10);assert.equal(peak,6);assert.equal(sizes.colocation,800);
});

test('deadline prevents unstarted sends and new claims; queue errors and retries never spin',async()=>{
 let now=0,sent=0,claims=0;
 const run=deliveryGate({concurrency:1,deadline:5,now:()=>now});
 const outcomes=await Promise.all([run(async()=>{sent++;now=5;return 'delivered';}),run(async()=>{sent++;return 'delivered';})]);
 assert.deepEqual(outcomes,['delivered','deferred']);assert.equal(sent,1);
 const result=await drainQueues({expired:async()=>{claims++;return ['delivered'];}},{deadline:5,now:()=>now});
 assert.equal(claims,0);assert.equal(result.expired.claimed,0);
 const isolated=await drainQueues({broken:async()=>{throw Error('offline');},retry:async()=>['retry'],healthy:async()=>[]},{deadline:10,now:()=>0});
 assert.equal(isolated.broken.error,true);assert.equal(isolated.retry.rounds,1);assert.equal(isolated.healthy.error,false);
});

test('same flight requests share a durable lease and cache; access is checked even on cache hits',async()=>{
 const {db,acquire,finish}=await fixture();try{
  const token=crypto.randomUUID();assert.equal((await acquire(token)).acquired,true);
  for(let i=0;i<20;i++)assert.equal((await acquire(crypto.randomUUID())).pending,true);
  assert.equal(await scalar(db,"select calls from trip_flight_lookup_limits where bucket='global'"),1);
  assert.equal(await finish(crypto.randomUUID(),{}),false);
  const result={source:'aerodatabox',flightNumber:'UA353',date:'2035-01-01',fetchedAt:new Date().toISOString(),flights:[{id:'route'}]};
  assert.equal(await finish(token,result),true);
  assert.deepEqual((await acquire(crypto.randomUUID())).cached,result);
  await assert.rejects(acquire(crypto.randomUUID(),bob),/access denied/);
  assert.equal(await scalar(db,"select calls from trip_flight_lookup_limits where bucket='global'"),1);
 }finally{await db.close();}
});

test('failed and abandoned leases recover without refunding spend or accepting an old owner result',async()=>{
 const {db,acquire,finish}=await fixture();try{
  const first=crypto.randomUUID();await acquire(first);await finish(first);
  assert.equal((await acquire(crypto.randomUUID())).pending,true);
  await db.exec('update flight_lookup_requests set retry_at=now()');
  const abandoned=crypto.randomUUID();assert.equal((await acquire(abandoned)).acquired,true);
  await db.exec("update flight_lookup_requests set lease_until=now()-interval '1 second'");
  const replacement=crypto.randomUUID();assert.equal((await acquire(replacement)).acquired,true);
  assert.equal(await finish(abandoned,{source:'aerodatabox',flightNumber:'UA353',date:'2035-01-01',flights:[]}),false);
  assert.equal(await scalar(db,"select calls from trip_flight_lookup_limits where bucket='global'"),3);
 }finally{await db.close();}
});

test('global and background ceilings stay 50/20; hourly rejection never consumes a global reservation',async()=>{
 const {db,acquire}=await fixture();try{
  assert.deepEqual(await scalar(db,'select to_jsonb(p)-\'id\' from flight_lookup_policy p'),{daily_total:50,daily_background:20,hourly_per_user:10});
  for(let i=0;i<20;i++)assert.equal(await scalar(db,'select wif_flight_reserve_budget(null,true)'),true);
  assert.equal(await scalar(db,'select wif_flight_reserve_budget(null,true)'),false);
  for(let i=0;i<10;i++)await acquire(crypto.randomUUID(),alice,'UA'+(100+i));
  await assert.rejects(acquire(crypto.randomUUID(),alice,'UA999'),/limit reached/);
  assert.equal(await scalar(db,"select calls from trip_flight_lookup_limits where bucket='global'"),30);
  await db.exec("update trip_flight_lookup_limits set calls=50 where bucket='global'");
  await assert.rejects(acquire(crypto.randomUUID(),alice,'UA998'),/limit reached/);
  await db.exec('set role authenticated');
  await assert.rejects(scalar(db,'select * from flight_lookup_policy'),/permission denied/);
  await assert.rejects(scalar(db,'select wif_capacity_health()'),/permission denied/);
 }finally{await db.close();}
});

test('a follower reuses the leader result without a second provider call and pending waits are bounded',async()=>{
 let reads=0,providerCalls=0;const result={source:'aerodatabox',flights:[]};
 const reused=await sharedFlightLookup(async()=>++reads===1?{pending:true}:{cached:result},alice,'trip',{flightNumber:'UA353',date:'2035-01-01'},'test',{delay:async()=>{},provider:async()=>{providerCalls++;}});
 assert.deepEqual(reused,result);assert.equal(providerCalls,0);
 reads=0;await assert.rejects(sharedFlightLookup(async()=>{reads++;return {pending:true};},alice,'trip',{flightNumber:'UA353',date:'2035-01-01'},'test',{delay:async()=>{},provider:async()=>{providerCalls++;}}),e=>e.status===503);
 assert.equal(reads,4);assert.equal(providerCalls,0);
});

test('foreground and background share a lease and a fresh result without charging twice',async()=>{
 const {db}=await fixture();try{
  const at=new Date(),date=at.toISOString().slice(0,10),token=crypto.randomUUID();
  await scalar(db,"select wif_trip_add_flight($1,'scale-trip','scale-flight','UA353',$2,'outbound')",[alice,date]);
  const candidate={id:'EWR|LAX|test',status:'scheduled',departure:{code:'EWR',scheduledTime:{utc:new Date(+at-60000).toISOString()}},arrival:{code:'LAX',scheduledTime:{utc:new Date(+at+3600000).toISOString()}}};
  await db.query("update flights set candidate_id=$1,departure=$2,arrival=$3,status='scheduled',verified_at=now()-interval '1 hour' where id='scale-flight'",[candidate.id,candidate.departure,candidate.arrival]);
  const args=[alice,'scale-trip','UA353',date,token];
  assert.equal((await scalar(db,'select wif_flight_lookup_acquire($1,$2,$3,$4,$5)',args)).acquired,true);
  assert.equal(await scalar(db,'select wif_trip_claim_refresh($1)',[crypto.randomUUID()]),null);
  const result={source:'aerodatabox',flightNumber:'UA353',date,fetchedAt:at.toISOString(),flights:[candidate]};
  await scalar(db,'select wif_flight_lookup_finish($1,$2,$3,$4)',['UA353',date,token,result]);
  const backgroundToken=crypto.randomUUID();
  const job=await scalar(db,'select wif_trip_claim_refresh($1)',[backgroundToken]);
  assert.deepEqual(job.cached,result);
  await scalar(db,'select wif_trip_finish_refresh($1,$2,$3,$4)',[backgroundToken,'UA353',date,result]);
  assert.equal(await scalar(db,"select calls from trip_flight_lookup_limits where bucket='global'"),1);
  assert.equal(await scalar(db,"select count(*)::int from trip_flight_lookup_limits where bucket='background'"),0);
  assert.equal(await scalar(db,"select tracking_state from flights where id='scale-flight'"),'updated');
 }finally{await db.close();}
});

test('global worker slots coalesce wake-up bursts, preserve the scheduled lane and recover abandoned work',async()=>{
 const {db}=await fixture();try{
  const owner=crypto.randomUUID(),replacement=crypto.randomUUID();
  const claim=(token,lane)=>scalar(db,'select wif_push_worker_acquire($1,$2)',[token,lane]);
  assert.equal(await claim(owner,'interactive'),true);
  for(let i=0;i<30;i++)assert.equal(await claim(crypto.randomUUID(),'interactive'),false);
  assert.equal(await claim(crypto.randomUUID(),'scheduled'),true);
  assert.equal(await scalar(db,"select wif_push_worker_release($1,'interactive')",[replacement]),false);
  await db.exec("update push_worker_slots set lease_until=now()-interval '1 second' where lane='interactive'");
  assert.equal(await claim(replacement,'interactive'),true);
  assert.equal(await scalar(db,"select wif_push_worker_release($1,'interactive')",[owner]),false);
  assert.equal(await scalar(db,"select wif_push_worker_release($1,'interactive')",[replacement]),true);
  await assert.rejects(claim(owner,'invalid'),/Invalid worker lease/);
  await db.exec('set role anon');
  await assert.rejects(claim(owner,'scheduled'),/permission denied/);
 }finally{await db.close();}
});


test('a batch waits for every started delivery before releasing the worker slot on failure',async()=>{
 let finish;let completed=false;
 const slow=new Promise(resolve=>finish=()=>{completed=true;resolve('delivered');});
 const batch=settleBatch([Promise.reject(Error('completion unavailable')),slow]);
 let settled=false;batch.catch(()=>{settled=true;});
 await new Promise(resolve=>setImmediate(resolve));assert.equal(settled,false);
 finish();await assert.rejects(batch,/completion unavailable/);assert.equal(completed,true);
});

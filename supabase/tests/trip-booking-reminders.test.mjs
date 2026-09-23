import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {PGlite} from '@electric-sql/pglite';
import {deliverTripBookingReminders} from '../functions/_shared/trip-booking-reminders.mjs';
const a='10000000-0000-0000-0000-000000000001',b='10000000-0000-0000-0000-000000000002',c='10000000-0000-0000-0000-000000000003';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function fixture(){
 const db=new PGlite();await db.exec('create schema auth;create table auth.users(id uuid primary key,email text);create role anon;create role authenticated;create role service_role');
 for(const f of (await readdir(new URL('../migrations',import.meta.url))).filter(x=>x.endsWith('.sql')).sort()){
  await db.exec(await readFile(new URL('../migrations/'+f,import.meta.url),'utf8'));
 }
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await db.query("insert into app_users(id,username,display_name,is_debug) values($1,'carol','Carol',true)",[c]);
 await db.query('insert into user_sharing_settings(user_id) values($1)',[c]);
 await scalar(db,"select wif_trip_create($1,'booking-trip','A trip','LAX','2035-01-01','2035-01-03')",[a]);
 for(const [id,name] of [[b,'bob'],[c,'carol']]){
  const inv=await scalar(db,"select wif_trip_invite($1,'booking-trip',$2)",[a,name]);
  await scalar(db,'select wif_trip_accept_invitation($1,$2)',[id,inv.id]);
 }
 await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend')",[b,randomUUID(),randomUUID().replaceAll('-','').repeat(2)]);
 const person=await scalar(db,"select id from participants where trip_id='booking-trip' and user_id=$1",[b]);
 const device=await scalar(db,'select id from devices where user_id=$1',[b]);
 const context=(zone='America/Los_Angeles',locale='en')=>scalar(db,'select wif_trip_reminder_context($1,$2,$3)',[b,zone,locale]);
 const remind=(actor=a,target=person)=>scalar(db,"select wif_trip_remind_member($1,'booking-trip',$2)",[actor,target]);
 const claim=token=>scalar(db,'select wif_trip_booking_claim($1)',[token]);
 const prepare=(id,token)=>scalar(db,'select wif_trip_booking_prepare($1,$2)',[id,token]);
 return {db,person,device,context,remind,claim,prepare};
}

test('morning scheduling uses recipient local 9AM, handles DST and never guesses a missing time zone',async()=>{
 const {db,context}=await fixture();try{
  const schedule=at=>scalar(db,'select wif_trip_schedule_booking($1)',[at]);
  assert.equal(await schedule('2026-03-07T17:00:00Z'),0);
  await context();
  assert.equal(await schedule('2026-03-07T16:59:00Z'),0);
  assert.equal(await schedule('2026-03-07T17:00:00Z'),1); // PST
  assert.equal(await schedule('2026-03-07T17:01:00Z'),0);
  assert.equal(await schedule('2026-03-08T16:00:00Z'),1); // PDT, 23 hours later
  assert.equal(await schedule('2026-03-09T17:01:00Z'),0); // after the morning window, no catch-up spam
  await assert.rejects(context('Invented/Place'),/Invalid/);
  await context('Asia/Shanghai','zh-Hans');
  assert.equal(await schedule('2026-03-10T01:00:00Z'),1);
  assert.equal(await scalar(db,'select count(*)::int from trip_booking_reminders'),3);
 }finally{await db.close();}
});

test('every member can remind another member; reminders share a 24-hour cooldown and reject spoofed/self/foreign targets',async()=>{
 const {db,remind,person}=await fixture();try{
  assert.equal((await remind(c)).status,'queued');
  assert.equal((await remind(a)).status,'cooldown');
  assert.equal((await remind(c)).status,'cooldown');
  await assert.rejects(remind(b),/access denied/);
  await assert.rejects(remind(a,randomUUID()),/access denied/);
  await assert.rejects(remind(randomUUID()),/access denied/);
  assert.equal(await scalar(db,'select count(*)::int from trip_booking_reminders'),1);
  await db.exec("update trip_booking_reminders set created_at=now()-interval '25 hours',scheduled_day=current_date-2");
  assert.equal((await remind()).status,'queued');
  await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[b,c]);
  assert.equal((await remind(c)).status,'unavailable');
 }finally{await db.close();}
});

test('adding any outbound flight stops reminders; return-only flights still need outbound; legacy unclassified data stays conservative',async()=>{
 const {db,context,remind}=await fixture();try{
  await context();
  await scalar(db,"select wif_trip_add_flight($1,'booking-trip','return','UA353','2035-01-03','inbound')",[b]);
  assert.equal(await scalar(db,"select wif_trip_needs_flight('booking-trip',$1)",[b]),true);
  await scalar(db,"select wif_trip_add_flight($1,'booking-trip','outbound','UA353','2035-01-01','outbound')",[b]);
  assert.equal((await remind()).status,'unavailable');
  await db.exec("update flights set direction=null where id='outbound'");
  assert.equal(await scalar(db,"select wif_trip_needs_flight('booking-trip',$1)",[b]),false);
 }finally{await db.close();}
});

test('queued reminders respect opt-out, flight additions, member removal, deletion and device ownership at send time',async()=>{
 for(const change of ['opt-out','flight','leave','remove','delete','device']){
  const {db,remind,claim,prepare,person,device}=await fixture();try{
   assert.equal((await remind()).status,'queued');const token=randomUUID();const jobs=await claim(token);assert.equal(jobs.length,1);
   assert.ok(await prepare(jobs[0].delivery_id,token));
   if(change==='opt-out')await scalar(db,"select wif_trip_planning_preferences($1,'booking-trip',false)",[b]);
   if(change==='flight')await scalar(db,"select wif_trip_add_flight($1,'booking-trip','late-flight','UA353','2035-01-01','outbound')",[b]);
   if(change==='device')await db.query('update devices set user_id=$1 where id=$2',[c,device]);
   if(['leave','remove','delete'].includes(change)){
    const rev=await scalar(db,"select revision from trips where id='booking-trip'");
    await scalar(db,"select wif_trip_lifecycle($1,'booking-trip',$2,$3,$4,$5)",[change==='leave'?b:a,change==='remove'?'removeMember':change,randomUUID(),change==='leave'?null:rev,change==='remove'?person:null]);
   }
   assert.equal(await prepare(jobs[0].delivery_id,token),null,change);
  }finally{await db.close();}
 }
});

test('private previews hide names; localized reminder copy and deep links remain account-bound',async()=>{
 const {db,context,remind,claim,prepare}=await fixture();try{
  await context('Asia/Shanghai','zh-Hans');await remind();const token=randomUUID();const [job]=await claim(token);
  await db.query('update user_sharing_settings set notification_preview_enabled=false where user_id=$1',[b]);
  let p=await prepare(job.delivery_id,token);assert.match(p.body,/Across Us/);assert.doesNotMatch(p.body,/A trip|Alice/);
  await db.query('update user_sharing_settings set notification_preview_enabled=true where user_id=$1',[b]);
  p=await prepare(job.delivery_id,token);assert.match(p.body,/去程航班/);assert.match(p.body,/A trip/);
  assert.equal(p.deep_link,'whereismyfriend://trips/view/booking-trip');
  assert.equal(await prepare(job.delivery_id,randomUUID()),null);
  for(const role of ['anon','authenticated']){
   await db.exec('set role '+role);await assert.rejects(remind(),/permission denied/);await assert.rejects(db.query('select * from trip_reminder_context'),/permission denied/);await db.exec('reset role');
  }
 }finally{await db.close();}
});

test('notification leases do not duplicate delivery or invalidate an active fifth attempt',async()=>{
 const {db,remind,claim,prepare}=await fixture();try{
  await remind();const token=randomUUID();const [job]=await claim(token);assert.deepEqual(await claim(randomUUID()),[]);
  await db.query('update trip_booking_deliveries set attempts=5 where id=$1',[job.delivery_id]);
  assert.deepEqual(await claim(randomUUID()),[]);assert.ok(await prepare(job.delivery_id,token));
  assert.equal(await scalar(db,"select wif_trip_booking_complete($1,$2,'delivered')",[job.delivery_id,randomUUID()]),false);
  assert.equal(await scalar(db,"select wif_trip_booking_complete($1,$2,'delivered')",[job.delivery_id,token]),true);
  assert.deepEqual(await claim(randomUUID()),[]);
 }finally{await db.close();}
});

test('worker never sends an invalidated prepared reminder and releases its lease',async()=>{
 const calls=[];let sent=0;
 const database={rpc:async(name,args)=>{calls.push(name);return {data:name==='wif_trip_booking_claim'?[{delivery_id:'x'}]:name==='wif_trip_booking_prepare'?null:true,error:null};}};
 assert.deepEqual(await deliverTripBookingReminders(database,'token',async()=>{sent++;}),['failed']);assert.equal(sent,0);assert.ok(calls.includes('wif_trip_booking_complete'));
});

test('push worker routes booking deliveries correctly and rechecks before APNs',async()=>{
 const {stripTypeScriptTypes}=await import('node:module');const vm=await import('node:vm');
 const {classifyAPNsResponse}=await import('../functions/_shared/push-security.mjs');
 const source=(await readFile(new URL('../functions/push-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
 for(const eligible of [true,false]){
  let handler;const calls=[],sends=[];
  const database={rpc:async(name,args)=>{calls.push({name,args});return {error:null,data:
   name==='wif_trip_booking_claim'?[{delivery_id:'delivery'}]:
   name==='wif_trip_booking_prepare'?{delivery_id:'delivery',device_id:'device',event_id:'reminder',encrypted_apns_token:'encrypted',environment:'production',bundle_id:'com.example.test',title:'Flight reminder',body:'Add your flight',deep_link:'test://trips/view/trip',expires_at:9999999999}:
   name==='wif_trip_booking_allowed'?eligible:true};}};
  class SignJWT {setProtectedHeader(){return this;}setIssuer(){return this;}setIssuedAt(){return this;}async sign(){return 'test-provider-token';}}
  vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),{
   Request,Response,URL,console,crypto,AbortSignal,createClient:()=>database,normalizeAPNsPrivateKey:x=>x,importPKCS8:async()=>({}),SignJWT,
   decryptAPNSToken:async()=> 'test-device-token',classifyAPNsResponse,deliverTripBookingReminders,
   fetch:async(url,options)=>{sends.push({url,options});return new Response('',{status:200});},
   Deno:{env:{get:()=> 'test-only'},serve:fn=>{handler=fn;}},
  });
  const response=await handler(new Request('https://example.invalid/worker',{method:'POST',headers:{Authorization:'Bearer test-only','Content-Type':'application/json'},body:JSON.stringify({action:'trip-reminders'})}));
  assert.equal(response.status,200);assert.equal(sends.length,eligible?1:0);
  const completed=calls.find(c=>c.name==='wif_trip_booking_complete');assert.equal(completed.args.p_outcome,eligible?'delivered':'failed');
  if(eligible){const body=JSON.parse(sends[0].options.body);assert.equal(body.aps['thread-id'],'trip-reminders');assert.equal(body.deepLink,'test://trips/view/trip');}
 }
});

test('turning reminders off and back on does not erase cooldown or replay an old reminder',async()=>{
 const {db,remind,claim}=await fixture();try{
  await remind();const token=randomUUID();assert.equal((await claim(token)).length,1);
  await scalar(db,"select wif_trip_planning_preferences($1,'booking-trip',false)",[b]);
  await scalar(db,"select wif_trip_planning_preferences($1,'booking-trip',true)",[b]);
  assert.equal((await remind(c)).status,'cooldown');
  assert.deepEqual(await claim(randomUUID()),[]);
 }finally{await db.close();}
});

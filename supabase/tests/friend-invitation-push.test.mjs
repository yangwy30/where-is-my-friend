import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {wakeInvitationWorker} from '../functions/_shared/invitation-wakeup.mjs';
const alice='10000000-0000-0000-0000-000000000001',bob='10000000-0000-0000-0000-000000000002';
async function scalar(db,sql,args=[]) {return Object.values((await db.query(sql,args)).rows[0])[0];}
async function setup(legacy=false) {
 const db=new PGlite();
 await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role;');
 for(const file of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort()) {
  if(legacy && file.startsWith('20260915030000'))continue;
  await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
 }
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 return db;
}
const invite=db=>scalar(db,"select wif_send_friend_request($1,'bob')",[alice]);
const requestID=async db=>(await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests[0].id;
const device=(db,owner=bob)=>scalar(db,"select wif_register_push_device($1,$2,$3,'v1:nonce:ciphertext','production','com.yangwy30.whereismyfriend','whereismyfriend')",[owner,'30000000-0000-0000-0000-000000000001','c'.repeat(64)]);
const claim=(db,token)=>scalar(db,'select wif_friend_invitation_claim($1)',[token]);
const prepare=(db,id,token)=>scalar(db,'select wif_friend_invitation_prepare($1,$2)',[id,token]);

test('friend request persists without a device, delivers once after registration, and respects preview privacy',async()=>{
 const db=await setup();try {
  await invite(db);const request=await requestID(db);
  assert.equal(await scalar(db,'select count(*)::int from friend_invitation_alerts'),1);
  assert.equal((await claim(db,crypto.randomUUID())).length,0);
  await assert.rejects(invite(db),/already exists/);
  await device(db);const token=crypto.randomUUID(), jobs=await claim(db,token);
  assert.equal(jobs.length,1);assert.equal((await claim(db,crypto.randomUUID())).length,0);
  let payload=await prepare(db,jobs[0].delivery_id,token);
  assert.equal(payload.deep_link,`whereismyfriend://friend-requests/${request}`);
  assert.match(payload.body,/Alice/);assert.equal(payload.bundle_id,'com.yangwy30.whereismyfriend');
  await scalar(db,'select wif_set_sharing_preferences($1,false,false,false)',[bob]);
  payload=await prepare(db,jobs[0].delivery_id,token);
  assert.equal(payload.body,'You have a new friend request. Open Across Us to review.');
  assert.equal(await scalar(db,"select wif_friend_invitation_complete($1,$2,'delivered')",[jobs[0].delivery_id,token]),true);
  assert.equal((await claim(db,crypto.randomUUID())).length,0);
  await db.exec('set role authenticated');
  await assert.rejects(db.query('select * from friend_invitation_alerts'),/permission denied/);
  await assert.rejects(claim(db,crypto.randomUUID()),/permission denied/);
 }finally{await db.close();}
});

test('accepted, declined, replaced, expired and blocked requests cannot generate a stale push',async()=>{
 const db=await setup();try {
  await device(db);await invite(db);const request=await requestID(db);
  let token=crypto.randomUUID(),jobs=await claim(db,token);
  await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[bob,alice]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  await db.exec('delete from user_blocks');
  await db.exec("update friend_invitation_alerts set expires_at=now()-interval '1 second'");
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  await db.exec("update friend_invitation_alerts set expires_at=now()+interval '7 days'");
  await scalar(db,"select wif_respond_friend_request($1,$2,'decline')",[bob,request]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  await assert.rejects(invite(db),/Please wait/);
  await db.exec("update friend_invitation_alerts set created_at=now()-interval '11 minutes'");
  await invite(db);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  token=crypto.randomUUID();jobs=await claim(db,token);assert.equal(jobs.length,1);
  await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
 }finally{await db.close();}
});

test('leases are bounded and an old delivery cannot disable a new device owner',async()=>{
 const db=await setup();try {
  const d=await device(db);await invite(db);let token=crypto.randomUUID(),jobs=await claim(db,token);const id=jobs[0].delivery_id;
  assert.equal(await scalar(db,"select wif_friend_invitation_complete($1,$2,'delivered')",[id,crypto.randomUUID()]),false);
  await db.query("update friend_invitation_deliveries set claimed_at=now()-interval '3 minutes' where id=$1",[id]);
  assert.equal(await prepare(db,id,token),null);
  const old=token;token=crypto.randomUUID();assert.equal((await claim(db,token)).length,1);
  assert.equal(await scalar(db,"select wif_friend_invitation_complete($1,$2,'delivered')",[id,old]),false);
  await db.query('update devices set user_id=$1 where id=$2',[alice,d]);
  assert.equal(await prepare(db,id,token),null);
  await scalar(db,"select wif_friend_invitation_complete($1,$2,'retry','timeout',null,true)",[id,token]);
  assert.equal(await scalar(db,'select disabled_at from devices where id=$1',[d]),null);
  await db.query('update devices set user_id=$1 where id=$2',[bob,d]);
  await db.exec('update friend_invitation_deliveries set attempts=5,available_at=now()');
  assert.equal((await claim(db,crypto.randomUUID())).length,0);
  assert.equal(await scalar(db,'select status from friend_invitation_deliveries where id=$1',[id]),'failed');
 }finally{await db.close();}
});

test('installing friend notification support does not backfill old pending requests',async()=>{
 const db=await setup(true);try {
  await invite(db);await device(db);
  await db.exec(await readFile(new URL('../migrations/20260915030000_friend_invitation_notifications.sql',import.meta.url),'utf8'));
  assert.equal(await scalar(db,'select count(*)::int from friend_invitation_alerts'),0);
  assert.equal((await claim(db,crypto.randomUUID())).length,0);
 }finally{await db.close();}
});

test('invitation wake-up is post-commit background work, private and non-blocking on failure',async()=>{
 const tasks=[],calls=[];
 const options={baseURL:'https://example.supabase.co',secret:'test-only',waitUntil:task=>tasks.push(task),
  fetcher:async(url,init)=>{calls.push({url:String(url),init});return new Response('{}');}};
 assert.equal(wakeInvitationWorker(options),true);await Promise.all(tasks);
 assert.equal(calls[0].url,'https://example.supabase.co/functions/v1/push-worker');
 assert.equal(calls[0].init.headers.Authorization,'Bearer test-only');
 assert.deepEqual(JSON.parse(calls[0].init.body),{action:'invitations'});
 assert.equal(wakeInvitationWorker({...options,secret:undefined}),false);
 assert.equal(wakeInvitationWorker({...options,baseURL:'not a URL'}),false);
 tasks.length=0;
 assert.equal(wakeInvitationWorker({...options,fetcher:()=>{throw new Error('unavailable');}}),true);
 await assert.doesNotReject(Promise.all(tasks));
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {deliverTripInvitations} from '../functions/_shared/trip-invitations.mjs';
const alice='10000000-0000-0000-0000-000000000001',bob='10000000-0000-0000-0000-000000000002';
async function scalar(db,sql,args=[]){return Object.values((await db.query(sql,args)).rows[0])[0];}
async function setup(){
 const db=new PGlite();
 await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role');
 for(const f of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort())await db.exec(await readFile(new URL('../migrations/'+f,import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await scalar(db,"select wif_trip_create($1,'invite-test','Tokyo together','HND',current_date,current_date+4)",[alice]);
 return db;
}
const invite=db=>scalar(db,"select wif_trip_invite($1,'invite-test','bob')",[alice]);
const device=(db,owner=bob)=>scalar(db,"select wif_register_push_device($1,$2,$3,'v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend')",[owner,crypto.randomUUID(),crypto.randomUUID().replaceAll('-','').repeat(2)]);
const claim=(db,token)=>scalar(db,'select wif_trip_invitation_claim($1)',[token]);
const prepare=(db,id,token)=>scalar(db,'select wif_trip_invitation_prepare($1,$2)',[id,token]);

test('invitation outbox is transactional, account-bound, idempotent, per device and privacy-aware',async()=>{
 const db=await setup();try{
  const i=await invite(db),again=await invite(db);assert.equal(i.id,again.id);
  assert.equal(await scalar(db,'select count(*)::int from trip_invitation_alerts'),1);
  assert.equal((await claim(db,crypto.randomUUID())).length,0); // In-app invite survives no device/no permission.
  assert.equal((await scalar(db,'select wif_trip_invitation_list($1)',[bob])).length,1);
  await device(db);await device(db);await device(db,alice);
  const token=crypto.randomUUID(),jobs=await claim(db,token);assert.equal(jobs.length,2);
  assert.equal((await claim(db,crypto.randomUUID())).length,0);
  const p=await prepare(db,jobs[0].delivery_id,token);
  assert.equal(p.deep_link,`whereismyfriend://trips/join/${i.id}`);
  assert.match(p.body,/Tokyo together/);assert.equal(p.title,'Trip invitation');
  assert.equal(await prepare(db,jobs[0].delivery_id,crypto.randomUUID()),null);
  await db.query('update user_sharing_settings set notification_preview_enabled=false where user_id=$1',[bob]);
  assert.equal((await prepare(db,jobs[0].delivery_id,token)).body,'You have a new trip invitation. Open Across Us to review.');
  await scalar(db,"select wif_trip_invitation_complete($1,$2,'delivered')",[jobs[0].delivery_id,token]);
  assert.equal(await scalar(db,"select wif_trip_invitation_complete($1,$2,'retry')",[jobs[0].delivery_id,token]),false);
  assert.equal((await claim(db,crypto.randomUUID())).length,0);
  await db.exec('set role authenticated');
  await assert.rejects(db.query('select * from trip_invitation_deliveries'),/permission denied/);
  await assert.rejects(db.query('select wif_trip_invitation_claim($1)',[crypto.randomUUID()]),/permission denied/);
 }finally{await db.close();}
});

test('revoke, re-invite, block, expiry, acceptance and device reassignment cancel stale deliveries',async()=>{
 const db=await setup();try{
  const d=await device(db);let i=await invite(db),token=crypto.randomUUID(),jobs=await claim(db,token);
  await scalar(db,'select wif_trip_dismiss_invitation($1,$2,true)',[alice,i.id]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  const replacement=await invite(db);assert.notEqual(replacement.id,i.id);
  token=crypto.randomUUID();jobs=await claim(db,token);assert.equal(jobs.length,1);
  await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[bob,alice]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  await db.exec('delete from user_blocks');
  await db.query('update devices set user_id=$1 where id=$2',[alice,d]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  await db.query('update devices set user_id=$1 where id=$2',[bob,d]);
  await db.query("update trip_invitations set expires_at=now()-interval '1 second' where id=$1",[replacement.id]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
  i=await invite(db);token=crypto.randomUUID();jobs=await claim(db,token);
  await scalar(db,'select wif_trip_accept_invitation($1,$2)',[bob,i.id]);
  assert.equal(await prepare(db,jobs[0].delivery_id,token),null);
 }finally{await db.close();}
});

test('invitation delivery retries are leased, capped, and cannot disable a new device owner',async()=>{
 const db=await setup();try{
  const d=await device(db);await invite(db);
  let token=crypto.randomUUID(),jobs=await claim(db,token),id=jobs[0].delivery_id;
  assert.equal(await scalar(db,"select wif_trip_invitation_complete($1,$2,'delivered')",[id,crypto.randomUUID()]),false);
  await db.query("update trip_invitation_deliveries set claimed_at=now()-interval '3 minutes' where id=$1",[id]);
  assert.equal(await prepare(db,id,token),null);
  const oldToken=token;token=crypto.randomUUID();assert.equal((await claim(db,token)).length,1);
  assert.equal(await scalar(db,"select wif_trip_invitation_complete($1,$2,'delivered')",[id,oldToken]),false);
  await db.query('update devices set user_id=$1 where id=$2',[alice,d]);
  await scalar(db,"select wif_trip_invitation_complete($1,$2,'retry','provider timeout',null,true)",[id,token]);
  assert.equal(await scalar(db,'select disabled_at from devices where id=$1',[d]),null);
  await db.query('update devices set user_id=$1 where id=$2',[bob,d]);
  await db.query("update trip_invitation_deliveries set attempts=5,available_at=now() where id=$1",[id]);
  assert.equal((await claim(db,crypto.randomUUID())).length,0);
  assert.equal(await scalar(db,'select status from trip_invitation_deliveries where id=$1',[id]),'failed');
 }finally{await db.close();}
});

test('worker revalidates before sending and never sends a revoked invitation',async()=>{
 const calls=[],sent=[];
 const database={rpc:async(name,args)=>{
  calls.push({name,args});
  if(name==='wif_trip_invitation_claim')return {data:[{delivery_id:'valid'},{delivery_id:'revoked'}]};
  if(name==='wif_trip_invitation_prepare')return {data:args.p_id==='valid'?{delivery_id:'valid',deep_link:'whereismyfriend://trips/join/id'}:null};
  return {data:true};
 }};
 const outcomes=await deliverTripInvitations(database,'lease',async delivery=>{sent.push(delivery);return 'delivered';});
 assert.deepEqual(outcomes,['delivered','failed']);assert.equal(sent.length,1);assert.equal(sent[0].kind,'trip-invitation');
 assert.ok(calls.some(c=>c.name==='wif_trip_invitation_complete'&&c.args.p_id==='revoked'));
});

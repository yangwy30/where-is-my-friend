import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';
const owner='10000000-0000-0000-0000-000000000001', member='10000000-0000-0000-0000-000000000002';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function fixture() {
 const db=new PGlite();
 await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role');
 for(const file of (await readdir(new URL('../migrations',import.meta.url))).filter(x=>x.endsWith('.sql')).sort()) {
  await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
 }
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await scalar(db,"select wif_trip_create($1,'lifecycle','Trip','LAX','2026-10-01','2026-10-04')",[owner]);
 const username=await scalar(db,'select username from app_users where id=$1',[member]);
 const invite=await scalar(db,"select wif_trip_invite($1,'lifecycle',$2)",[owner,username]);
 await scalar(db,'select wif_trip_accept_invitation($1,$2)',[member,invite.id]);
 for(const [actor,id] of [[owner,'owner-flight'],[member,'member-flight']])
  await scalar(db,"select wif_trip_add_flight($1,'lifecycle',$2,'UA353','2026-10-01','outbound')",[actor,id]);
 const snapshot=()=>scalar(db,"select wif_trip_snapshot($1,'lifecycle')",[owner]);
 const plan=await snapshot();
 const person=plan.participants.find(p=>p.user_id===member).id;
 const act=(actor,action,revision=plan.revision,participant=null,request=randomUUID())=>
  scalar(db,"select wif_trip_lifecycle($1,'lifecycle',$2,$3,$4,$5)",[actor,action,request,revision,participant]);
 return {db,act,snapshot,plan,person,invite,username};
}

test('members leave with their flights and alerts; cannot read or rejoin via old invite; lost response retry is safe',async()=>{
 const {db,act,person,invite,username,snapshot}=await fixture();
 try {
  const request=randomUUID();
  const result=await act(member,'leave',null,null,request);assert.equal(result.success,true);assert.equal(result.trip,null);
  assert.equal((await act(member,'leave',null,null,request)).success,true);
  await assert.rejects(scalar(db,"select wif_trip_snapshot($1,'lifecycle')",[member]),/access denied/);
  await assert.rejects(scalar(db,'select wif_trip_accept_invitation($1,$2)',[member,invite.id]),/access denied/);
  await assert.rejects(scalar(db,"select wif_trip_add_flight($1,'lifecycle','retry-flight','UA353','2026-10-01','outbound')",[member]),/access denied/);
  const current=await snapshot();assert.deepEqual(current.flights.map(f=>f.id),['owner-flight']);
  assert.equal(current.participants.some(p=>p.id===person),false);
  const replacement=await scalar(db,"select wif_trip_invite($1,'lifecycle',$2)",[owner,username]);
  assert.notEqual(replacement.id,invite.id);
  const rejoined=await scalar(db,'select wif_trip_accept_invitation($1,$2)',[member,replacement.id]);
  assert.equal(rejoined.participants.length,2);assert.equal(rejoined.flights.length,1);
 } finally {await db.close();}
});

test('only creator can remove members; stale revisions and owner removal are rejected',async()=>{
 const {db,act,person,plan,snapshot}=await fixture();
 try {
  const ownerPerson=plan.participants.find(p=>p.user_id===owner).id;
  await assert.rejects(act(member,'removeMember',plan.revision,ownerPerson),/access denied/);
  await assert.rejects(act(owner,'removeMember',plan.revision,ownerPerson),/access denied/);
  await assert.rejects(act(owner,'leave',null),/creator must/);
  await assert.rejects(act(owner,'removeMember',plan.revision-1,person),/conflict/);
  await assert.rejects(act(owner,'removeMember',plan.revision,randomUUID()),/access denied/);
  const result=await act(owner,'removeMember',plan.revision,person);
  assert.equal(result.trip.participants.length,1);assert.equal(result.trip.flights[0].id,'owner-flight');
  assert.ok(result.trip.revision>plan.revision);
  await assert.rejects(scalar(db,"select wif_trip_check_in($1,'lifecycle','landed')",[member]),/access denied/);
  assert.equal((await snapshot()).flights.length,1);
 } finally {await db.close();}
});

test('cancellation archives and preserves records while blocking legacy and current writes, invites, lookup, tracking and pushes',async()=>{
 const {db,act,plan,person,username}=await fixture();
 try {
  await assert.rejects(act(member,'cancel'),/access denied/);
  const cancelled=await act(owner,'cancel');assert.ok(cancelled.trip.cancelled_at);assert.ok(cancelled.trip.completed_at);
  assert.equal(cancelled.trip.flights.length,2);assert.equal(cancelled.trip.participants.length,2);
  for(const [sql,args] of [
   ["select wif_trip_complete($1,'lifecycle',false)",[owner]],
   ["select wif_trip_update($1,'lifecycle','Oops','LAX','2026-10-01','2026-10-04')",[owner]],
   ["select wif_trip_preferences($1,'lifecycle',true)",[member]],
   ["select wif_trip_check_in($1,'lifecycle','landed')",[member]],
   ["select wif_trip_delete_flight($1,'lifecycle','member-flight')",[member]],
   ["select wif_trip_flight_lookup_begin($1,'lifecycle','UA353','2026-10-01')",[member]],
   ["select wif_trip_invite($1,'lifecycle',$2)",[owner,username]],
   ["select wif_trip_mutate($1,'lifecycle','details',$2,$3)",[owner,{name:'Oops',destinationAirport:'LAX',startDate:'2026-10-01',endDate:'2026-10-04'},cancelled.trip.revision]],
  ]) await assert.rejects(scalar(db,sql,args),/cancelled/);
  assert.equal(await scalar(db,"select count(*)::int from flights f where wif_trip_tracking_due(f)"),0);
  assert.deepEqual(await scalar(db,'select wif_trip_claim_deliveries($1)',[randomUUID()]),[]);
  assert.deepEqual(await scalar(db,'select wif_trip_invitation_claim($1)',[randomUUID()]),[]);
  const left=await act(member,'leave',null);assert.equal(left.trip,null);
  const fresh=await scalar(db,"select wif_trip_snapshot($1,'lifecycle')",[owner]);
  assert.equal((await act(owner,'delete',fresh.revision)).success,true);
 } finally {await db.close();}
});

test('deletion cascades only this trip and can be replayed only by its original actor/request',async()=>{
 const {db,act,plan}=await fixture();
 try {
  await scalar(db,"select wif_trip_create($1,'other-trip','Other','JFK','2026-10-01','2026-10-04')",[owner]);
  await assert.rejects(act(member,'delete'),/access denied/);
  const request=randomUUID();assert.equal((await act(owner,'delete',plan.revision,null,request)).success,true);
  assert.equal((await act(owner,'delete',plan.revision,null,request)).success,true);
  await assert.rejects(act(member,'delete',plan.revision,null,request),/access denied/);
  await assert.rejects(act(owner,'cancel',plan.revision,null,request),/conflict/);
  for(const table of ['trips','trip_members','participants','flights','notes','trip_invitations','trip_invitation_alerts']) {
   assert.equal(await scalar(db,`select count(*)::int from ${table} where ${table==='trips'?'id':'trip_id'}='lifecycle'`),0);
  }
  assert.equal((await scalar(db,"select wif_trip_snapshot($1,'other-trip')",[owner])).id,'other-trip');
  for(const role of ['anon','authenticated']) {
   await db.exec(`set role ${role}`);
   await assert.rejects(act(owner,'delete'),/permission denied/);
   await assert.rejects(db.query('select * from trip_lifecycle_receipts'),/permission denied/);
   await db.exec('reset role');
  }
 } finally {await db.close();}
});

test('cancelling expires pending invitations and invalidates already-claimed invitation deliveries',async()=>{
 const {db,act}=await fixture();
 try {
  const recipient='10000000-0000-0000-0000-000000000003';
  await db.query("insert into app_users(id,username,display_name,is_debug) values($1,'carol','Carol',true)",[recipient]);
  await db.query('insert into user_sharing_settings(user_id) values($1)',[recipient]);
  await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend')",[recipient,randomUUID(),randomUUID().replaceAll('-','').repeat(2)]);
  const invitation=await scalar(db,"select wif_trip_invite($1,'lifecycle','carol')",[owner]);
  const token=randomUUID();
  const claims=await scalar(db,'select wif_trip_invitation_claim($1)',[token]);assert.equal(claims.length,1);
  assert.ok(await scalar(db,'select wif_trip_invitation_prepare($1,$2)',[claims[0].delivery_id,token]));
  await act(owner,'cancel');
  assert.equal(await scalar(db,'select wif_trip_invitation_prepare($1,$2)',[claims[0].delivery_id,token]),null);
  assert.deepEqual(await scalar(db,'select wif_trip_invitation_list($1)',[recipient]),[]);
  await assert.rejects(scalar(db,'select wif_trip_accept_invitation($1,$2)',[recipient,invitation.id]),/access denied/);
 } finally {await db.close();}
});

test('leaving, removing and cancelling invalidate flight alerts already claimed for the affected member',async()=>{
 for(const action of ['leave','removeMember','cancel']) {
  const {db,act,person,plan}=await fixture();
  try {
   await scalar(db,"select wif_trip_preferences($1,'lifecycle',true)",[member]);
   await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend')",[member,randomUUID(),randomUUID().replaceAll('-','').repeat(2)]);
   await db.exec("update flights set candidate_id='candidate',status='landed' where id='owner-flight'");
   const event=await scalar(db,"insert into trip_flight_events(flight_id,candidate_id,kind) values('owner-flight','candidate','landed') returning id");
   await db.query('insert into trip_flight_deliveries(event_id,device_id,recipient_id) select $1,id,user_id from devices where user_id=$2',[event,member]);
   const token=randomUUID();const claims=await scalar(db,'select wif_trip_claim_deliveries($1)',[token]);assert.equal(claims.length,1);
   assert.ok(await scalar(db,'select wif_trip_prepare_delivery($1,$2)',[claims[0].delivery_id,token]));
   await act(action==='leave'?member:owner,action,action==='leave'?null:plan.revision,action==='removeMember'?person:null);
   assert.equal(await scalar(db,'select wif_trip_prepare_delivery($1,$2)',[claims[0].delivery_id,token]),null);
   assert.deepEqual(await scalar(db,'select wif_trip_claim_deliveries($1)',[randomUUID()]),[]);
  } finally {await db.close();}
 }
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const alice='10000000-0000-0000-0000-000000000001', bob='10000000-0000-0000-0000-000000000002';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function setup() {
 const db=new PGlite();
 await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role;');
 for(const file of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort()) await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await scalar(db,"select wif_send_friend_request($1,'bob')",[alice]);
 const request=(await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests[0].id;
 return {db,request};
}
test('sender withdrawal clears both inboxes and queued push deliveries; retry is harmless',async()=>{
 const {db,request}=await setup();try{
  await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:nonce:ciphertext','production','com.yangwy30.whereismyfriend','whereismyfriend')",[bob,'30000000-0000-0000-0000-000000000001','c'.repeat(64)]);
  const token=crypto.randomUUID();
  const [delivery]=await scalar(db,'select wif_friend_invitation_claim($1)',[token]);
  assert.ok(delivery);
  assert.equal(await scalar(db,'select count(*)::int from friend_invitation_alerts'),1);
  assert.equal(await scalar(db,'select count(*)::int from friend_invitation_deliveries'),1);
  const snapshot=await scalar(db,'select wif_cancel_friend_request($1,$2)',[alice,request]);
  assert.equal(snapshot.friendRequests.length,0);
  assert.equal((await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests.length,0);
  assert.equal(await scalar(db,'select count(*)::int from friend_invitation_alerts'),0);
  assert.equal(await scalar(db,'select count(*)::int from friend_invitation_deliveries'),0);
  assert.equal(await scalar(db,'select wif_friend_invitation_prepare($1,$2)',[delivery.delivery_id,token]),null);
  assert.equal((await scalar(db,'select wif_cancel_friend_request($1,$2)',[alice,request])).friends.length,0);
  await assert.rejects(scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]));
  await scalar(db,"select wif_send_friend_request($1,'bob')",[alice]);
  assert.equal((await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests.length,1);
 }finally{await db.close()}
});
test('recipient and unrelated caller cannot withdraw a pending invitation',async()=>{
 const {db,request}=await setup();try{
  await assert.rejects(scalar(db,'select wif_cancel_friend_request($1,$2)',[bob,request]));
  await assert.rejects(scalar(db,'select wif_cancel_friend_request($1,$2)',['10000000-0000-0000-0000-000000000003',request]));
  assert.equal((await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests.length,1);
  for(const role of ['anon','authenticated']) assert.equal(await scalar(db,"select has_function_privilege($1,'public.wif_cancel_friend_request(uuid,uuid)','EXECUTE')",[role]),false);
  assert.equal(await scalar(db,"select has_function_privilege('service_role','public.wif_cancel_friend_request(uuid,uuid)','EXECUTE')"),true);
 }finally{await db.close()}
});
test('accepting before withdrawal preserves the friendship and its sharing preferences',async()=>{
 const {db,request}=await setup();try{
  await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]);
  await assert.rejects(scalar(db,'select wif_cancel_friend_request($1,$2)',[alice,request]));
  assert.equal((await scalar(db,'select wif_snapshot($1)',[alice])).friends.length,1);
  assert.equal((await scalar(db,'select wif_snapshot($1)',[bob])).friends.length,1);
  assert.equal(await scalar(db,'select count(*)::int from sharing_preferences'),2);
 }finally{await db.close()}
});

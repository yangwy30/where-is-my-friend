import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const alice='10000000-0000-0000-0000-000000000001',bob='10000000-0000-0000-0000-000000000002';
const a='a7160000-0000-0000-0000-000000000001',b='a7160000-0000-0000-0000-000000000002';
const migration=new URL('../migrations/20260916010000_travel_identity_and_retry.sql',import.meta.url);
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function setup(legacy=false) {
 const db=new PGlite();
 await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role;');
 for(const file of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort()) {
  if(legacy&&file.startsWith('20260916010000')) continue;
  await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
 }
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await scalar(db,"select wif_send_friend_request($1,'bob')",[alice]);
 const request=(await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests[0].id;
 await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]);
 return db;
}
const save=(db,owner,id,area,audience,revision=0)=>scalar(db,
 "select wif_travel_save_v2($1,$2,'New York','US',$3,'America/New_York',current_date+2,current_date+5,$4::uuid[],$5,$6,false)",
 [owner,id,area,audience,owner===alice,revision]);
const overlap=async db=>(await scalar(db,'select wif_travel_snapshot($1)',[alice])).overlaps;
async function ready(db) {
 await save(db,alice,a,'NY',[bob]);await save(db,bob,b,'NY',[alice]);
 await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend')",[alice,crypto.randomUUID(),'a'.repeat(64)]);
}

test('future identity matches supported aliases but never merges different or missing states',async()=>{
 const db=await setup();try {
  await save(db,alice,a,'NY',[bob]);await save(db,bob,b,'New York',[alice]);
  assert.equal((await overlap(db)).length,1);
  await save(db,bob,b,'NJ',[alice],1);assert.equal((await overlap(db)).length,0);
  await save(db,alice,a,'',[bob],1);await save(db,bob,b,'',[alice],2);
  assert.equal((await overlap(db)).length,0);
 }finally{await db.close();}
});

test('identity upgrade preserves sent state so a migrated overlap is not pushed again',async()=>{
 const db=await setup(true);try {
  await ready(db);const oldID=(await overlap(db))[0].id;
  const token=crypto.randomUUID();const jobs=await scalar(db,'select wif_travel_claim($1)',[token]);
  await scalar(db,"select wif_travel_complete($1,$2,'delivered',false)",[jobs[0].delivery_id,token]);
  await db.exec(await readFile(migration,'utf8'));
  const newID=(await overlap(db))[0].id;assert.notEqual(newID,oldID);
  assert.equal(await scalar(db,'select status from upcoming_deliveries where overlap_id=$1',[newID]),'delivered');
  assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]),[]);
 }finally{await db.close();}
});

test('identity upgrade carries pending attempts and backoff without dropping queued work',async()=>{
 const db=await setup(true);try {
  await ready(db);const token=crypto.randomUUID();const jobs=await scalar(db,'select wif_travel_claim($1)',[token]);
  await scalar(db,"select wif_travel_complete($1,$2,'retry',false)",[jobs[0].delivery_id,token]);
  await db.exec(await readFile(migration,'utf8'));
  const id=(await overlap(db))[0].id;
  const row=(await db.query('select status,attempts,available_at>now() waiting from upcoming_deliveries where overlap_id=$1',[id])).rows[0];
  assert.deepEqual(row,{status:'pending',attempts:1,waiting:true});
  assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]),[]);
  await db.query('update upcoming_deliveries set available_at=now() where overlap_id=$1',[id]);
  const next=await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]);assert.equal(next.length,1);
 }finally{await db.close();}
});

test('fifth attempt keeps its live lease; privacy revocation still cancels it immediately',async()=>{
 const db=await setup();try {
  await ready(db);await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]);
  await db.exec("update upcoming_deliveries set attempts=4,claimed_at=null,claim_token=null,available_at=now()");
  const token=crypto.randomUUID(),jobs=await scalar(db,'select wif_travel_claim($1)',[token]);
  assert.equal(jobs.length,1);
  assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]),[]);
  assert.ok(await scalar(db,'select wif_travel_prepare($1,$2)',[jobs[0].delivery_id,token]));
  await save(db,alice,a,'NY',[],1);
  await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]);
  assert.equal(await scalar(db,'select wif_travel_prepare($1,$2)',[jobs[0].delivery_id,token]),null);
  assert.equal(await scalar(db,'select status from upcoming_deliveries where id=$1',[jobs[0].delivery_id]),'failed');
 }finally{await db.close();}
});

test('expired final lease is retired instead of receiving a sixth attempt',async()=>{
 const db=await setup();try {
  await ready(db);await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]);
  await db.exec("update upcoming_deliveries set attempts=5,claimed_at=now()-interval '3 minutes',available_at=now()");
  assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]),[]);
  assert.equal(await scalar(db,'select status from upcoming_deliveries'),'failed');
 }finally{await db.close();}
});

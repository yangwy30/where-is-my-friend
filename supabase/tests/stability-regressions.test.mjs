import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {pushRoute} from '../functions/_shared/push-routing.mjs';
const alice='10000000-0000-0000-0000-000000000001',bob='10000000-0000-0000-0000-000000000002';
async function scalar(db,sql,args=[]) {return Object.values((await db.query(sql,args)).rows[0])[0];}
async function setup(stopBeforeFix=false) {
 const db=new PGlite();
 await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role;');
 for(const file of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort()) {
  if(stopBeforeFix && file >= '20260915020000') continue;
  await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
 }
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await scalar(db,"select wif_send_friend_request($1,'bob')",[alice]);
 const request=(await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests[0].id;
 await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]);
 return db;
}
const update=(db,id,city,area)=>scalar(db,"select wif_update_presence_v2($1,$2,'US','foregroundLocation',now(),$3)",[id,city,area]);

test('same-name cities in different states or missing state never emit same-city events',async()=>{
 const db=await setup();try {
  await update(db,alice,'Pasadena','CA');await update(db,bob,'Pasadena','TX');
  assert.equal(await scalar(db,'select count(*)::int from colocation_events'),0);
  await update(db,bob,'Pasadena',null);
  assert.equal(await scalar(db,'select count(*)::int from colocation_events'),0);
  await update(db,bob,'Pasadena','California');
  assert.equal(await scalar(db,'select count(*)::int from colocation_events'),2);
  assert.equal(await scalar(db,"select wif_presence_key('New York','US','New York')"),'v2|US|ny|newyork');
 } finally {await db.close();}
});

test('24h freshness gates new events without closing a stay or inventing a return',async()=>{
 const db=await setup();try {
  await update(db,alice,'New York','NY');await update(db,bob,'New York','NY');
  const events=await scalar(db,'select count(*)::int from colocation_events');
  for(const age of [3,25]) {
   await db.query("update current_presence set client_updated_at=now()-make_interval(hours=>$1)",[age]);
   await scalar(db,'select wif_evaluate_user($1)',[alice]);
   assert.equal(await scalar(db,'select count(*)::int from colocation_sessions where left_at is null'),2);
  }
  await update(db,alice,'New York','NY');await update(db,bob,'New York','NY');
  assert.equal(await scalar(db,'select count(*)::int from colocation_events'),events);
  await update(db,bob,'Seattle','WA');
  assert.equal(await scalar(db,'select count(*)::int from colocation_sessions where left_at is null'),0);
 } finally {await db.close();}
});

test('identity migration and first upgraded samples never replay an existing same-city arrival',async()=>{
 const db=await setup(true);try {
  await update(db,alice,'New York',null);await update(db,bob,'New York',null);
  const before=await scalar(db,'select count(*)::int from colocation_events');assert.equal(before,2);
  await db.exec(await readFile(new URL('../migrations/20260915020000_presence_identity_and_freshness.sql',import.meta.url),'utf8'));
  assert.equal(await scalar(db,'select count(*)::int from colocation_events'),before);
  await update(db,alice,'New York','NY');await update(db,bob,'New York','New York');
  assert.equal(await scalar(db,'select count(*)::int from colocation_events'),before);
  assert.equal(await scalar(db,'select count(*)::int from colocation_sessions where left_at is null'),2);
 } finally {await db.close();}
});

test('production APNs routes the main and staging apps to distinct allowlisted topics',()=>{
 const main='com.yangwy30.whereismyfriend',stage=main+'.staging';
 for(const environment of ['production','sandbox']) {
  assert.equal(pushRoute({environment,bundleID:main}).bundleID,main);
  assert.equal(pushRoute({environment,bundleID:stage}).bundleID,stage);
  assert.equal(pushRoute({environment,bundleID:stage}).urlScheme,'whereismyfriend-staging');
 }
 assert.throws(()=>pushRoute({environment:'production',bundleID:'attacker.app'}));
 assert.throws(()=>pushRoute({environment:'other',bundleID:main}));
 assert.equal(pushRoute({environment:'production'},key=>key==='APNS_PRODUCTION_BUNDLE_ID'?main:undefined).bundleID,main);
});

test('queued same-city delivery is checked again after freshness or visibility changes',async()=>{
 const db=await setup();try {
  await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:nonce:ciphertext','production','com.yangwy30.whereismyfriend','whereismyfriend')",
   [alice,'30000000-0000-0000-0000-000000000001','a'.repeat(64)]);
  await update(db,alice,'New York','NY');await update(db,bob,'New York','NY');
  const token=crypto.randomUUID();
  const rows=(await db.query('select * from wif_claim_notification_deliveries(20,$1)',[token])).rows;
  assert.equal(rows.length,1);
  const allowed=()=>scalar(db,'select wif_colocation_delivery_allowed($1,$2)',[rows[0].delivery_id,token]);
  assert.equal(await allowed(),true);
  await db.query("update current_presence set client_updated_at=now()-interval '25 hours' where user_id=$1",[bob]);
  assert.equal(await allowed(),false);
  await update(db,bob,'New York','NY');assert.equal(await allowed(),true);
  await scalar(db,'select wif_set_sharing_preferences($1,false,false,true)',[bob]);
  assert.equal(await allowed(),false);
  await db.exec('set role authenticated');
  await assert.rejects(allowed(),/permission denied/);
 } finally {await db.close();}
});

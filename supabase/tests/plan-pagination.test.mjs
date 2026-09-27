import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const a='10000000-0000-0000-0000-000000000001',b='10000000-0000-0000-0000-000000000002';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function fixture(){
 const db=new PGlite();await db.exec('create schema auth;create table auth.users(id uuid primary key,email text);create role anon;create role authenticated;create role service_role');
 for(const f of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort())await db.exec(await readFile(new URL('../migrations/'+f,import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
 await scalar(db,"select wif_send_friend_request($1,'bob')",[a]);
 const invitation=(await scalar(db,'select wif_snapshot($1)',[b])).friendRequests[0].id;
 await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[b,invitation]);
 await db.query(`insert into travel_plans(id,owner_id,city,country_code,region,time_zone,city_key,start_day,end_day,allow_friend_browsing)
 select gen_random_uuid(),$1,'Tokyo','JP','Tokyo','Asia/Tokyo','tokyo',current_date+(n%4),current_date+10,true from generate_series(1,75)n`,[a]);
 await db.query('insert into travel_plan_audience(plan_id,friend_id,friendship_id) select id,$1,$2 from travel_plans',[b,invitation]);
 const page=(cursor=null,friend=null,id=null)=>scalar(db,'select wif_friend_plan_page($1,50,$2,$3,$4,$5,$6)',[b,cursor?.startDay??null,cursor?.id??null,cursor?.version??null,friend,id]);
 return {db,page};
}
test('overview preserves badges/counts while cursor pages return every plan once in stable order',async()=>{
 const {db,page}=await fixture();try{
  const legacy=await scalar(db,'select wif_travel_snapshot($1)',[b]);assert.equal(legacy.friendPlans.length,75);
  const own=await scalar(db,'select wif_travel_core_snapshot($1)',[a]);assert.equal(own.plans.length,75);assert.equal(own.includesOwnPlans,true);
  const light=await scalar(db,'select wif_travel_overview($1)',[a]);assert.deepEqual(light.plans,[]);assert.equal(light.includesOwnPlans,false);
  const overview=await scalar(db,'select wif_travel_overview($1)',[b]);assert.equal(overview.friendPlans,undefined);
  assert.equal(overview.friendPlanSummaries.length,1);assert.equal(overview.friendPlanSummaries[0].count,75);
  const one=await page(),two=await page(one.nextCursor);assert.equal(one.items.length,50);assert.equal(two.items.length,25);assert.equal(two.nextCursor,null);
  assert.deepEqual([...one.items,...two.items],legacy.friendPlans);assert.equal(new Set([...one.items,...two.items].map(x=>x.id)).size,75);
  assert.deepEqual(overview.friendPlanSummaries[0].nextPlan,one.items[0]);
  assert.equal((await page(null,a,two.items[0].id)).items[0].id,two.items[0].id);
  assert.equal((await page(null,b)).items.length,0);
 }finally{await db.close();}
});
test('changes between pages force a restart and consent is always checked for pages and detail',async()=>{
 const {db,page}=await fixture();try{
  const first=await page();
  await db.query('update travel_plans set allow_friend_browsing=false where id=$1',[first.items[0].id]);
  const changed=await page(first.nextCursor);assert.equal(changed.resetRequired,true);assert.deepEqual(changed.items,[]);
  assert.equal((await page(null,null,first.items[0].id)).items.length,0);
  await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[b,a]);
  assert.equal((await page()).items.length,0);
  assert.equal((await scalar(db,'select wif_travel_overview($1)',[b])).friendPlanSummaries.length,0);
  assert.equal((await page(first.nextCursor)).resetRequired,true);
 }finally{await db.close();}
});
test('private paging helpers reject direct client access and oversized pages',async()=>{
 const {db}=await fixture();try{
  await assert.rejects(scalar(db,'select wif_friend_plan_page($1,51)',[b]),/Invalid page/);
  await assert.rejects(scalar(db,'select wif_friend_plan_page($1,50,current_date,null)',[b]),/Invalid page/);
  await db.exec('set role authenticated');
  await assert.rejects(scalar(db,'select wif_friend_plan_page($1)',[b]),/permission denied/);
  await assert.rejects(db.query('select * from wif_visible_friend_plan_rows'),/permission denied/);
 }finally{await db.close();}
});

test('home overlap preview keeps the total and detail outside the preview; legacy stays complete',async()=>{
 const {db}=await fixture();try{
  const friendship=(await db.query("select id from friendships where status='accepted'")).rows[0].id;
  const plan=(await db.query(`insert into travel_plans(id,owner_id,city,country_code,region,time_zone,city_key,start_day,end_day)
   values(gen_random_uuid(),$1,'Tokyo','JP','Tokyo','Asia/Tokyo','tokyo',current_date,current_date+10) returning id`,[b])).rows[0].id;
  await db.query('insert into travel_plan_audience(plan_id,friend_id,friendship_id) values($1,$2,$3)',[plan,a,friendship]);
  const overview=await scalar(db,'select wif_travel_overview($1)',[b]);
  const full=await scalar(db,'select wif_travel_overlap_snapshot($1)',[b]);
  assert.equal(overview.overlaps.length,3);assert.equal(overview.overlapCount,4);assert.equal(overview.includesAllOverlaps,false);
  assert.equal(full.overlaps.length,4);assert.equal(full.includesAllOverlaps,true);assert.equal(full.overlapVersion,overview.overlapVersion);
  assert.deepEqual(full.overlaps.slice(0,3),overview.overlaps);
  const target=full.overlaps[3];
  assert.deepEqual((await scalar(db,'select wif_travel_overlap_snapshot($1,null,$2)',[b,target.id])).overlaps,[target]);
  assert.equal((await scalar(db,'select wif_travel_snapshot($1)',[b])).overlaps.length,4);
  await db.query("update app_users set display_name='New name' where id=$1",[a]);
  assert.notEqual((await scalar(db,'select wif_travel_overview($1)',[b])).overlapVersion,overview.overlapVersion);
  await db.query('delete from travel_plan_audience where plan_id=$1',[plan]);
  const revoked=await scalar(db,'select wif_travel_overlap_snapshot($1,null,$2)',[b,target.id]);
  assert.equal(revoked.overlapCount,0);assert.deepEqual(revoked.overlaps,[]);assert.notEqual(revoked.overlapVersion,overview.overlapVersion);
  await db.query('insert into travel_plan_audience(plan_id,friend_id,friendship_id) values($1,$2,$3)',[plan,a,friendship]);
  await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[a,b]);
  assert.equal((await scalar(db,'select wif_travel_overview($1)',[b])).overlapCount,0);
  await db.query('delete from user_blocks');
  await db.query("update friendships set status='declined' where id=$1",[friendship]);
  assert.deepEqual((await scalar(db,'select wif_travel_overlap_snapshot($1,null,$2)',[b,target.id])).overlaps,[]);
  await db.query("update friendships set status='accepted' where id=$1",[friendship]);
  await db.query('update travel_plans set start_day=current_date-10,end_day=current_date-5 where id=$1',[plan]);
  assert.equal((await scalar(db,'select wif_travel_overview($1)',[b])).overlapCount,0);
  await db.query('delete from travel_plans where id=$1',[plan]);
  assert.equal((await scalar(db,'select wif_travel_overview($1)',[b])).overlapCount,0);
 }finally{await db.close();}
});
test('overlap helpers validate inputs and cannot be called by untrusted clients',async()=>{
 const {db}=await fixture();try{
  await assert.rejects(scalar(db,'select wif_travel_overlap_snapshot($1,4)',[b]),/Invalid overlap/);
  await assert.rejects(scalar(db,"select wif_travel_overlap_snapshot($1,null,'bad')",[b]),/Invalid overlap/);
  await db.exec('set role authenticated');
  await assert.rejects(scalar(db,'select wif_travel_overlap_snapshot($1)',[b]),/permission denied/);
 }finally{await db.close();}
});

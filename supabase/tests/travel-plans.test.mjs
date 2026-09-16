import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {travelPlanInput,deliverUpcoming,normalizeAPNsPrivateKey} from '../functions/_shared/travel-plans.mjs';

test('APNs key formatting accepts pasted PEM, escaped newlines, quoted and base64 values without inventing a key',()=>{
    // Delimiters only, never real cryptographic material.
    const pem=['-----BEGIN','PRIVATE KEY-----\nexample-not-a-real-key\n-----END','PRIVATE KEY-----'].join(' ');
    for(const value of [pem,`  ${pem}  `,JSON.stringify(pem),btoa(pem)]) assert.equal(normalizeAPNsPrivateKey(value),pem);
    assert.equal(normalizeAPNsPrivateKey(undefined),'');
    assert.equal(normalizeAPNsPrivateKey('missing'),'missing');
});

const alice='10000000-0000-0000-0000-000000000001',bob='10000000-0000-0000-0000-000000000002';
const a='31000000-0000-0000-0000-000000000001',b='31000000-0000-0000-0000-000000000002';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function setup() {
    const db=new PGlite();
    await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role;');
    for(const file of (await readdir(new URL('../migrations',import.meta.url))).filter(f=>f.endsWith('.sql')).sort()) {
        if(file.startsWith('20260901220000_'))continue;
        await db.exec(await readFile(new URL(`../migrations/${file}`,import.meta.url),'utf8'));
    }
    await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
    await scalar(db,'select wif_send_friend_request($1,\'bob\')',[alice]);
    const request=(await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests[0].id;
    await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]);
    return db;
}
const snap=(db,id)=>scalar(db,'select wif_travel_snapshot($1)',[id]);
const save=(db,owner,id,audience=[],revision=0,enabled=false,city='Tokyo',region='Tokyo',start=5,end=9)=>scalar(db,
    "select wif_travel_save($1,$2,$3,'JP',$4,'Asia/Tokyo',current_date+$5::integer,current_date+$6::integer,$7::uuid[],$8,$9)",
    [owner,id,city,region,start,end,audience,enabled,revision]);

test('travel plans: own-only CRUD, reciprocal audiences, exact date intersection, private by default and optimistic revision',async()=>{
    const db=await setup();try {
        let s=await save(db,alice,a);
        assert.deepEqual(s.plans[0].audience,[]);assert.equal(s.plans[0].alertsEnabled,false);
        assert.deepEqual((await snap(db,bob)).plans,[]);
        await save(db,bob,b,[alice],0,false,'Tokyo','Tokyo',7,12);
        assert.deepEqual((await snap(db,alice)).overlaps,[]);
        s=await save(db,alice,a,[bob],1);
        assert.equal(s.overlaps.length,1);
        assert.equal(s.overlaps[0].startDay,(await snap(db,bob)).plans[0].startDay);
        assert.equal(s.overlaps[0].endDay,s.plans[0].endDay);
        await assert.rejects(save(db,bob,a,[],2),/access denied/);
        await assert.rejects(save(db,alice,a,[bob],1),/conflict/);
        await assert.rejects(scalar(db,'select wif_travel_delete($1,$2,2)',[bob,a]),/access denied/);
        await assert.rejects(save(db,alice,crypto.randomUUID(),[alice]),/current friends/);
        await assert.rejects(save(db,alice,crypto.randomUUID(),[crypto.randomUUID()]),/current friends/);
        await save(db,alice,a,[],2);
        assert.deepEqual((await snap(db,bob)).overlaps,[]);
        await scalar(db,'select wif_travel_delete($1,$2,3)',[alice,a]);
        assert.equal((await snap(db,alice)).plans.length,0);
    } finally {await db.close();}
});

test('overlaps do not conflate regions; blocks and friendship removal revoke immediately; dates and timezones validated',async()=>{
    const db=await setup();try {
        await save(db,alice,a,[bob]);await save(db,bob,b,[alice],0,false,'Tokyo','Other region');
        assert.equal((await snap(db,alice)).overlaps.length,0);
        await save(db,bob,b,[alice],1);assert.equal((await snap(db,alice)).overlaps.length,1);
        await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[bob,alice]);
        assert.equal((await snap(db,alice)).overlaps.length,0);
        await db.exec('delete from user_blocks');
        await scalar(db,'select wif_remove_friend($1,$2)',[alice,bob]);
        assert.equal((await snap(db,alice)).overlaps.length,0);
        assert.equal(await scalar(db,'select count(*)::int from travel_plan_audience'),0);
        await assert.rejects(save(db,alice,crypto.randomUUID(),[],0,false,'Tokyo','Tokyo',10,5),/Invalid travel/);
        await assert.rejects(scalar(db,"select wif_travel_save($1,$2,'Tokyo','JP','Tokyo','Not/AZone',current_date+1,current_date+2,'{}',false,0)",[alice,crypto.randomUUID()]),/Invalid|time zone/);
        await db.exec('set role authenticated');
        await assert.rejects(db.query('select * from travel_plans'),/permission denied/);
        await assert.rejects(db.query('select wif_travel_snapshot($1)',[alice]),/permission denied/);
        await db.exec('reset role');
    } finally {await db.close();}
});

test('upcoming push: opt-in, bounded lease, revalidation, privacy, per-device dedup, no stale owner delivery',async()=>{
    const db=await setup();try {
        await save(db,alice,a,[bob]);await save(db,bob,b,[alice]);
        const device=await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend')",[alice,crypto.randomUUID(),'c'.repeat(64)]);
        let token=crypto.randomUUID();
        assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[token]),[]);
        await save(db,alice,a,[bob],1,true);
        const claimed=await scalar(db,'select wif_travel_claim($1)',[token]);assert.equal(claimed.length,1);
        assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]),[]);
        const id=claimed[0].delivery_id;
        let prepared=await scalar(db,'select wif_travel_prepare($1,$2)',[id,token]);
        assert.match(prepared.deep_link,/whereismyfriend:\/\/upcoming\/[a-f0-9]{32}$/);
        await db.query('update user_sharing_settings set notification_preview_enabled=false where user_id=$1',[alice]);
        prepared=await scalar(db,'select wif_travel_prepare($1,$2)',[id,token]);
        assert.equal(prepared.title,'An upcoming overlap');assert.ok(!prepared.body.includes('Bob'));
        await save(db,bob,b,[],1);
        assert.equal(await scalar(db,'select wif_travel_prepare($1,$2)',[id,token]),null);
        await save(db,bob,b,[alice],2);
        await db.query('update devices set user_id=$1 where id=$2',[bob,device]);
        assert.equal(await scalar(db,'select wif_travel_prepare($1,$2)',[id,token]),null);
        await db.query('update devices set user_id=$1 where id=$2',[alice,device]);
        await scalar(db,"select wif_travel_complete($1,$2,'delivered',false)",[id,token]);
        assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]),[]);
        await save(db,alice,a,[bob],2,true,'Tokyo','Tokyo',30,35);
        await save(db,bob,b,[alice],3,true,'Tokyo','Tokyo',30,35);
        assert.deepEqual(await scalar(db,'select wif_travel_claim($1)',[crypto.randomUUID()]),[]);
    } finally {await db.close();}
});

test('travel input rejects owner injection and malformed dates; worker never sends a revoked prepared item',async()=>{
    const valid={city:'Tokyo',countryCode:'JP',region:'Tokyo',timeZone:'Asia/Tokyo',startDay:'2026-10-12',endDay:'2026-10-16',audience:[bob],alertsEnabled:false,revision:0};
    assert.equal(travelPlanInput(valid).p_country,'JP');
    for(const bad of [{...valid,userID:alice},{...valid,startDay:'2026-02-30'},{...valid,endDay:'2026-01-01'},
        {...valid,alertsEnabled:'yes'},{...valid,audience:[null]},{...valid,revision:-1}]) assert.throws(()=>travelPlanInput(bad));
    const calls=[];
    const database={rpc:async(name)=>{calls.push(name);return {data:name==='wif_travel_claim'?[{delivery_id:'revoked'}]:null,error:null};}};
    let sent=0;await deliverUpcoming(database,'lease',async()=>{sent++;});
    assert.equal(sent,0);assert.deepEqual(calls,['wif_travel_claim','wif_travel_prepare','wif_travel_complete']);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {travelPlanInput} from '../functions/_shared/travel-plans.mjs';

const alice='10000000-0000-0000-0000-000000000001',bob='10000000-0000-0000-0000-000000000002';
const planID='a7150000-0000-0000-0000-000000000001';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const snapshot=(db,user)=>scalar(db,'select wif_travel_snapshot($1)',[user]);
async function befriend(db) {
    await scalar(db,"select wif_send_friend_request($1,'bob')",[alice]);
    const request=(await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests[0].id;
    await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]);
}
async function setup({legacy=false}={}) {
    const db=new PGlite();
    await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role;');
    for(const file of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort()) {
        if(file.startsWith('20260901220000_') ||
            (legacy && (file.startsWith('20260915040000_') || file.startsWith('20260923010000_')))) continue;
        await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
    }
    await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
    await befriend(db);
    return db;
}
const save=(db,{revision=0,browse=false,audience=[bob],id=planID,start=2,end=5}={})=>scalar(db,
    "select wif_travel_save_v2($1,$2,'Tokyo','JP','Tokyo','Asia/Tokyo',current_date+$3::integer,current_date+$4::integer,$5::uuid[],false,$6,$7)",
    [alice,id,start,end,audience,revision,browse]);
const legacySave=(db,revision=0)=>scalar(db,
    "select wif_travel_save($1,$2,'Tokyo','JP','Tokyo','Asia/Tokyo',current_date+2,current_date+5,$3::uuid[],false,$4)",
    [alice,planID,[bob],revision]);

test('migration keeps legacy matching grants private; explicit browsing works without reciprocal plans or announcement pushes',async()=>{
    const db=await setup({legacy:true});try {
        await legacySave(db);
        await db.exec(await readFile(new URL('../migrations/20260915040000_friend_travel_plans.sql',import.meta.url),'utf8'));
        assert.equal((await snapshot(db,alice)).plans[0].allowFriendBrowsing,false);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await save(db,{revision:1,browse:true});
        const bobSnapshot=await snapshot(db,bob);
        assert.equal(bobSnapshot.plans.length,0);
        assert.equal(bobSnapshot.overlaps.length,0);
        assert.equal(bobSnapshot.friendPlans.length,1);
        assert.equal(bobSnapshot.friendPlans[0].friendID,alice);
        assert.deepEqual(Object.keys(bobSnapshot.friendPlans[0]).sort(),
            ['id','friendID','friendName','city','countryCode','region','timeZone','startDay','endDay'].sort());
        assert.deepEqual((await snapshot(db,alice)).friendPlans,[]);
        assert.equal(await scalar(db,'select count(*)::int from upcoming_deliveries'),0);
    } finally {await db.close();}
});

test('default migration opens existing plans to their selected friends and preserves later opt-outs',async()=>{
    const db=await setup({legacy:true});try {
        await db.exec(await readFile(new URL('../migrations/20260915040000_friend_travel_plans.sql',import.meta.url),'utf8'));
        await legacySave(db);
        assert.equal((await snapshot(db,alice)).plans[0].allowFriendBrowsing,false);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await db.exec(await readFile(new URL('../migrations/20260923010000_default_friend_plan_browsing.sql',import.meta.url),'utf8'));
        assert.equal((await snapshot(db,alice)).plans[0].allowFriendBrowsing,true);
        assert.equal((await snapshot(db,alice)).plans[0].revision,2);
        assert.equal((await snapshot(db,bob)).friendPlans.length,1);
        assert.equal(await scalar(db,'select count(*)::int from upcoming_deliveries'),0);
        await legacySave(db,2);
        assert.equal((await snapshot(db,bob)).friendPlans.length,1);
        await save(db,{revision:3,browse:false});
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await legacySave(db,4);
        assert.equal((await snapshot(db,alice)).plans[0].allowFriendBrowsing,false);
        const another='a7150000-0000-0000-0000-000000000003';
        await scalar(db,"select wif_travel_save($1,$2,'Tokyo','JP','Tokyo','Asia/Tokyo',current_date+2,current_date+5,$3::uuid[],false,0)",[alice,another,[bob]]);
        assert.equal((await snapshot(db,bob)).friendPlans.length,1);
    } finally {await db.close();}
});

test('audience, opt-out, deletion, blocks, friendship removal and re-addition revoke friend browsing',async()=>{
    const db=await setup();try {
        await save(db,{browse:true,audience:[]});
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await save(db,{revision:1,browse:true});
        assert.equal((await snapshot(db,bob)).friendPlans.length,1);
        await save(db,{revision:2,browse:false});
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await save(db,{revision:3,browse:true});
        await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[bob,alice]);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await db.exec('delete from user_blocks');
        await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[alice,bob]);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await db.exec('delete from user_blocks');
        await scalar(db,'select wif_remove_friend($1,$2)',[alice,bob]);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await befriend(db);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await save(db,{revision:4,browse:true});
        assert.equal((await snapshot(db,bob)).friendPlans.length,1);
        await scalar(db,'select wif_travel_delete($1,$2,5)',[alice,planID]);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
    } finally {await db.close();}
});

test('legacy writes preserve browsing choice and v2 revision/owner checks cannot be bypassed',async()=>{
    const db=await setup();try {
        await save(db,{browse:true});
        await assert.rejects(save(db,{revision:0,browse:false}),/conflict/);
        assert.equal((await snapshot(db,bob)).friendPlans.length,1);
        await assert.rejects(scalar(db,"select wif_travel_save_v2($1,$2,'Tokyo','JP','Tokyo','Asia/Tokyo',current_date+2,current_date+5,'{}',false,1,true)",[bob,planID]),/access denied/);
        await legacySave(db,1);
        assert.equal((await snapshot(db,alice)).plans[0].allowFriendBrowsing,true);
        assert.equal((await snapshot(db,bob)).friendPlans.length,1);
        await save(db,{revision:2,browse:false});
        await legacySave(db,3);
        assert.equal((await snapshot(db,alice)).plans[0].allowFriendBrowsing,false);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await assert.rejects(save(db,{revision:4,browse:null}),/visibility/);
    } finally {await db.close();}
});

test('friend feed is date-sorted, excludes ended plans and deleted owners, and is service-role only',async()=>{
    const db=await setup();try {
        await save(db,{browse:true,start:6,end:9});
        const earlier='a7150000-0000-0000-0000-000000000002';
        await save(db,{id:earlier,browse:true,start:2,end:4});
        assert.deepEqual((await snapshot(db,bob)).friendPlans.map(p=>p.id),[earlier,planID]);
        await db.query("update travel_plans set start_day=(now() at time zone time_zone)::date-2,end_day=(now() at time zone time_zone)::date-1 where id=$1",[earlier]);
        assert.deepEqual((await snapshot(db,bob)).friendPlans.map(p=>p.id),[planID]);
        await db.query('update app_users set deleted_at=now() where id=$1',[alice]);
        assert.deepEqual((await snapshot(db,bob)).friendPlans,[]);
        await assert.rejects(snapshot(db,alice),/unavailable/);
        for(const role of ['anon','authenticated']) {
            await db.exec('set role '+role);
            await assert.rejects(scalar(db,'select wif_friend_travel_plans($1)',[bob]),/permission denied/);
            await assert.rejects(scalar(db,"select wif_travel_save_v2($1,$2,'Tokyo','JP','Tokyo','Asia/Tokyo',current_date+2,current_date+5,'{}',false,1,true)",[alice,planID]),/permission denied/);
            await db.exec('reset role');
        }
    } finally {await db.close();}
});

test('API input accepts an explicit visibility choice and preserves the legacy RPC shape',()=>{
    const body={city:'Tokyo',countryCode:'JP',region:'Tokyo',timeZone:'Asia/Tokyo',startDay:'2026-10-12',endDay:'2026-10-16',audience:[bob],alertsEnabled:false,revision:0};
    assert.equal(Object.hasOwn(travelPlanInput(body),'p_allow_friend_browsing'),false);
    assert.equal(travelPlanInput({...body,allowFriendBrowsing:true}).p_allow_friend_browsing,true);
    assert.equal(travelPlanInput({...body,allowFriendBrowsing:false}).p_allow_friend_browsing,false);
    for(const value of [null,'true',1,{},[]]) assert.throws(()=>travelPlanInput({...body,allowFriendBrowsing:value}));
});

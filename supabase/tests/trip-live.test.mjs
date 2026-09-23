import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import { refreshOneFlight, deliverTripUpdates } from '../functions/_shared/trip-worker.mjs';

const alice='10000000-0000-0000-0000-000000000001', bob='10000000-0000-0000-0000-000000000002';
const person='30000000-0000-0000-0000-000000000002';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function fixture() {
    const db=new PGlite();
    await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role');
    for(const file of (await readdir(new URL('../migrations',import.meta.url))).filter(x=>x.endsWith('.sql')).sort()) {
        await db.exec(await readFile(new URL(`../migrations/${file}`,import.meta.url),'utf8'));
    }
    await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
    const departure=new Date(Date.now()-1800000).toISOString(), arrival=new Date(Date.now()+3600000).toISOString();
    const date=departure.slice(0,10);
    const trip=await scalar(db,"select wif_trip_create($1,'live-trip','Together','LAX',$2::date,$2::date+3)",[alice,date]);
    await db.query("insert into trip_members(trip_id,user_id,role) values('live-trip',$1,'member')",[bob]);
    await db.query("insert into participants(id,trip_id,user_id,name) values($1,'live-trip',$2,'Bob')",[person,bob]);
    await scalar(db,"select wif_trip_add_flight($1,'live-trip','live-flight','UA353',$2,'outbound')",[alice,date]);
    const candidate={id:'EWR|LAX|selected',date,flightNumber:'UA353',departure:{code:'EWR',scheduledTime:{utc:departure,local:departure}},
        arrival:{code:'LAX',scheduledTime:{utc:arrival,local:arrival}},status:'scheduled'};
    await db.query("update flights set candidate_id=$1,departure=$2,arrival=$3,status='scheduled',verified_at=now()-interval '1 hour' where id='live-flight'",
        [candidate.id,JSON.stringify(candidate.departure),JSON.stringify(candidate.arrival)]);
    const device=await scalar(db,"select wif_register_push_device($1,$2,$3,'v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend')",
        [bob,crypto.randomUUID(),'a'.repeat(64)]);
    const claim=()=>scalar(db,'select wif_trip_claim_refresh($1)',[crypto.randomUUID()]);
    const run=async (changes={}, token=crypto.randomUUID())=>{
        await scalar(db,'select wif_trip_claim_refresh($1)',[token]);
        const result={source:'aerodatabox',flightNumber:'UA353',date,fetchedAt:new Date().toISOString(),flights:[{...candidate,...changes}]};
        return scalar(db,'select wif_trip_finish_refresh($1,$2,$3,$4)',[token,'UA353',date,JSON.stringify(result)]);
    };
    return {db,date,trip,candidate,device,run,claim};
}

test('trip preferences and check-ins belong to actor; meeting edits require owner and revision',async()=>{
    const {db,trip}=await fixture();
    try {
        assert.equal(await scalar(db,"select wif_trip_utc('2026-09-09 22:30Z')=wif_trip_utc('2026-09-09T22:30:00Z')"),true);
        assert.equal(await scalar(db,"select wif_trip_utc('invalid')"),null);
        const before=await scalar(db,"select wif_trip_snapshot($1,'live-trip')",[bob]);
        assert.equal(before.flight_alerts_enabled,false);
        const updated=await scalar(db,"select wif_trip_preferences($1,'live-trip',true)",[bob]);
        assert.equal(updated.flight_alerts_enabled,true);
        assert.equal((await scalar(db,"select wif_trip_snapshot($1,'live-trip')",[alice])).flight_alerts_enabled,false);
        await assert.rejects(scalar(db,"select wif_trip_meeting($1,'live-trip','Gate 4',$2)",[bob,trip.revision]),/access denied/);
        const meeting=await scalar(db,"select wif_trip_meeting($1,'live-trip','Gate 4',$2)",[alice,trip.revision]);
        assert.equal(meeting.meeting_point,'Gate 4');
        await assert.rejects(scalar(db,"select wif_trip_meeting($1,'live-trip','stale',$2)",[alice,trip.revision]),/conflict/);
        const checked=await scalar(db,"select wif_trip_check_in($1,'live-trip','bags_collected')",[bob]);
        assert.equal(checked.participants.find(p=>p.user_id===bob).check_in,'bags_collected');
        assert.equal(checked.participants.find(p=>p.user_id===alice).check_in,'not_set');
        assert.equal(checked.flights[0].status,'scheduled');
        await scalar(db,"select wif_trip_check_in($1,'live-trip','not_set')",[bob]);
        assert.equal(await scalar(db,'select check_in_at from participants where id=$1',[person]),null);
        await db.query('delete from trip_members where user_id=$1',[bob]);
        await assert.rejects(scalar(db,"select wif_trip_preferences($1,'live-trip',true)",[bob]),/access denied/);
    } finally {await db.close();}
});

test('refresh leases prevent duplicate calls; only active verified flights qualify; daily cap is durable',async()=>{
    const {db,claim}=await fixture();
    try {
        await db.exec("update trips set completed_at=now()");
        assert.equal(await claim(),null);
        await db.exec("update trips set completed_at=null; update flights set status='unverified'");
        assert.equal(await claim(),null);
        await db.exec("update flights set status='scheduled'");
        assert.ok(await claim());
        assert.equal(await claim(),null);
        assert.equal(await scalar(db,"select calls from trip_flight_lookup_limits where bucket='background'"),1);
        await db.exec("update trip_flight_refresh_jobs set lease_until=now()-interval '1 minute'; update trip_flight_lookup_limits set calls=20 where bucket='background'");
        assert.equal(await claim(),null);
        assert.equal(await scalar(db,"select tracking_state from flights where id='live-flight'"),'quota_limited');
        assert.equal(await scalar(db,"select calls from trip_flight_lookup_limits where bucket='global'"),1);
    } finally {await db.close();}
});

test('refresh persists selected route only; failure preserves previous time/status and revision',async()=>{
    const {db,date,candidate,run}=await fixture();
    try {
        const old=await scalar(db,"select to_jsonb(f) from flights f where id='live-flight'");
        await run({id:'other-leg',status:'landed'});
        const missing=await scalar(db,"select to_jsonb(f) from flights f where id='live-flight'");
        assert.equal(missing.status,old.status); assert.equal(missing.verified_at,old.verified_at); assert.equal(missing.tracking_state,'not_found');
        await db.exec('update trip_flight_refresh_jobs set available_at=now()');
        const token=crypto.randomUUID();
        await scalar(db,'select wif_trip_claim_refresh($1)',[token]);
        await scalar(db,'select wif_trip_finish_refresh($1,$2,$3,null)',[token,'UA353',date]);
        assert.equal(await scalar(db,"select tracking_state from flights where id='live-flight'"),'unavailable');
        await db.exec('update trip_flight_refresh_jobs set available_at=now()');
        await run({status:'airborne'});
        const current=await scalar(db,"select to_jsonb(f) from flights f where id='live-flight'");
        assert.equal(current.revision,old.revision); assert.equal(current.status,'airborne');
        assert.equal(current.candidate_id,candidate.id);
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_events'),0);
    } finally {await db.close();}
});

test('landed alert is deduplicated, opt-in only, account-bound, and never changes manual check-in',async()=>{
    const {db,run}=await fixture();
    try {
        await scalar(db,"select wif_trip_preferences($1,'live-trip',true)",[bob]);
        await run({status:'landed'});
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_events'),1);
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_deliveries'),1);
        assert.equal(await scalar(db,'select check_in from participants where id=$1',[person]),'not_set');
        const token=crypto.randomUUID();
        const [claim]=await scalar(db,'select wif_trip_claim_deliveries($1)',[token]);
        const delivery=await scalar(db,'select wif_trip_prepare_delivery($1,$2)',[claim.delivery_id,token]);
        assert.match(delivery.body,/has landed/); assert.match(delivery.deep_link,/trips\/view\/live-trip$/);
        assert.deepEqual(await scalar(db,'select wif_trip_claim_deliveries($1)',[crypto.randomUUID()]),[]);
        await scalar(db,'select wif_trip_complete_delivery($1,$2,\'delivered\')',[claim.delivery_id,token]);
        assert.deepEqual(await scalar(db,'select wif_trip_claim_deliveries($1)',[crypto.randomUUID()]),[]);
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_events'),1);
    } finally {await db.close();}
});

test('opt-out, blocks, changed installation owner and membership removal prevent queued alerts',async()=>{
    const {db,run,device}=await fixture();
    try {
        await scalar(db,"select wif_trip_preferences($1,'live-trip',true)",[bob]);
        await run({status:'cancelled'});
        const token=crypto.randomUUID();
        const [claim]=await scalar(db,'select wif_trip_claim_deliveries($1)',[token]);
        const prepare=()=>scalar(db,'select wif_trip_prepare_delivery($1,$2)',[claim.delivery_id,token]);
        await scalar(db,"select wif_trip_preferences($1,'live-trip',false)",[bob]); assert.equal(await prepare(),null);
        await scalar(db,"select wif_trip_preferences($1,'live-trip',true)",[bob]);
        await db.query('insert into user_blocks(blocker_id,blocked_id) values($1,$2)',[bob,alice]); assert.equal(await prepare(),null);
        await db.exec('delete from user_blocks');
        await db.query('update devices set user_id=$1 where id=$2',[alice,device]); assert.equal(await prepare(),null);
        await db.query('update devices set user_id=$1 where id=$2',[bob,device]);
        await db.query('update user_sharing_settings set notification_preview_enabled=false where user_id=$1',[bob]);
        assert.equal((await prepare()).body,'Open Across Us to see your trip update.');
        await db.query('delete from trip_members where user_id=$1',[bob]); assert.equal(await prepare(),null);
        assert.deepEqual(await scalar(db,'select wif_trip_claim_deliveries($1)',[crypto.randomUUID()]),[]);
    } finally {await db.close();}
});

test('significant arrival delay threshold is 30 minutes; no initial opt-in means no push',async()=>{
    const {db,run,candidate}=await fixture();
    try {
        const revised=minutes=>({...candidate.arrival,revisedTime:{utc:new Date(Date.parse(candidate.arrival.scheduledTime.utc)+minutes*60000).toISOString()}});
        await run({arrival:revised(29)});
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_events'),0);
        await db.exec('update trip_flight_refresh_jobs set available_at=now()');
        await run({arrival:revised(30)});
        assert.equal(await scalar(db,"select status from flights where id='live-flight'"),'delayed');
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_events'),1);
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_deliveries'),0);
        await scalar(db,"select wif_trip_preferences($1,'live-trip',true)",[bob]);
        await db.exec('update trip_flight_refresh_jobs set available_at=now()');
        await run({arrival:revised(60)});
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_events'),1);
        assert.equal(await scalar(db,'select count(*)::int from trip_flight_deliveries'),0);
    } finally {await db.close();}
});

test('flight edited mid-request cannot receive a previous candidate update; expired worker lease is ignored',async()=>{
    const {db,date,candidate}=await fixture();
    try {
        const token=crypto.randomUUID(); await scalar(db,'select wif_trip_claim_refresh($1)',[token]);
        await db.exec("update flights set candidate_id='replacement'");
        const result={source:'aerodatabox',flightNumber:'UA353',date,fetchedAt:new Date().toISOString(),flights:[{...candidate,status:'landed'}]};
        assert.equal(await scalar(db,'select wif_trip_finish_refresh($1,$2,$3,$4)',[token,'UA353',date,JSON.stringify(result)]),0);
        assert.equal(await scalar(db,"select status from flights where id='live-flight'"),'scheduled');
        await db.exec('update trip_flight_refresh_jobs set available_at=now()');
        await scalar(db,'select wif_trip_claim_refresh($1)',[token]);
        await db.exec("update trip_flight_refresh_jobs set lease_until=now()-interval '1 minute'");
        assert.equal(await scalar(db,'select wif_trip_finish_refresh($1,$2,$3,$4)',[token,'UA353',date,JSON.stringify(result)]),0);
    } finally {await db.close();}
});

test('new tracking tables and RPCs cannot be accessed by direct clients',async()=>{
    const {db}=await fixture();
    try {
        for(const role of ['anon','authenticated']) {
            for(const table of ['trip_flight_refresh_jobs','trip_flight_events','trip_flight_deliveries']) {
                for(const op of ['SELECT','INSERT','UPDATE','DELETE']) assert.equal(await scalar(db,'select has_table_privilege($1,$2,$3)',[role,table,op]),false);
            }
            for(const {signature} of (await db.query("select oid::regprocedure::text as signature from pg_proc where proname like 'wif_trip_%'")).rows) {
                assert.equal(await scalar(db,"select has_function_privilege($1,$2,'EXECUTE')",[role,signature]),false);
            }
        }
    } finally {await db.close();}
});

test('worker performs no provider request without a reservation, persists failures, and rechecks push access',async()=>{
    let providerCalls=0; const calls=[];
    const fetcher=async()=>{providerCalls++;throw new Error('offline');};
    await refreshOneFlight(async()=>null,'key',fetcher); assert.equal(providerCalls,0);
    const rpc=async(name,args)=>{calls.push([name,args]);return name==='wif_trip_claim_refresh'?{flightNumber:'UA353',date:'2026-09-09'}:0;};
    assert.equal((await refreshOneFlight(rpc,'key',fetcher)).state,'provider_unavailable');
    assert.equal(calls.at(-1)[1].p_result,null); assert.equal(providerCalls,1);
    let sent=0;
    await deliverTripUpdates(async(name)=>name==='wif_trip_claim_deliveries'?[{delivery_id:'test'}]:null,async()=>{sent++;});
    assert.equal(sent,0);
});

test('trip-worker HTTP refuses public keys and never consumes quota before authentication',async()=>{
    let handler,refreshCalls=0;
    const source=(await readFile(new URL('../functions/trip-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
    vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),{
        Request,Response,AbortSignal,JSON,Date,
        createClient:()=>({}),
        refreshOneFlight:async()=>{refreshCalls++; return {state:'idle',updated:0};},
        deliverTripUpdates:async()=>({claimed:0,delivered:0}),
        Deno:{env:{get:name=>name==='PUSH_WORKER_SECRET'?'worker-only':'configured'},serve:cb=>handler=cb},
    });
    for(const token of ['', 'public-publishable-key']) {
        const r=await handler(new Request('https://example.com',{method:'POST',headers:{Authorization:`Bearer ${token}`}}));
        assert.equal(r.status,401);
    }
    assert.equal(refreshCalls,0);
    assert.equal((await handler(new Request('https://example.com',{method:'POST',headers:{Authorization:'Bearer worker-only'}}))).status,200);
    assert.equal(refreshCalls,1);
});

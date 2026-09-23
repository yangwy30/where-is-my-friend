import test from "node:test";
import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
import { transformSnapshot, importIntoLocalDatabase } from "../../scripts/trip-migration/transform.mjs";

const alice = "10000000-0000-0000-0000-000000000001";
const bob = "10000000-0000-0000-0000-000000000002";
const guest = "30000000-0000-0000-0000-000000000001";
const secondGuest = "30000000-0000-0000-0000-000000000002";
async function scalar(db, sql, parameters = []) { return Object.values((await db.query(sql, parameters)).rows[0])[0]; }
async function database() {
    const db = new PGlite();
    await db.exec("create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role");
    for (const file of (await readdir(new URL("../migrations", import.meta.url))).filter(f => f.endsWith(".sql")).sort()) {
        await db.exec(await readFile(new URL(`../migrations/${file}`, import.meta.url), "utf8"));
    }
    await db.exec(await readFile(new URL("../seed.sql", import.meta.url), "utf8"));
    return db;
}
async function create(db, owner = alice, id = "trip-one") {
    return scalar(db, "select wif_trip_create($1,$2,'A trip','LAX','2026-09-05','2026-09-08')", [owner, id]);
}

test("trip create is atomic/idempotent and overlapping trips stay independent", async () => {
    const db = await database();
    try {
        const first = await create(db);
        assert.equal(first.my_role, "owner");
        assert.equal(first.participants.length, 1);
        await create(db);
        await create(db, alice, "trip-two");
        assert.equal(await scalar(db, "select count(*)::int from trip_members"), 2);
        assert.equal(await scalar(db, "select count(*)::int from participants"), 2);
        assert.equal((await scalar(db, "select wif_trip_list($1)", [alice])).length, 2);
        assert.deepEqual(await scalar(db, "select wif_trip_list($1)", [bob]), []);
        await assert.rejects(create(db, bob), /Trip access denied/);
        await assert.rejects(scalar(db, "select wif_trip_snapshot($1,'trip-one')", [bob]), /Trip access denied/);
    } finally { await db.close(); }
});

test("members write only their own flights; owners manage only shared trip details", async () => {
    const db = await database();
    try {
        const trip = await create(db);
        await db.query("insert into trip_members(trip_id,user_id,role) values ('trip-one',$1,'member')", [bob]);
        await db.query("insert into participants(id,trip_id,name,user_id) values ($1,'trip-one','Bob',$2)", [guest,bob]);
        await assert.rejects(scalar(db, "select wif_trip_complete($1,'trip-one',true)", [bob]), /Trip access denied/);
        await assert.rejects(scalar(db, "select wif_trip_update($1,'trip-one','Changed','JFK','2026-09-05','2026-09-08')", [bob]), /Trip access denied/);
        const add = (actor,id) => scalar(db, "select wif_trip_add_flight($1,'trip-one',$2,'UA 353','2026-09-05','outbound')", [actor,id]);
        await add(alice,"alice-flight");
        await add(bob,"bob-flight");
        await add(bob,"bob-flight");
        const flights = (await scalar(db,"select wif_trip_snapshot($1,'trip-one')",[bob])).flights;
        assert.equal(flights.length,2);
        assert.equal(flights.find(f=>f.id==="alice-flight").participant_id,trip.participants[0].id);
        assert.equal(flights.find(f=>f.id==="bob-flight").participant_id,guest);
        for (const [actor,other] of [[alice,"bob-flight"],[bob,"alice-flight"]]) {
            await assert.rejects(scalar(db,"select wif_trip_update_flight($1,'trip-one',$2,'DL 12','2026-09-06','inbound')",[actor,other]),/Trip access denied/);
            await assert.rejects(scalar(db,"select wif_trip_delete_flight($1,'trip-one',$2)",[actor,other]),/Trip access denied/);
            await assert.rejects(add(actor,other),/Flight conflict/);
        }
        await db.exec(`update flights set status='landed',departure='{\"code\":\"EWR\"}',arrival='{\"code\":\"LAX\"}',airline='United',gate='A1' where id='bob-flight'`);
        const changed = await scalar(db,"select wif_trip_update_flight($1,'trip-one','bob-flight','DL 12','2026-09-06','inbound')",[bob]);
        const flight = changed.flights.find(f=>f.id==="bob-flight");
        assert.equal(flight.status,"unverified");
        assert.deepEqual(flight.departure,{});
        assert.deepEqual(flight.arrival,{});
        assert.equal(flight.gate,"");
        await scalar(db,"select wif_trip_delete_flight($1,'trip-one','bob-flight')",[bob]);
        assert.equal(await scalar(db,"select count(*)::int from flights"),1);
        assert.ok((await scalar(db,"select wif_trip_complete($1,'trip-one',true)",[alice])).completed_at);
        assert.equal((await scalar(db,"select wif_trip_complete($1,'trip-one',false)",[alice])).completed_at,null);
        await create(db, bob, "trip-two");
        await assert.rejects(scalar(db,"select wif_trip_update_flight($1,'trip-two','alice-flight','DL 12','2026-09-06','inbound')",[bob]),/Trip access denied/);
        await db.query("update app_users set deleted_at=now() where id=$1",[bob]);
        await assert.rejects(add(bob,"deleted-account"),/Trip access denied/);
    } finally { await db.close(); }
});

test("unclaimed namesakes cannot be edited, and shared-editor RPCs no longer exist", async () => {
    const db = await database();
    try {
        const trip = await create(db);
        await db.query("insert into participants(id,trip_id,name) values ($1,'trip-one',$2)",[guest,trip.participants[0].name]);
        await db.query("insert into flights(id,trip_id,participant_id,flight_number) values ('legacy-flight','trip-one',$1,'UA 353')",[guest]);
        await assert.rejects(scalar(db,"select wif_trip_delete_flight($1,'trip-one','legacy-flight')",[alice]),/Trip access denied/);
        assert.equal(await scalar(db,"select to_regprocedure('wif_trip_add_guest(uuid,text,uuid,text)')"),null);
        assert.equal(await scalar(db,"select to_regprocedure('wif_trip_add_flight(uuid,text,text,uuid,text,date,text)')"),null);
        await db.query("insert into trip_members(trip_id,user_id,role) values ('trip-one',$1,'member')",[bob]);
        await assert.rejects(scalar(db,"select wif_trip_add_flight($1,'trip-one','f-one','UA 353','2026-09-05','outbound')",[bob]),/Trip access denied/);
    } finally { await db.close(); }
});

test("account invitations require recipient acceptance and never claim legacy namesakes", async () => {
    const db = await database();
    try {
        await create(db);
        const username = await scalar(db,"select username from app_users where id=$1",[bob]);
        const name = await scalar(db,"select display_name from app_users where id=$1",[bob]);
        await db.query("insert into participants(id,trip_id,name) values ($1,'trip-one',$2)",[guest,name]);
        let invitation = await scalar(db,"select wif_trip_invite($1,'trip-one',$2)",[alice,username]);
        assert.equal((await scalar(db,"select wif_trip_invitations($1)",[bob])).length,1);
        assert.deepEqual(await scalar(db,"select wif_trip_list($1)",[bob]),[]);
        await assert.rejects(scalar(db,"select wif_trip_snapshot($1,'trip-one')",[bob]),/Trip access denied/);
        await assert.rejects(scalar(db,"select wif_trip_accept_invitation($1,$2)",[alice,invitation.id]),/Trip access denied/);
        await db.query("update trip_invitations set expires_at=now()-interval '1 day' where id=$1",[invitation.id]);
        await assert.rejects(scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,invitation.id]),/Trip access denied/);
        const expiredID = invitation.id;
        invitation = await scalar(db,"select wif_trip_invite($1,'trip-one',$2)",[alice,username]);
        assert.notEqual(invitation.id, expiredID);
        await assert.rejects(scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,expiredID]),/Trip access denied/);
        const joined=await scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,invitation.id]);
        assert.equal(joined.my_role,"member");
        assert.equal(joined.participants.find(p=>p.id===guest).user_id,null);
        assert.equal(joined.participants.filter(p=>p.user_id===bob).length,1);
        await scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,invitation.id]);
        assert.equal(await scalar(db,"select count(*)::int from trip_members"),2);
        await assert.rejects(scalar(db,"select wif_trip_invite($1,'trip-one',$2)",[bob,username]),/Trip access denied/);
        await db.query("delete from trip_members where user_id=$1",[bob]);
        await assert.rejects(scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,invitation.id]),/Trip access denied/);
        await assert.rejects(scalar(db,"select wif_trip_list($1)",[null]),/Trip access denied/);
    } finally { await db.close(); }
});

test("cloud mutations check each resource revision and persist only cached provider candidates atomically", async () => {
    const db = await database();
    try {
        const original = await create(db);
        const mutate = (actor,kind,payload,revision=null) => scalar(db,"select wif_trip_mutate($1,'trip-one',$2,$3,$4)",[actor,kind,JSON.stringify(payload),revision]);
        const number = {id:'cloud-flight',flightNumber:'UA353',date:'2026-09-05',direction:'outbound'};
        await assert.rejects(mutate(bob,'addFlight',number),/Trip access denied/);
        const candidate = {id:'EWR-LAX',flightNumber:'UA353',date:number.date,departure:{code:'EWR'},arrival:{code:'LAX'},status:'airborne',airline:'United'};
        await scalar(db,"select wif_trip_flight_lookup_cache('UA353','2026-09-05',$1)", [JSON.stringify({source:'aerodatabox',flightNumber:'UA353',date:number.date,fetchedAt:'2026-09-05T12:00:00Z',flights:[candidate]})]);
        await assert.rejects(mutate(alice,'addFlight',{...number,candidateID:'forged-route'}),/Search again/);
        assert.equal(await scalar(db,"select count(*)::int from flights"),0);
        const saved = await mutate(alice,'addFlight',{...number,candidateID:candidate.id});
        assert.equal(saved.flights[0].status,'airborne');
        assert.equal(saved.flights[0].departure.code,'EWR');
        assert.ok(saved.flights[0].verified_at);
        const revision = saved.flights[0].revision;
        await mutate(alice,'addFlight',{...number,candidateID:candidate.id});
        assert.equal(await scalar(db,"select count(*)::int from flights"),1);
        await assert.rejects(mutate(alice,'editFlight',number,revision-1),/Flight conflict/);
        const changed = await mutate(alice,'editFlight',{...number,flightNumber:'DL12'},revision);
        assert.equal(changed.flights[0].status,'unverified');
        assert.equal(changed.flights[0].candidate_id,null);
        assert.equal(changed.flights[0].verified_at,null);
        assert.deepEqual(changed.flights[0].departure,{});
        await assert.rejects(mutate(alice,'deleteFlight',{id:number.id},revision),/Flight conflict/);
        await mutate(alice,'deleteFlight',{id:number.id},changed.flights[0].revision);
        const completed=await mutate(alice,'completion',{completed:true},original.revision);
        assert.ok(completed.completed_at);
        await assert.rejects(mutate(alice,'details',{name:'stale',destinationAirport:'JFK',startDate:number.date,endDate:number.date},original.revision),/Trip conflict/);
        assert.equal((await scalar(db,"select wif_trip_snapshot($1,'trip-one')",[alice])).name,original.name);
    } finally { await db.close(); }
});

test("invites can be declined/revoked, old links stay dead, and blocking prevents acceptance", async () => {
    const db=await database();
    try {
        await create(db);
        const username=await scalar(db,"select username from app_users where id=$1",[bob]);
        const invite=()=>scalar(db,"select wif_trip_invite($1,'trip-one',$2)",[alice,username]);
        const first=await invite();
        const pending=await scalar(db,"select wif_trip_invitation_list($1)",[bob]);
        assert.equal(pending[0].trip_name,'A trip');
        assert.equal(pending[0].recipient_id,bob);
        await assert.rejects(scalar(db,"select wif_trip_invitation_list($1,'trip-one')",[bob]),/Trip access denied/);
        await assert.rejects(scalar(db,"select wif_trip_dismiss_invitation($1,$2,false)",[alice,first.id]),/Trip access denied/);
        await scalar(db,"select wif_trip_dismiss_invitation($1,$2,false)",[bob,first.id]);
        await assert.rejects(scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,first.id]),/Trip access denied/);
        const second=await invite();
        await scalar(db,"select wif_trip_dismiss_invitation($1,$2,true)",[alice,second.id]);
        assert.deepEqual(await scalar(db,"select wif_trip_invitation_list($1)",[bob]),[]);
        const third=await invite();
        for(const id of [first.id,second.id]) await assert.rejects(scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,id]),/Trip access denied/);
        await db.query("insert into user_blocks(blocker_id,blocked_id) values($1,$2)",[bob,alice]);
        await assert.rejects(scalar(db,"select wif_trip_accept_invitation($1,$2)",[bob,third.id]),/Trip access denied/);
        await assert.rejects(invite(),/Trip access denied/);
        assert.deepEqual(await scalar(db,"select wif_trip_invitation_list($1)",[bob]),[]);
    } finally { await db.close(); }
});

test("anonymous and authenticated clients cannot bypass the App API or read imported trips", async () => {
    const db = await database();
    try {
        await create(db);
        const functions = (await db.query("select oid::regprocedure::text as signature from pg_proc where proname like 'wif_trip_%'")).rows;
        for (const role of ["anon", "authenticated"]) {
            for (const name of ["trips", "trip_members", "participants", "flights", "notes", "trip_import_batches", "trip_invitations", "trip_flight_lookup_cache", "trip_flight_lookup_limits"]) {
                for (const operation of ["SELECT", "INSERT", "UPDATE", "DELETE"]) {
                    assert.equal(await scalar(db, "select has_table_privilege($1,$2,$3)", [role, name, operation]), false);
                }
            }
            for (const fn of functions) assert.equal(await scalar(db, "select has_function_privilege($1,$2,'EXECUTE')", [role, fn.signature]), false);
        }
        for (const fn of functions) assert.equal(await scalar(db, "select has_function_privilege('service_role',$1,'EXECUTE')", [fn.signature]), true);
        await db.exec("set role anon");
        await assert.rejects(db.query("select * from trips"), /permission denied/);
        await db.exec("reset role");
    } finally { await db.close(); }
});

test('flight lookup quotas persist across requests and cache never bypasses trip membership',async()=>{
    const db=await database();
    try {
        await create(db);
        const begin=actor=>scalar(db,"select wif_trip_flight_lookup_begin($1,'trip-one','UA353','2026-09-06')",[actor]);
        await assert.rejects(begin(bob),/Trip access denied/);
        for(let i=0;i<10;i++) assert.equal((await begin(alice)).cached,null);
        await assert.rejects(begin(alice),/limit reached/);
        const result={source:'aerodatabox',flightNumber:'UA353',date:'2026-09-06',flights:[]};
        await scalar(db,"select wif_trip_flight_lookup_cache('UA353','2026-09-06',$1::jsonb)",[JSON.stringify(result)]);
        assert.deepEqual((await begin(alice)).cached,result);
        await assert.rejects(begin(bob),/Trip access denied/);
        await db.exec("update trip_flight_lookup_cache set expires_at=now()-interval '1 minute'; update trip_flight_lookup_limits set window_start=now()-interval '1 day' where bucket<>'global'");
        assert.equal((await begin(alice)).cached,null);
        await db.exec("update trip_flight_lookup_limits set calls=50 where bucket='global'");
        await assert.rejects(begin(alice),/limit reached/);
    } finally {await db.close();}
});

function fixture() {
    return { formatVersion: 1, sourceProject: "aaaaaaaaaaaaaaaaaaaa", exportedAt: "2026-09-05T12:00:00Z",
        trips: [{ id: "legacy-one", pin: "fixture-pin", name: "Legacy", start_date: "2026-09-05", end_date: "2026-09-08", destination_airport: "LAX" }],
        participants: [{ id: guest, trip_id: "legacy-one", name: "Traveler" }],
        flights: [{ id: "legacy-f", trip_id: "legacy-one", flight_number: "UA 353", added_by: "Traveler", departure: { code: "EWR" }, arrival: { code: "LAX" } }],
        notes: [{ id: "legacy-n", trip_id: "legacy-one", content: "A note", author: "Traveler" }], push_subscriptions: [] };
}

test("legacy transform preserves IDs, strips access credentials, and never claims App identities", () => {
    const snapshot = fixture();
    const plan = transformSnapshot(snapshot);
    assert.equal(plan.rows.trips[0].id, "legacy-one");
    assert.equal(Object.hasOwn(plan.rows.trips[0], "pin"), false);
    assert.equal(plan.rows.participants[0].user_id, null);
    assert.equal(plan.rows.flights[0].participant_id, guest);
    assert.equal(plan.rows.flights[0].direction, "outbound");
    snapshot.flights[0].arrival = { code: "NRT" };
    assert.equal(transformSnapshot(snapshot).rows.flights[0].direction, null);
    snapshot.flights[0].secret_new_field = "must not silently drop";
    assert.throws(() => transformSnapshot(snapshot), /Unmapped source column/);
});

test("local import leaves legacy trips inaccessible and rolls back a conflicting import", async () => {
    const db = await database();
    try {
        const snapshot = fixture();
        const report = await importIntoLocalDatabase(db, snapshot, JSON.stringify(snapshot));
        assert.equal(report.counts.trips, 1);
        assert.equal(await scalar(db, "select count(*)::int from trip_members"), 0);
        assert.deepEqual(await scalar(db, "select wif_trip_list($1)", [alice]), []);
        await assert.rejects(scalar(db, "select wif_trip_snapshot($1,'legacy-one')", [alice]), /Trip access denied/);
        await assert.rejects(create(db, alice, "legacy-one"), /Trip access denied/);
        await assert.rejects(importIntoLocalDatabase(db, snapshot, JSON.stringify(snapshot)), /duplicate key/);
        assert.equal(await scalar(db, "select count(*)::int from trips"), 1);
        assert.equal(await scalar(db, "select count(*)::int from trip_import_batches"), 1);
    } finally { await db.close(); }
});

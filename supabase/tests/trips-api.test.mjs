import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { stripTypeScriptTypes } from "node:module";
import vm from "node:vm";
import { isUUID, normalizeAPIPath } from "../functions/_shared/domain.mjs";
import { FlightLookupError, flightLookupInput } from "../functions/_shared/flight-lookup.mjs";
import { travelPlanInput } from "../functions/_shared/travel-plans.mjs";
import { wakeInvitationWorker } from "../functions/_shared/invitation-wakeup.mjs";
import { resilientSupabaseFetch, temporaryStatus, authFailureStatus } from "../functions/_shared/upstream-policy.mjs";

const userID = "10000000-0000-0000-0000-000000000001";
const authID = "20000000-0000-0000-0000-000000000001";
const participantID = "30000000-0000-0000-0000-000000000001";

test('collaboration endpoints accept only the authenticated actor and strict fields',async()=>{
    const {request,calls}=await harness();
    for(const [action,payload,name] of [
        ['preferences',{enabled:true},'wif_trip_preferences'],
        ['meeting',{point:'Exit 3',revision:1},'wif_trip_meeting'],
        ['check-in',{state:'bags_collected'},'wif_trip_check_in'],
    ]) {
        const path=`/v1/trips/trip-one/${action}`;
        assert.equal((await request('POST',path,payload,'')).status,401);
        assert.equal((await request('POST',path,{...payload,userID:'someone-else'})).status,400);
        assert.equal((await request('POST',path,payload)).status,200);
        assert.equal(calls.at(-1).name,name); assert.equal(calls.at(-1).parameters.p_user_id,userID);
    }
    assert.equal((await request('POST','/v1/trips/trip-one/meeting',{point:'x'})).status,400);
    assert.equal((await request('POST','/v1/trips/trip-one/preferences',{enabled:'true'})).status,400);
});

async function harness({ databaseError = null, cached = null, upstreamStatus, authError = null } = {}) {
    const calls = [];
    let handler;
    const database = {
        auth: { getUser: async token => authError ? {data:{user:null},error:authError}
            : token === "valid" ? { data: { user: { id: authID } }, error: null }
            : { data: { user: null }, error: { message: "invalid", status:401, code:'bad_jwt' } } },
        rpc: async (name, parameters) => {
            calls.push({ name, parameters });
            if (name === "wif_resolve_app_user") return { data: userID, error: null };
            if (name === "wif_trip_flight_lookup_begin") return { data: { cached }, error: databaseError };
            return { data: name === "wif_trip_list" ? [] : { id: "trip-one" }, error: databaseError, status:upstreamStatus };
        },
    };
    const source = (await readFile(new URL("../functions/api/index.ts", import.meta.url), "utf8"))
        .replace(/^import .*;\n/gm, "");
    const javascript = stripTypeScriptTypes(source, { mode: "transform" });
    vm.runInNewContext(javascript, {
        Request, Response, URL, console, isUUID, normalizeAPIPath, FlightLookupError, flightLookupInput, travelPlanInput,
        resilientSupabaseFetch, temporaryStatus, authFailureStatus, wakeInvitationWorker,
        fetchFlightLookup: async input => { calls.push({ name: "provider", parameters: input }); return { source: "aerodatabox", ...input, flights: [] }; },
        createClient: () => database,
        Deno: { env: { get: name => name === "SUPABASE_URL" ? "https://example.supabase.co" : "test-only" },
            serve: callback => { handler = callback; } },
    });
    return { calls, request: (method, path, body, token = "valid") => handler(new Request(`https://example.supabase.co/functions/v1/api${path}`, {
        method, headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    })) };
}

test('upstream Auth timeouts never become expired sessions or reach application writes', async()=>{
    for(const error of [{status:504,message:'Gateway Timeout'}, {status:503,message:'Service unavailable'},
        {message:'fetch failed'}, {message:'Unexpected upstream failure'}, {status:429,message:'Too many requests'}]) {
        const {request,calls}=await harness({authError:error});
        const response=await request('PATCH','/v1/profile',{displayName:'Name',username:'name',avatarPalette:1});
        assert.equal(response.status,authFailureStatus(error));
        assert.notEqual(response.status,401); assert.equal(calls.length,0);
        assert.doesNotMatch(await response.text(),/session expired/);
    }
    const invalid=await harness({authError:{status:403,code:'bad_jwt',message:'invalid'}});
    assert.equal((await invalid.request('POST','/v1/auth/bootstrap',{})).status,401);
    assert.equal(invalid.calls.length,0);
});

test('profile gateway failure stays 504, never replays write; business conflict remains 409',async()=>{
    for(const [error,upstreamStatus,expected] of [
        [{message:'Gateway Timeout'},504,504],
        [{message:'Internal upstream failure'},502,503],
        [{message:'TypeError: Upstream request timed out.'},0,504],
        [{code:'23505',message:'Username already taken.'},409,409],
        [{code:'P0001',message:'Invalid username.'},400,400],
        [{code:'XX000',message:'secret internal database detail'},500,503],
    ]) {
        const {request,calls}=await harness({databaseError:error,upstreamStatus});
        const response=await request('PATCH','/v1/profile',{displayName:'Name',username:'name',avatarPalette:1});
        assert.equal(response.status,expected);
        assert.equal(calls.filter(c=>c.name==='wif_update_profile').length,1);
        if(expected>=500)assert.doesNotMatch(await response.text(),/secret internal/);
    }
});

test("Trips HTTP routes use only the verified App actor, ignoring supplied account IDs", async () => {
    const { request, calls } = await harness();
    const cases = [
        ["GET", "/v1/trips", undefined, "wif_trip_list"],
        ["POST", "/v1/trips", { id: "trip-one", name: "Trip", destinationAirport: "lax", startDate: "2026-09-05", endDate: "2026-09-08" }, "wif_trip_create"],
        ["GET", "/v1/trips/trip-one", undefined, "wif_trip_snapshot"],
        ["PATCH", "/v1/trips/trip-one", { name: "Edited", destinationAirport: "JFK", startDate: "2026-09-05", endDate: "2026-09-08" }, "wif_trip_update"],
        ["PUT", "/v1/trips/trip-one/completion", { completed: true }, "wif_trip_complete"],
        ["POST", "/v1/trips/trip-one/invitations", { username: "bob" }, "wif_trip_invite"],
        ["GET", "/v1/trip-invitations", undefined, "wif_trip_invitation_list"],
        ["POST", `/v1/trip-invitations/${participantID}/accept`, {}, "wif_trip_accept_invitation"],
        ["POST", "/v1/trips/trip-one/flights", { id: "f-one", flightNumber: "UA 353", date: "2026-09-05", direction: "outbound" }, "wif_trip_add_flight"],
        ["PATCH", "/v1/trips/trip-one/flights/f-one", { flightNumber: "UA 353", date: "2026-09-05", direction: "outbound" }, "wif_trip_update_flight"],
        ["DELETE", "/v1/trips/trip-one/flights/f-one", undefined, "wif_trip_delete_flight"],
    ];
    for (const [method, path, body, expectedRPC] of cases) {
        const response = await request(method, path, body && !path.includes("/flights") ? { ...body, userID: "attacker", p_user_id: "attacker", role: "owner" } : body);
        assert.equal(response.status, 200);
        assert.equal(calls.at(-1).name, expectedRPC);
        assert.equal(calls.at(-1).parameters.p_user_id, userID);
        assert.equal(calls.at(-2).parameters.p_auth_user_id, authID);
    }
});

test('friend plan consent uses v2 with the authenticated actor; old payloads stay on the legacy write', async()=>{
    const {request,calls}=await harness();
    const body={city:'Tokyo',countryCode:'JP',region:'Tokyo',timeZone:'Asia/Tokyo',startDay:'2026-10-12',endDay:'2026-10-16',audience:[],alertsEnabled:false,revision:0,allowFriendBrowsing:true};
    const path=`/v1/travel-plans/${participantID}`;
    assert.equal((await request('PUT',path,body,'')).status,401);
    assert.equal((await request('PUT',path,{...body,ownerID:'someone'})).status,400);
    assert.equal((await request('PUT',path,body)).status,200);
    assert.equal(calls.at(-1).name,'wif_travel_save_v2');
    assert.equal(calls.at(-1).parameters.p_user_id,userID);
    assert.equal(calls.at(-1).parameters.p_allow_friend_browsing,true);
    assert.equal((await request('GET','/v1/travel-plans')).status,200);
    assert.equal(calls.at(-1).parameters.p_user_id,userID);
});

test('personal travel HTTP validates auth, owner injection, revisions and RPC actor', async () => {
    const {request,calls}=await harness();
    const path=`/v1/travel-plans/${participantID}`;
    const body={city:'Tokyo',countryCode:'JP',region:'Tokyo',timeZone:'Asia/Tokyo',startDay:'2026-09-12',endDay:'2026-09-15',audience:[],alertsEnabled:false,revision:0};
    assert.equal((await request('GET','/v1/travel-plans',undefined,'')).status,401);
    assert.equal((await request('PUT',path,body,'expired')).status,401);
    assert.equal((await request('PUT',path,{...body,ownerID:userID})).status,400);
    assert.equal((await request('DELETE',path,{})).status,400);
    assert.equal((await request('PUT',path,body)).status,200);
    assert.equal(calls.at(-1).name,'wif_travel_save');
    assert.equal(calls.at(-1).parameters.p_user_id,userID);
    assert.equal((await request('DELETE',path,{revision:1})).status,200);
    assert.equal(calls.at(-1).name,'wif_travel_delete');
    assert.equal(calls.at(-1).parameters.p_user_id,userID);
    const denied=await harness({databaseError:{message:'Travel access denied.'}});
    assert.equal((await denied.request('PUT',path,body)).status,403);
});

test("Trips HTTP rejects absent/expired sessions and invalid inputs before calling trip RPCs", async () => {
    const { request, calls } = await harness();
    assert.equal((await request("GET", "/v1/trips", undefined, "")).status, 401);
    assert.equal((await request("GET", "/v1/trips", undefined, "expired")).status, 401);
    assert.equal((await request("POST", "/v1/trips", {})).status, 400);
    assert.equal((await request("PUT", "/v1/trips/trip-one/completion", { completed: "true" })).status, 400);
    assert.equal((await request("POST", "/v1/trips/trip-one/participants", { id: participantID, name: "Guest" })).status, 403);
    for (const identity of ["participantID", "userID", "p_user_id", "travelerID", "role"]) {
        assert.equal((await request("POST", "/v1/trips/trip-one/flights", {
            id: "f-one", flightNumber: "UA 353", date: "2026-09-05", direction: "outbound", [identity]: participantID,
        })).status, 400);
        assert.equal((await request("PATCH", "/v1/trips/trip-one/flights/f-one", {
            flightNumber: "UA 353", date: "2026-09-05", direction: "outbound", [identity]: participantID,
        })).status, 400);
    }
    assert.equal(calls.filter(call => call.name.startsWith("wif_trip_")).length, 0);
});

test("Trips HTTP maps denied membership to 403 without returning trip data", async () => {
    const { request } = await harness({ databaseError: { message: "Trip access denied." } });
    const response = await request("GET", "/v1/trips/trip-one");
    assert.equal(response.status, 403);
    assert.deepEqual(await response.json(), { message: "Trip access denied." });
});

test("flight lookup authenticates and authorizes before provider use, caches results and rejects bad input", async () => {
    const body={flightNumber:'UA 353',date:'2026-09-06'};
    const path='/v1/trips/trip-one/flight-lookup';
    const {request,calls}=await harness();
    assert.equal((await request('POST',path,body,'')).status,401);
    assert.equal((await request('POST',path,{...body,participantID})).status,400);
    assert.equal((await request('POST',path,{...body,date:'2026-02-30'})).status,400);
    assert.equal(calls.filter(c=>c.name==='provider').length,0);
    assert.equal((await request('POST',path,body)).status,200);
    const tripCalls=calls.filter(c=>c.name!=='wif_resolve_app_user');
    assert.deepEqual(tripCalls.map(c=>c.name),['wif_trip_flight_lookup_begin','provider','wif_trip_flight_lookup_cache']);
    assert.equal(tripCalls[0].parameters.p_user_id,userID);
    assert.equal(tripCalls[1].parameters.flightNumber,'UA353');
    const hit=await harness({cached:{source:'aerodatabox',flights:[]}});
    assert.equal((await hit.request('POST',path,body)).status,200);
    assert.equal(hit.calls.filter(c=>c.name==='provider').length,0);
    for(const [message,status] of [['Trip access denied.',403],['Flight lookup limit reached.',429]]) {
        const denied=await harness({databaseError:{message}});
        assert.equal((await denied.request('POST',path,body)).status,status);
        assert.equal(denied.calls.filter(c=>c.name==='provider').length,0);
    }
});

test("cloud mutation routes reject identity/provider injection and require revisions", async () => {
    const {request,calls}=await harness();
    const path='/v1/trips/trip-one/mutations';
    const payload={id:'flight',flightNumber:'UA353',date:'2026-09-05',direction:'outbound',candidateID:'EWR-LAX'};
    for(const field of ['participantID','userID','status','departure','arrival','verifiedAt']) {
        assert.equal((await request('POST',path,{kind:'addFlight',payload:{...payload,[field]:'forged'}})).status,400);
    }
    assert.equal((await request('POST',path,{kind:'editFlight',payload})).status,400);
    assert.equal((await request('POST',path,{kind:'__proto__',payload})).status,400);
    assert.equal((await request('POST',path,{kind:'addFlight',payload},'public-key')).status,401);
    assert.equal(calls.filter(c=>c.name==='wif_trip_mutate').length,0);
    assert.equal((await request('POST',path,{kind:'addFlight',payload})).status,200);
    assert.equal(calls.at(-1).parameters.p_user_id,userID);
    assert.equal((await request('POST',path,{kind:'editFlight',payload,revision:3})).status,200);
    assert.equal(calls.at(-1).parameters.p_revision,3);
    for(const action of ['decline','revoke']) {
        assert.equal((await request('POST',`/v1/trip-invitations/${participantID}/${action}`,{})).status,200);
        assert.equal(calls.at(-1).parameters.p_revoke,action==='revoke');
    }
});

test("removed public lookup never spends provider quota with a public key or missing session", async () => {
    const { request, calls } = await harness();
    const body = { flightNumber: 'CZ 328', date: '2026-09-06' };
    const path = '/v1/flights/lookup';

    for (const token of ['', 'sb_publishable_public', 'expired']) {
        assert.equal((await request('POST', path, body, token)).status, 401);
    }
    assert.equal((await request('POST', path, body)).status, 404);
    assert.equal(calls.filter(call => call.name === 'provider').length, 0);
});

test('lifecycle HTTP actions reject spoofed actors and malformed fields and bind retries to the authenticated actor',async()=>{
 const {request,calls}=await harness();
 const path='/v1/trips/trip-one/lifecycle';
 const requestID='40000000-0000-0000-0000-000000000001';
 for(const action of ['leave','cancel','delete','removeMember']) {
  const body={action,requestID,...(action==='leave'?{}:{revision:4}),...(action==='removeMember'?{participantID}:{})};
  assert.equal((await request('POST',path,body,'')).status,401);
  assert.equal((await request('POST',path,{...body,userID:participantID})).status,400);
  assert.equal((await request('POST',path,{...body,requestID:'bad-id'})).status,400);
  assert.equal((await request('POST',path,body)).status,200);
  assert.equal(calls.at(-1).name,'wif_trip_lifecycle');
  assert.equal(calls.at(-1).parameters.p_user_id,userID);
  assert.equal(calls.at(-1).parameters.p_action,action);
  assert.equal(calls.at(-1).parameters.p_request_id,requestID);
 }
 for(const body of [{action:'delete',requestID},{action:'removeMember',requestID,revision:4},
  {action:'leave',requestID,participantID},{action:'leave',requestID,revision:4},
  {action:'cancel',requestID,revision:0},{action:'restore',requestID,revision:4}])
  assert.equal((await request('POST',path,body)).status,400);
 const denied=await harness({databaseError:{code:'P0001',message:'Trip access denied.'}});
 assert.equal((await denied.request('POST',path,{action:'delete',requestID,revision:4})).status,403);
 const stale=await harness({databaseError:{code:'P0001',message:'Trip conflict. Refresh before trying again.'}});
 assert.equal((await stale.request('POST',path,{action:'delete',requestID,revision:4})).status,409);
});

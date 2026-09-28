import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import {deliveryGate,drainQueues,settleBatch,workerFetch} from '../functions/_shared/queue-drain.mjs';

test('immediate same-city worker uses the interactive lease and no unrelated queues or scheduled heartbeat',async()=>{
 let handler,busy=false;const calls=[],heartbeats=[];
 const db={rpc:async(name,args)=>{calls.push({name,args});return {error:null,data:name==='wif_push_worker_acquire'?!busy:[]};}};
 const raw=(await readFile(new URL('../functions/push-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
 const unrelated=async()=>{throw Error('Unexpected unrelated queue');};
 vm.runInNewContext(stripTypeScriptTypes(raw,{mode:'transform'}),{
  Request,Response,Date,AbortSignal,crypto,console,deliveryGate,drainQueues,settleBatch,workerFetch,
  createClient:()=>db,normalizeAPNsPrivateKey:x=>x,
  deliverUpcoming:unrelated,deliverTripInvitations:unrelated,deliverFriendInvitations:unrelated,deliverTripBookingReminders:unrelated,
  backgroundObservation:p=>p,postHeartbeat:(...args)=>{heartbeats.push(args);return Promise.resolve();},
  Deno:{env:{get:n=>n==='WIF_OBSERVABILITY_ENABLED'?'true':'synthetic'},serve:f=>handler=f}
 });
 const request=(authorized=true)=>handler(new Request('https://example.invalid/push-worker',{method:'POST',
  headers:authorized?{Authorization:'Bearer synthetic'}:{},body:JSON.stringify({action:'colocation'})}));
 assert.equal((await request(false)).status,401);assert.equal(calls.length,0);
 const response=await request();assert.equal(response.status,200);
 assert.equal(calls[0].name,'wif_push_worker_acquire');assert.equal(calls[0].args.p_lane,'interactive');
 assert.ok(calls.some(c=>c.name==='wif_claim_notification_deliveries'));
 assert.equal(calls.at(-1).name,'wif_push_worker_release');assert.equal(heartbeats.length,0);
 assert.deepEqual(Object.keys((await response.json()).queues),['colocation']);
 calls.length=0;busy=true;
 assert.equal((await (await request()).json()).state,'busy');assert.equal(calls.length,1);
});

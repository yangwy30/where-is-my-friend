// Operational probes only: no test users, notification deliveries or paid-provider calls.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve} from 'node:path';
const cli=resolve('node_modules/.bin/supabase'),project='cdhpaujazbuppbxyhjxq';
const run=async args=>{try{return (await promisify(execFile)(cli,args,{timeout:60000,maxBuffer:2*1024*1024})).stdout;}catch{throw Error('Supabase command failed; output withheld.');}};
const query=async sql=>JSON.parse(await run(['db','query','--linked','--project-ref',project,'--output','json',sql])).rows;
const baseline=await query(`select wif_capacity_health() as health,
 exists(select 1 from supabase_migrations.schema_migrations where version='20260927010000') as migrated,
 has_function_privilege('anon','public.wif_capacity_health()','execute') as anonymous_health,
 has_function_privilege('authenticated','public.wif_flight_lookup_acquire(uuid,text,text,date,uuid)','execute') as direct_client_lookup,
 has_function_privilege('authenticated','public.wif_push_worker_acquire(uuid,text)','execute') as direct_client_worker`);
if(!baseline[0]?.migrated || baseline[0].anonymous_health || baseline[0].direct_client_lookup || baseline[0].direct_client_worker)throw Error('Migration or function boundary verification failed.');
const requests=await query(`select name,net.http_post(
 url:=(select decrypted_secret from vault.decrypted_secrets where name='wif_project_url')||'/functions/v1/'||f.name,
 headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='wif_push_worker_secret'),
 'apikey',(select decrypted_secret from vault.decrypted_secrets where name='wif_publishable_key')),
 body:='{"action":"check-capacity"}'::jsonb,timeout_milliseconds:=20000) as id
 from (values('push-worker'),('trip-worker')) f(name)`);
const ids=requests.map(row=>Number(row.id));if(ids.some(x=>!Number.isSafeInteger(x)))throw Error('Unexpected probe ID.');
let replies=[];
for(let attempt=0;attempt<8;attempt++){
 replies=await query(`select id,status_code,content from net._http_response where id in (${ids.join(',')})`);
 if(replies.length===ids.length)break;
 await new Promise(resolve=>setTimeout(resolve,1500));
}
const probes=replies.map(row=>{
 let body;try{body=JSON.parse(row.content);}catch{throw Error('Invalid health response.');}
 if(row.status_code!==200 || body.flightPolicy?.daily_total!==50 || body.flightPolicy?.daily_background!==20)throw Error('Worker health check failed.');
 return {name:requests.find(r=>Number(r.id)===Number(row.id)).name,status:row.status_code,policy:body.flightPolicy};
});
if(probes.length!==2)throw Error('Health requests did not finish.');
const functions=JSON.parse(await run(['functions','list','--project-ref',project,'--output','json']));
const required=functions.filter(f=>['api','push-worker','trip-worker'].includes(f.name));
if(required.length!==3)throw Error('Expected three deployed functions.');
for(const f of required){
 if(f.status!=='ACTIVE'||f.verify_jwt!==(f.name==='api'))throw Error('Function status/authentication changed.');
}
const keys=JSON.parse(await run(['projects','api-keys','--project-ref',project,'--reveal','--output','json']));
const anon=keys.find(k=>k.name==='anon')?.api_key;
if(!anon)throw Error('Public gateway key unavailable.');
const response=await fetch(`https://${project}.supabase.co/functions/v1/api/v1/snapshot`,{
 headers:{apikey:anon,Authorization:`Bearer ${anon}`},signal:AbortSignal.timeout(20000)});
const denial=await response.json();
if(response.status!==401 || denial.message!=='The session expired.')throw Error('API authentication boundary probe failed.');
console.log(JSON.stringify({verifiedAt:new Date().toISOString(),baseline:baseline[0],probes,apiAnonymousStatus:response.status,
 functions:functions.map(({name,version,status,verify_jwt})=>({name,version,status,verify_jwt}))},null,2));

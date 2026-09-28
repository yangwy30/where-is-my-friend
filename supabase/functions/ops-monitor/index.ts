import { authFailureStatus } from "../_shared/upstream-policy.mjs";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { clientObservation, postObservation } from "../_shared/observability.mjs";
import { boundedJSON, equalSecret, evaluateHealth, healthHTML } from "../_shared/ops-health.mjs";

const origin=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
const probeSecret=Deno.env.get('OPS_PROBE_TOKEN');
const db=createClient(origin,service,{auth:{persistSession:false,autoRefreshToken:false},db:{retry:false},
 global:{fetch:(input:any,init:any)=>fetch(input,{...init,signal:AbortSignal.timeout(4000)})}});
const headers={'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'GET,POST,OPTIONS'};
const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers});
let cached:{until:number,value:any}|undefined;
let pending:Promise<any>|undefined;
let failedUntil=0;
const seenBuckets=new Map<string,number>();
async function getHealth(){
 if(failedUntil>Date.now())throw Error('Probe cooling down');
 if(cached&&cached.until>Date.now())return cached.value;
 if(pending)return pending;
 pending=(async()=>{
  const [health,api]=await Promise.all([
   db.rpc('wif_ops_health'),
   fetch(origin+'/functions/v1/api/v1/ops-probe',{headers:{apikey:anon,Authorization:'Bearer '+anon},redirect:'error',signal:AbortSignal.timeout(8000)})
    .then(async r=>r.status===401&&/^[a-f0-9-]{36}$/i.test(r.headers.get('x-wif-request-id')??'')&&(await r.json()).message==='The session expired.').catch(()=>false)
  ]);
  if(health.error||!health.data||!Array.isArray(health.data.features)||!Array.isArray(health.data.queues)||!Array.isArray(health.data.workers))throw Error('Health storage unavailable');
  let signing=true;
  if(health.data.workers.some((w:any)=>w.worker==='push'&&w.expected)){
   const key=Deno.env.get('PUSH_WORKER_SECRET');
   signing=!!key&&await fetch(origin+'/functions/v1/push-worker',{method:'POST',headers:{apikey:anon,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:'{"action":"check-signing"}',redirect:'error',signal:AbortSignal.timeout(4000)})
    .then(async r=>r.ok&&(await r.json()).signingReady===true).catch(()=>false);
  }
  const result=evaluateHealth(health.data,{apiAvailable:api,pushSigningReady:signing});cached={value:result,until:Date.now()+20000};
  // Maintenance is bounded and never claims a notification or changes user data.
  const cleanup=db.rpc('wif_ops_prune').then(()=>{}).catch(()=>{});
  if(typeof EdgeRuntime!=='undefined')EdgeRuntime.waitUntil(cleanup);
  return result;
 })().catch(error=>{failedUntil=Date.now()+10000;throw error;}).finally(()=>{pending=undefined;});return pending;
}
Deno.serve(async request=>{
 const path=new URL(request.url).pathname.split('/').filter(Boolean);
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(request.method==='POST'&&path.at(-1)==='client-events'){
  const token=request.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];if(!token)return json({message:'Authentication required.'},401);
  try{
   const {data,error}=await db.auth.getUser(token);if(error||!data.user)return json({message:'Diagnostics authentication unavailable.'},error?authFailureStatus(error):401);
   let event;try{event=clientObservation(await boundedJSON(request));}catch{return json({message:'Invalid diagnostic event.'},400);}
   await postObservation(origin,service,event,{source:'client',authID:data.user.id,timeoutMs:2500});
   return new Response(null,{status:204,headers});
  }catch{return json({message:'Diagnostics unavailable.'},503);}
 }
 if(!['GET','HEAD'].includes(request.method)||path.at(-2)!=='status'||!probeSecret||probeSecret.length<32||!equalSecret(path.at(-1),probeSecret))return json({message:'Not found.'},404);
 try{
  const result=await getHealth();
  const external=/uptimerobot/i.test(request.headers.get('user-agent')??''),kind=external?'external':'manual',bucket=Math.floor(Date.now()/60000);
  if(seenBuckets.get(kind)!==bucket){
   seenBuckets.set(kind,bucket);
   const seen=db.rpc('wif_ops_probe_seen',{p_external:external}).then(()=>{}).catch(()=>{});
   if(typeof EdgeRuntime!=='undefined')EdgeRuntime.waitUntil(seen);
  }
  return new Response(request.method==='HEAD'?null:healthHTML(result),{status:result.status==='ok'?200:503,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'"}});
 }catch{return json({status:'unavailable'},503);}
});

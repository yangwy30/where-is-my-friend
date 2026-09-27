import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import {performance} from 'node:perf_hooks';
import {isUUID,normalizeAPIPath} from '../../supabase/functions/_shared/domain.mjs';
import {resilientSupabaseFetch,temporaryStatus,authFailureStatus} from '../../supabase/functions/_shared/upstream-policy.mjs';
import {travelPlanInput} from '../../supabase/functions/_shared/travel-plans.mjs';
import {flightLookupInput,FlightLookupError} from '../../supabase/functions/_shared/flight-lookup.mjs';

export async function createHarness(pool, tokens, metrics) {
 const database={
  auth:{getUser:async token=>{
   // Simulated identity service latency; this is not an Apple/Supabase Auth benchmark.
   await new Promise(resolve=>setTimeout(resolve,25));
   return tokens.has(token)?{data:{user:{id:tokens.get(token)}},error:null}:{data:{user:null},error:{status:401,code:'bad_jwt'}};
  }},
  rpc:async(name,args={})=>{
   if(!/^wif_[a-z0-9_]+$/.test(name)||Object.keys(args).some(k=>!/^p_[a-z_]+$/.test(k)))throw Error('Unexpected RPC');
   const queued=performance.now();let client,started;
   try{
    client=await pool.connect();started=performance.now();
    const keys=Object.keys(args);
    const sql=`select public.${name}(${keys.map((k,i)=>`${k} => $${i+1}`).join(',')}) as value`;
    const result=await client.query(sql,Object.values(args));
    metrics.push({name,waitMs:started-queued,sqlMs:performance.now()-started,ok:true});
    return {data:result.rows[0].value,error:null};
   }catch(error){
    metrics.push({name,waitMs:(started??performance.now())-queued,sqlMs:started?performance.now()-started:0,ok:false,code:error.code??'pool_timeout',constraint:error.constraint});
    return {data:null,error:{code:error.code??'PGRST003',message:error.message},status:error.code==='23505'?409:error.code==='57014'?500:error.code?400:503};
   }finally{client?.release();}
  },
 };
 let handler;
 const source=(await readFile(new URL('../../supabase/functions/api/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
 const noExternal=()=>{throw Error('External service disabled in load test');};
 vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),{
  Request,Response,URL,console,crypto,AbortSignal,Date,
  isUUID,normalizeAPIPath,resilientSupabaseFetch,temporaryStatus,authFailureStatus,travelPlanInput,flightLookupInput,FlightLookupError,
  sharedFlightLookup:noExternal,fetchFlightLookup:noExternal,fetch:noExternal,wakeInvitationWorker:()=>false,
  createClient:()=>database,
  Deno:{env:{get:name=>name==='SUPABASE_URL'?'http://127.0.0.1':'synthetic-test-only'},serve:callback=>handler=callback},
 });
 return {handler,database};
}

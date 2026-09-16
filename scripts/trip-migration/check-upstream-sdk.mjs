// Local fault injection using the exact production SDK; no network or credentials.
import assert from 'node:assert/strict';
import {createRequire,stripTypeScriptTypes} from 'node:module';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import vm from 'node:vm';
import {isUUID,normalizeAPIPath} from '../../supabase/functions/_shared/domain.mjs';
import {resilientSupabaseFetch,temporaryStatus,authFailureStatus} from '../../supabase/functions/_shared/upstream-policy.mjs';
const {createClient}=createRequire(resolve(process.argv[2],'package.json'))('@supabase/supabase-js');
const source=(await readFile('supabase/functions/api/index.ts','utf8')).replace(/^import .*;[^\n]*\n/gm,'');
const authID='10000000-0000-0000-0000-000000000001',appID='20000000-0000-0000-0000-000000000001';
let passed=0;
for(const scenario of ['auth-timeout','auth-recovery','profile-timeout','invalid-auth','read-recovery']){
 let handler;const calls=[],logs=[];
 const fakeFetch=async request=>{
   const path=new URL(request.url).pathname;calls.push(path);
   const count=calls.filter(p=>p===path).length;
   if(path==='/auth/v1/user'){
     if(scenario==='invalid-auth')return Response.json({code:'bad_jwt',message:'invalid'},{status:403});
     if(scenario==='auth-timeout'||(scenario==='auth-recovery'&&count===1))return new Response('Gateway Timeout',{status:504});
     return Response.json({id:authID,aud:'authenticated'});
   }
   if(path.endsWith('wif_resolve_app_user')){
     if(scenario==='read-recovery'&&count===1)return new Response('Gateway Timeout',{status:504});
     return Response.json(appID);
   }
   if(path.endsWith('wif_update_profile'))return scenario==='profile-timeout'
      ?new Response('Gateway Timeout',{status:504}):Response.json({currentUser:{id:appID}});
   throw new Error('Unexpected transport route');
 };
 vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),{
   Request,Response,URL,console,isUUID,normalizeAPIPath,temporaryStatus,authFailureStatus,
   createClient,
   resilientSupabaseFetch:origin=>resilientSupabaseFetch(origin,{fetchImpl:fakeFetch,delay:async()=>{},log:entry=>logs.push(entry)}),
   Deno:{env:{get:key=>key==='SUPABASE_URL'?'https://example.supabase.co':'test-only'},serve:callback=>handler=callback},
 });
 const result=await handler(new Request('https://example.supabase.co/functions/v1/api/v1/profile',{
   method:'PATCH',headers:{Authorization:'Bearer test-only','Content-Type':'application/json'},
   body:JSON.stringify({displayName:'Test',username:'test',avatarPalette:1})}));
 const expected=scenario==='auth-timeout'||scenario==='profile-timeout'?504:scenario==='invalid-auth'?401:200;
 assert.equal(result.status,expected,scenario+': '+await result.text());
 assert.equal(calls.filter(p=>p==='/auth/v1/user').length,['auth-timeout','auth-recovery'].includes(scenario)?2:1);
 assert.equal(calls.filter(p=>p.endsWith('wif_update_profile')).length,['auth-timeout','invalid-auth'].includes(scenario)?0:1);
 assert.equal(calls.filter(p=>p.endsWith('wif_resolve_app_user')).length,scenario==='read-recovery'?2:['auth-timeout','invalid-auth'].includes(scenario)?0:1);
 assert.doesNotMatch(JSON.stringify(logs),/Bearer|test-only|displayName/);
 console.log(JSON.stringify({scenario,status:result.status,requests:calls.length,passed:true}));passed++;
}
console.log(`${passed} real-SDK fault-injection cases passed; zero network requests.`);

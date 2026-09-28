import {readFile,writeFile} from 'node:fs/promises';import {randomUUID} from 'node:crypto';
import {loadTarget,requestJSON} from '../staging/target.mjs';import {assertIsolation,keys,query} from '../staging/management.mjs';
const target=await loadTarget('.staging-private/target.json');await assertIsolation(target);
const monitor=JSON.parse(await readFile('.ops-private/staging-monitor.json','utf8'));if(monitor.projectRef!==target.projectRef)throw Error('Wrong monitor target');
const {anon,service}=await keys(target),checks=[],tag=randomUUID(),accounts=[],events=[];
const report={projectRef:target.projectRef,startedAt:new Date().toISOString(),checks,realEmailSent:false,realAPNs:false};
async function rpc(name,body){const r=await requestJSON(target.origin+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:anon,Authorization:'Bearer '+service},body});if(r.status!==200)throw Error(name+' returned '+r.status);return r.data;}
async function auth(path,body,key=service,method='POST'){const r=await requestJSON(target.origin+'/auth/v1/'+path,{method,headers:{apikey:anon,Authorization:'Bearer '+key},body});if(r.status!==200)throw Error('Auth request returned '+r.status);return r.data;}
const waitCache=()=>new Promise(r=>setTimeout(r,21000));
async function health(expected){const r=await fetch(monitor.url,{redirect:'error',signal:AbortSignal.timeout(15000)});if(r.status!==expected)throw Error('Probe returned '+r.status+' expected '+expected);return r.text();}
try{
 const bad=await fetch(target.origin+'/functions/v1/ops-monitor/status/not-a-key');if(bad.status!==404)throw Error('Secret probe must be protected');checks.push('Unknown probe token rejected');
 const email='ops-smoke-'+tag+'@example.invalid',password=randomUUID()+randomUUID();const user=await auth('admin/users',{email,password,email_confirm:true,app_metadata:{ops_test_run:tag}});accounts.push(user.id);
 await writeFile('.ops-private/staging-smoke-accounts.json',JSON.stringify({projectRef:target.projectRef,accounts}),{mode:0o600});
 const session=await auth('token?grant_type=password',{email,password},anon),id=randomUUID();events.push(id);
 const bootstrap=await fetch(target.origin+'/functions/v1/api/v1/auth/bootstrap',{method:'POST',headers:{apikey:anon,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json','x-wif-request-id':id,'x-wif-app-version':'ops-smoke'},body:'{}'});
 if(bootstrap.status!==200||bootstrap.headers.get('x-wif-request-id')!==id)throw Error('API observation header missing');checks.push('Real authenticated API keeps response and correlation ID');
 const event={eventID:randomUUID(),feature:'plans',kind:'decode_error',status:200,elapsedMs:100,version:'ops-smoke'};events.push(event.eventID);
 const endpoint=target.origin+'/functions/v1/ops-monitor/client-events';
 const unauthorized=await requestJSON(endpoint,{method:'POST',body:event});if(unauthorized.status!==401)throw Error('Unauthenticated collector accepted');checks.push('Client collector requires a real session');
 const extra=await requestJSON(endpoint,{method:'POST',headers:{Authorization:'Bearer '+session.access_token},body:{...event,message:'must-not-be-stored'}});if(extra.status!==400)throw Error('Raw message accepted');checks.push('Raw text and unexpected metadata rejected');
 const accepted=await requestJSON(endpoint,{method:'POST',headers:{Authorization:'Bearer '+session.access_token},body:event});if(accepted.status!==204)throw Error('Client collector failed');checks.push('Authenticated mobile error captured');
 const originalOverview=(await query(target,"select pg_get_functiondef('public.wif_travel_overview(uuid)'::regprocedure) definition"))[0].definition;
 await writeFile('.ops-private/staging-overview-restore.sql',originalOverview+';',{mode:0o600});
 const faultID=randomUUID();events.push(faultID);
 try{
  await query(target,"create or replace function public.wif_travel_overview(p_user_id uuid) returns jsonb language plpgsql stable security definer set search_path=public as $$ begin raise exception 'Isolated monitoring test' using errcode='08006';end; $$;");
  const failed=await fetch(target.origin+'/functions/v1/api/v2/travel-plans',{headers:{apikey:anon,Authorization:'Bearer '+session.access_token,'x-wif-request-id':faultID,'x-wif-app-version':'ops-smoke'}});
  if(failed.status<500)throw Error('Isolated fault did not exercise API failure path');
  let recorded=false;
  for(let i=0;i<10&&!recorded;i++){recorded=(await query(target,`select exists(select 1 from wif_ops_events where source='server' and event_id='${faultID}'::uuid) found`))[0].found;if(!recorded)await new Promise(r=>setTimeout(r,300));}
  if(!recorded)throw Error('Real API failure was not recorded');checks.push('A real isolated API failure records a correlated server event');
 }finally{await query(target,originalOverview+';');}
 await query(target,"delete from wif_ops_events where source='server' and app_version='ops-smoke'");
 await health(200);checks.push('A single report does not create an alert');
 for(let n=0;n<5;n++){const eid=randomUUID();events.push(eid);await rpc('wif_ops_record_event',{p_source:'server',p_event_id:eid,p_feature:'plans',p_kind:'server_error',p_status:503,p_elapsed_ms:600,p_version:'ops-smoke'});}
 await waitCache();const down=await health(503);if(!down.includes('Friend plans')||!down.includes('Needs attention'))throw Error('Wrong degraded page');checks.push('Repeated plan failures produce an unhealthy probe');
 await query(target,"delete from wif_ops_events where app_version='ops-smoke'");await waitCache();await health(200);checks.push('Recovery returns the probe to healthy');
 await query(target,"update wif_ops_settings set expect_push=true,enabled_at=now()-interval '20 minutes'");await waitCache();await health(503);checks.push('Stopped/unconfigured worker detected even with an empty queue');
 await query(target,"update wif_ops_settings set expect_push=false,expect_trip=false,enabled_at=now()");await waitCache();await health(200);checks.push('Worker configuration recovery clears the incident');report.passed=true;
}catch(e){report.passed=false;report.error=e.message;process.exitCode=1;}
finally{
 await query(target,"delete from wif_ops_events where app_version='ops-smoke';update wif_ops_settings set expect_push=false,expect_trip=false,enabled_at=now();");
 for(const id of accounts)await auth('admin/users/'+id,undefined,service,'DELETE');
 report.cleanedAccounts=accounts.length;report.finishedAt=new Date().toISOString();await writeFile('.ops-private/staging-smoke-report.json',JSON.stringify(report,null,2),{mode:0o600});console.log(JSON.stringify(report));
}

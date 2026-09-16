// Two isolated temporary Auth accounts; no real devices, APNs or flight lookup.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
import {writeFile,mkdtemp} from 'node:fs/promises';
const project='cdhpaujazbuppbxyhjxq',base=`https://${project}.supabase.co`,tag=randomUUID();
const accounts=[],report={project,checks:[],cleanup:[],startedAt:new Date().toISOString()};
let service,anon;
async function command(args){return (await promisify(execFile)(resolve('node_modules/.bin/supabase'),args,{timeout:60000,maxBuffer:1024*1024})).stdout;}
async function auth(path,method,body,key){
 const r=await fetch(base+'/auth/v1/'+path,{method,headers:{apikey:anon??key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 if(!r.ok)throw new Error(`Auth operation returned ${r.status}`);return r.json();
}
async function api(token,method,path,body,expected=200){
 const r=await fetch(base+'/functions/v1/api'+path,{method,headers:{apikey:anon,...(token?{Authorization:`Bearer ${token}`} : {}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
 if(r.status!==expected)throw new Error(`${method} ${path} returned ${r.status}; expected ${expected}`);return r.json();
}
function check(label,condition=true){if(!condition)throw new Error(label);report.checks.push(label);console.log(label);}
try {
 const keys=JSON.parse(await command(['projects','api-keys','--project-ref',project,'--reveal','--output','json']));
 service=keys.find(k=>k.name==='service_role')?.api_key;anon=keys.find(k=>k.name==='anon')?.api_key;
 if(!service||!anon)throw new Error('Credentials unavailable');
 await api(anon,'GET','/v1/travel-plans',undefined,401);
 const worker=await fetch(base+'/functions/v1/push-worker',{method:'POST',headers:{apikey:anon,Authorization:`Bearer ${anon}`},signal:AbortSignal.timeout(20000)});
 check('Public keys cannot access plans or run push worker',worker.status===401);
 for(const suffix of ['a','b']) {
  const email=`travel-smoke-${tag}-${suffix}@example.invalid`,password=randomUUID()+randomUUID();
  const account=await auth('admin/users','POST',{email,password,email_confirm:true},service);
  if(!account?.id)throw new Error('Temporary account creation failed');accounts.push({id:account.id});
  const session=await auth('token?grant_type=password','POST',{email,password},anon);
  const profile=await api(session.access_token,'POST','/v1/auth/bootstrap',{displayName:'Travel smoke test'});
  Object.assign(accounts.at(-1),{token:session.access_token,appID:profile.currentUser.id,username:profile.currentUser.username});
 }
 const [a,b]=accounts;
 await api(a.token,'POST','/v1/friends/requests',{username:b.username});
 const pending=await api(b.token,'GET','/v1/bootstrap');
 const invitation=pending.friendRequests.find(r=>r.userID===a.appID);
 if(!invitation)throw new Error('Test friendship request not found');
 await api(b.token,'PATCH',`/v1/friends/requests/${invitation.id}`,{response:'accept'});
 const day=n=>new Date(Date.now()+n*86400000).toISOString().slice(0,10);
 const input={city:'Palm Springs',countryCode:'US',region:'CA',timeZone:'America/Los_Angeles',startDay:day(5),endDay:day(10),audience:[],alertsEnabled:false,revision:0};
 const aid=randomUUID(),bid=randomUUID(),path=id=>`/v1/travel-plans/${id}`;
 let sa=await api(a.token,'PUT',path(aid),input);
 const ownOnly=await api(b.token,'GET','/v1/travel-plans');
 check('New plan private by default; another account cannot read it',sa.plans[0].audience.length===0&&!sa.plans[0].alertsEnabled&&ownOnly.plans.length===0);
 await api(b.token,'PUT',path(aid),{...input,revision:1},403);
 await api(a.token,'PUT',path(aid),{...input,ownerID:b.appID},400);
 check('Cross-owner edits and identity injection rejected');
 await api(b.token,'PUT',path(bid),{...input,audience:[a.appID],startDay:day(7),endDay:day(12)});
 check('One-way sharing produces no overlap',(await api(a.token,'GET','/v1/travel-plans')).overlaps.length===0);
 sa=await api(a.token,'PUT',path(aid),{...input,revision:1,audience:[b.appID]});
 const sb=await api(b.token,'GET','/v1/travel-plans');
 check('Both accounts see exactly the shared intersection',sa.overlaps.length===1&&sb.overlaps.length===1&&sa.overlaps[0].startDay===day(7)&&sa.overlaps[0].endDay===day(10));
 await api(a.token,'PUT',path(aid),{...input,revision:1},409);
 check('Stale device edit rejected');
 await api(a.token,'PUT',path(aid),{...input,revision:2});
 check('Revoking audience removes the other account’s overlap',(await api(b.token,'GET','/v1/travel-plans')).overlaps.length===0);
 await api(a.token,'DELETE',path(aid),{revision:3});
 check('Deleting a plan persists in cloud',(await api(a.token,'GET','/v1/travel-plans')).plans.length===0);
 await api(b.token,'DELETE',path(bid),{revision:1});
 report.passed=true;
} catch(error){report.passed=false;report.error=error.message;console.error(report.error);process.exitCode=1;}
finally {
 if(service)for(const account of accounts){
  try{await auth('admin/users/'+account.id,'DELETE',undefined,service);report.cleanup.push('Temporary Auth account and cascading data removed');}
  catch{report.cleanup.push(`Cleanup required for temporary Auth account ${account.id}`);process.exitCode=1;}
 }
 report.finishedAt=new Date().toISOString();
 const directory=await mkdtemp(resolve('.migration-backups/travel-smoke-'));
 await writeFile(resolve(directory,'report.json'),JSON.stringify(report,null,2),{flag:'wx',mode:0o600});
 console.log(JSON.stringify({directory,passed:report.passed,checks:report.checks.length,cleanup:report.cleanup}));
}

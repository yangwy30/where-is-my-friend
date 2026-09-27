import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {loadTarget,validatePrivateSession,requestJSON} from './target.mjs';
import {assertIsolation} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');await assertIsolation(target);
const session=validatePrivateSession(JSON.parse(await readFile('.staging-private/sessions.json','utf8')),target);
const [a,b]=session.accounts,aid=randomUUID(),bid=randomUUID(),owned=new Map(),checks=[];
const report={projectRef:target.projectRef,startedAt:new Date().toISOString(),checks,realPush:false,paidProviderCalls:false};
async function api(actor,method,path,body,status=200){
 const result=await requestJSON(target.origin+'/functions/v1/api'+path,{method,headers:{apikey:session.anon,...(actor?{Authorization:'Bearer '+actor.token}:{})},body});
 if(result.status!==status)throw Error(`${method} ${path.split('?')[0]} returned ${result.status}; expected ${status}`);return result.data;
}
function check(name,value){if(!value)throw Error(name);checks.push(name);}
const day=n=>new Date(Date.now()+n*86400000).toISOString().slice(0,10);
const payload={city:'Tokyo',countryCode:'JP',region:'Tokyo',timeZone:'Asia/Tokyo',startDay:day(7),endDay:day(10),audience:[],alertsEnabled:false,allowFriendBrowsing:true,revision:0};
async function save(actor,id,value){const r=await api(actor,'PUT','/v1/travel-plans/'+id,value);const row=r.plans.find(p=>p.id===id);if(!row)throw Error('Saved plan missing from owner response');owned.set(id,{actor,revision:row.revision});return row;}
try{
 await api(null,'GET','/v2/travel-plans',undefined,401);checks.push('Unauthenticated overview rejected');
 await save(a,aid,payload);
 check('Private plan absent from another account',(await api(b,'GET','/v2/friend-plans?planID='+aid)).items.length===0);
 await api(b,'PUT','/v1/travel-plans/'+aid,{...payload,revision:1},403);checks.push('Cross-owner edit rejected');
 await api(a,'PUT','/v1/travel-plans/'+aid,{...payload,revision:1,ownerID:b.appID},400);checks.push('Injected owner rejected');
 await save(b,bid,{...payload,startDay:day(9),endDay:day(12),audience:[a.appID]});
 await save(a,aid,{...payload,revision:1,audience:[b.appID]});
 const full=await api(b,'GET','/v2/travel-overlaps');
 const overlap=full.overlaps.find(x=>x.friendID===a.appID&&x.city==='Tokyo'&&x.startDay===day(9)&&x.endDay===day(10));
 check('Reciprocal plan dates produce the correct intersection',!!overlap);
 check('Shared plan is browsable',(await api(b,'GET','/v2/friend-plans?planID='+aid)).items.some(x=>x.id===aid));
 check('Notification detail resolves its exact overlap',(await api(b,'GET','/v2/travel-overlaps/'+overlap.id)).overlaps.some(x=>x.id===overlap.id));
 await api(a,'PUT','/v1/travel-plans/'+aid,{...payload,revision:1},409);checks.push('Stale revision rejected');
 await save(a,aid,{...payload,revision:2});
 check('Revoked plan disappears from the other account',(await api(b,'GET','/v2/friend-plans?planID='+aid)).items.length===0);
 check('Revoked overlap detail disappears',(await api(b,'GET','/v2/travel-overlaps/'+overlap.id)).overlaps.length===0);
 report.passed=true;
}catch(error){report.passed=false;report.error=error.message;process.exitCode=1;}
finally{
 report.cleanup=[];
 for(const [id,{actor,revision}] of owned){try{await api(actor,'DELETE','/v1/travel-plans/'+id,{revision});report.cleanup.push({planID:id,removed:true});}catch{report.cleanup.push({planID:id,removed:false});report.passed=false;process.exitCode=1;}}
 report.finishedAt=new Date().toISOString();await mkdir('.staging-private/results',{recursive:true,mode:0o700});await writeFile('.staging-private/results/smoke.json',JSON.stringify(report,null,2),{mode:0o600});console.log(JSON.stringify(report));
}

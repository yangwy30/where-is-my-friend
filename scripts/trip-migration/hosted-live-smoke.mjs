// Uses two temporary accounts and an unverified flight. No real devices or provider calls.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
import {writeFile} from 'node:fs/promises';
const project='cdhpaujazbuppbxyhjxq',base=`https://${project}.supabase.co`;
const tag=randomUUID().replaceAll('-','').slice(0,16),tripID=`deployment-smoke-${tag}`;
const accounts=[],report={project,tripID,checks:[],cleanup:[],startedAt:new Date().toISOString()};
let service,anon;
async function command(args){return (await promisify(execFile)(resolve('node_modules/.bin/supabase'),args,{timeout:60000,maxBuffer:1024*1024})).stdout;}
async function auth(path,method,body,key){
 const r=await fetch(base+'/auth/v1/'+path,{method,headers:{apikey:anon??key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 if(!r.ok)throw new Error(`Auth operation returned ${r.status}`);
 return r.json();
}
async function api(token,method,path,body,expected=200){
 const r=await fetch(base+'/functions/v1/api'+path,{method,headers:{apikey:anon,...(token?{Authorization:`Bearer ${token}`} : {}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
 if(r.status!==expected)throw new Error(`${method} ${path.replace(tripID,'[smoke-trip]')} returned ${r.status}; expected ${expected}`);
 return r.json();
}
function check(label,condition=true){if(!condition)throw new Error(label);report.checks.push(label);console.log(label);}
try {
 const keys=JSON.parse(await command(['projects','api-keys','--project-ref',project,'--reveal','--output','json']));
 service=keys.find(k=>k.name==='service_role')?.api_key;anon=keys.find(k=>k.name==='anon')?.api_key;
 if(!service||!anon)throw new Error('Required credentials unavailable');
 for(const action of ['preferences','meeting','check-in'])await api(anon,'POST',`/v1/trips/${tripID}/${action}`,{},401);
 const worker=await fetch(base+'/functions/v1/trip-worker',{method:'POST',headers:{apikey:anon,Authorization:`Bearer ${anon}`},signal:AbortSignal.timeout(20000)});
 check('Public keys cannot mutate trips or run background worker',worker.status===401);
 for(const suffix of ['a','b']) {
  const email=`trips-deployment-${tag}-${suffix}@example.invalid`,password=randomUUID()+randomUUID();
  const account=await auth('admin/users','POST',{email,password,email_confirm:true},service);
  if(!account?.id)throw new Error('Temporary account creation failed');
  accounts.push({id:account.id});
  const session=await auth('token?grant_type=password','POST',{email,password},anon);
  const profile=await api(session.access_token,'POST','/v1/auth/bootstrap',{displayName:'Trips live smoke test'});
  Object.assign(accounts.at(-1),{token:session.access_token,appID:profile.currentUser.id,username:profile.currentUser.username});
 }
 const [a,b]=accounts,day=new Date().toISOString().slice(0,10),path=`/v1/trips/${tripID}`;
 const trip=await api(a.token,'POST','/v1/trips',{id:tripID,name:'Live deployment smoke test',destinationAirport:'LAX',startDate:day,endDate:day});
 await api(b.token,'POST',path+'/preferences',{enabled:true},403);
 await api(b.token,'POST',path+'/check-in',{state:'landed'},403);
 const invite=await api(a.token,'POST',path+'/invitations',{username:b.username});
 const joined=await api(b.token,'POST',`/v1/trip-invitations/${invite.id}/accept`,{});
 check('Account-bound invitation works; alerts default off for both members',trip.flight_alerts_enabled===false&&joined.flight_alerts_enabled===false);
 const opted=await api(b.token,'POST',path+'/preferences',{enabled:true});
 const owner=await api(a.token,'GET',path);
 check('Alert preferences are independent per member',opted.flight_alerts_enabled===true&&owner.flight_alerts_enabled===false);
 await api(b.token,'POST',path+'/meeting',{point:'Unauthorized',revision:owner.revision},403);
 const meeting=await api(a.token,'POST',path+'/meeting',{point:'Terminal 4, exit B',revision:owner.revision});
 await api(a.token,'POST',path+'/meeting',{point:'Stale edit',revision:owner.revision},409);
 check('Only owner edits meeting point; stale revision rejected',meeting.meeting_point==='Terminal 4, exit B');
 await api(b.token,'POST',path+'/check-in',{state:'bags_collected',userID:a.appID},400);
 await api(b.token,'POST',path+'/check-in',{state:'invalid'},400);
 const checked=await api(b.token,'POST',path+'/check-in',{state:'bags_collected'});
 check('Check-in updates self only and rejects identity injection',checked.participants.find(p=>p.user_id===b.appID).check_in==='bags_collected'&&checked.participants.find(p=>p.user_id===a.appID).check_in==='not_set');
 const shared=await api(a.token,'GET',path);
 check('Other member sees shared meeting point and manual check-in',shared.meeting_point===meeting.meeting_point&&shared.participants.find(p=>p.user_id===b.appID).check_in==='bags_collected');
 const cleared=await api(b.token,'POST',path+'/check-in',{state:'not_set'});
 check('Member can clear own check-in and timestamp',cleared.participants.find(p=>p.user_id===b.appID).check_in_at===null);
 const empty=await api(a.token,'POST',path+'/meeting',{point:'',revision:meeting.revision});
 check('Owner can remove meeting point',empty.meeting_point==='');
 await api(b.token,'POST',path+'/preferences',{enabled:false});
 report.passed=true;
} catch(error){report.passed=false;report.error=error.message;console.error(report.error);process.exitCode=1;}
finally {
 if(service){
  try {
   await command(['db','query','--linked','--project-ref',project,'--output','json',`delete from public.trips where id='${tripID}' and name='Live deployment smoke test';`]);
   report.cleanup.push('Exact temporary trip removed');
  }catch{report.cleanup.push('Temporary trip cleanup needs attention');process.exitCode=1;}
  for(const account of accounts){try{await auth('admin/users/'+account.id,'DELETE',undefined,service);report.cleanup.push('Temporary Auth account removed');}
   catch{report.cleanup.push('Temporary Auth account cleanup needs attention');process.exitCode=1;}}
 }
 report.finishedAt=new Date().toISOString();
 await writeFile(resolve('.migration-backups/app-predeploy-G66dcS/hosted-live-smoke-'+tag+'.json'),JSON.stringify(report,null,2),{flag:'wx',mode:0o600});
 console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,cleanup:report.cleanup},null,2));
}

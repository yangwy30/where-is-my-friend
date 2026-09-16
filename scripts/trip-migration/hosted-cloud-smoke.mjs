// Two temporary accounts; only their exact records are written or cleaned up.
// Credentials stay in process memory. Provider calls: at most one cache miss.
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
 for(const path of ['/v1/flights/lookup','/v1/trips/not-member/flight-lookup']) {
  await api(anon,'POST',path,{flightNumber:'INVALID/INPUT',date:'invalid'},401);
 }
 check('Public keys cannot call flight lookup');
 for(const suffix of ['a','b']) {
  const email=`trips-deployment-${tag}-${suffix}@example.invalid`,password=randomUUID()+randomUUID();
  const account=await auth('admin/users','POST',{email,password,email_confirm:true},service);
  if(!account?.id)throw new Error('Temporary account creation failed');
  accounts.push({id:account.id});
  const session=await auth('token?grant_type=password','POST',{email,password},anon);
  const profile=await api(session.access_token,'POST','/v1/auth/bootstrap',{displayName:'Trips cloud smoke test'});
  Object.assign(accounts.at(-1),{token:session.access_token,appID:profile.currentUser.id,username:profile.currentUser.username});
 }
 const [a,b]=accounts,day=new Date().toISOString().slice(0,10);
 await api(a.token,'POST','/v1/friends/requests',{username:b.username});
 const pendingFriend=await api(b.token,'GET','/v1/bootstrap');
 const request=pendingFriend.friendRequests.find(r=>r.userID===a.appID);
 if(!request)throw new Error('Temporary friend request missing');
 await api(b.token,'PATCH',`/v1/friends/requests/${request.id}`,{response:'accept'});
 check('Existing friend invitation flow still works');
 const trip=await api(a.token,'POST','/v1/trips',{id:tripID,name:'Deployment smoke test',destinationAirport:'LAX',startDate:day,endDate:day});
 await api(a.token,'POST','/v1/trips',{id:tripID,name:'Deployment smoke test',destinationAirport:'LAX',startDate:day,endDate:day});
 check('Cloud trip creation is idempotent',trip.revision===1);
 const invite=()=>api(a.token,'POST',`/v1/trips/${tripID}/invitations`,{username:b.username});
 const first=await invite();
 const incoming=await api(b.token,'GET','/v1/trip-invitations');
 const outgoing=await api(a.token,'GET',`/v1/trips/${tripID}/invitations`);
 check('Recipient inbox and owner outgoing list match',incoming.invitations[0].id===first.id&&outgoing.invitations[0].recipient_id===b.appID);
 await api(b.token,'GET',`/v1/trips/${tripID}`,undefined,403);
 await api(a.token,'POST',`/v1/trip-invitations/${first.id}/accept`,{},403);
 await api(a.token,'POST',`/v1/trip-invitations/${first.id}/revoke`,{});
 await api(b.token,'POST',`/v1/trip-invitations/${first.id}/accept`,{},403);
 const second=await invite();
 await api(b.token,'POST',`/v1/trip-invitations/${second.id}/decline`,{});
 const third=await invite();
 check('Revoking, declining and reissuing rotate invitation links',first.id!==second.id&&second.id!==third.id);
 await api(b.token,'POST',`/v1/trip-invitations/${second.id}/accept`,{},403);
 const joined=await api(b.token,'POST',`/v1/trip-invitations/${third.id}/accept`,{});
 await api(b.token,'POST',`/v1/trip-invitations/${third.id}/accept`,{});
 check('Only explicit recipient acceptance creates membership once',joined.participants.length===2);
 const mutate=(actor,kind,payload,revision,expected=200)=>api(actor.token,'POST',`/v1/trips/${tripID}/mutations`,{kind,payload,...(revision===undefined?{}:{revision})},expected);
 const fa={id:`smoke-flight-a-${tag}`,flightNumber:'UA353',date:day,direction:'outbound'};
 const fb={...fa,id:`smoke-flight-b-${tag}`};
 await Promise.all([mutate(a,'addFlight',fa),mutate(b,'addFlight',fb)]);
 const after=await api(b.token,'GET',`/v1/trips/${tripID}`);
 check('Concurrent member additions preserve both flights',after.flights.length===2);
 const bFlight=after.flights.find(f=>f.id===fb.id);
 await mutate(a,'deleteFlight',{id:fb.id},bFlight.revision,403);
 await mutate(b,'completion',{completed:true},trip.revision,403);
 await mutate(b,'editFlight',{...fb,flightNumber:'DL12'},bFlight.revision-1,409);
 check('Owner cannot change another member flight; stale edits rejected');
 const lookup=await api(b.token,'POST',`/v1/trips/${tripID}/flight-lookup`,{flightNumber:'UA353',date:day});
 check('Authenticated provider search returns candidates',lookup.source==='aerodatabox'&&lookup.flights.length>0);
 const verified=await mutate(b,'editFlight',{...fb,candidateID:lookup.flights[0].id},bFlight.revision);
 const saved=verified.flights.find(f=>f.id===fb.id);
 check('Server persists selected real route and verification timestamp',saved.departure.code===lookup.flights[0].departure.code&&!!saved.verified_at);
 const aView=await api(a.token,'GET',`/v1/trips/${tripID}`);
 check('Other account reads the same selected route',aView.flights.find(f=>f.id===fb.id).candidate_id===saved.candidate_id);
 await mutate(b,'deleteFlight',{id:fb.id},saved.revision);
 const completed=await mutate(a,'completion',{completed:true},trip.revision);
 await mutate(a,'completion',{completed:false},trip.revision,409);
 const restored=await mutate(a,'completion',{completed:false},completed.revision);
 check('Completion and undo preserve trip data with revision protection',restored.completed_at===null&&restored.flights.length===1);
 report.passed=true;
} catch(error){report.passed=false;report.error=error.message;console.error(report.error);process.exitCode=1;}
finally {
 if(service){
  try {
   const ids=accounts.map(a=>a.appID).filter(id=>/^[0-9a-f-]{36}$/i.test(id));
   const sql=`delete from public.trips where id='${tripID}' and name='Deployment smoke test';`+
    (ids.length?` delete from public.trip_flight_lookup_limits where bucket in (${ids.map(id=>`'${id}'`).join(',')});`:'');
   await command(['db','query','--linked','--project-ref',project,'--output','json',sql]);report.cleanup.push('Exact temporary trip removed');
  }catch{report.cleanup.push('Temporary trip cleanup needs attention');process.exitCode=1;}
  for(const account of accounts){try{await auth('admin/users/'+account.id,'DELETE',undefined,service);report.cleanup.push('Temporary Auth account removed');}
   catch{report.cleanup.push('Temporary Auth account cleanup needs attention');process.exitCode=1;}}
 }
 report.finishedAt=new Date().toISOString();
 await writeFile(resolve('.migration-backups/app-predeploy-6qjfEk/hosted-cloud-smoke-'+tag+'.json'),JSON.stringify(report,null,2),{flag:'wx',mode:0o600});
 console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,cleanup:report.cleanup},null,2));
}

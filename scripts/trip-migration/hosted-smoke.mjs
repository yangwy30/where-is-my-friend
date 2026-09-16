// Authorized deployment verification with two temporary accounts. No existing user's session/data is used.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
import {writeFile} from 'node:fs/promises';
const project='cdhpaujazbuppbxyhjxq', base=`https://${project}.supabase.co`;
const cli=resolve('node_modules/.bin/supabase');
const tag=randomUUID().replaceAll('-','').slice(0,16), tripID=`deployment-smoke-${tag}`;
const report={project,tripID,checks:[],cleanup:[],startedAt:new Date().toISOString()};
const accounts=[];
let service,anon,actorID;
async function command(args){return (await promisify(execFile)(cli,args,{timeout:60000,maxBuffer:1024*1024})).stdout;}
async function auth(path,method,body,key){
 const response=await fetch(base+'/auth/v1/'+path,{method,headers:{apikey:anon??key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 const data=await response.json().catch(()=>null);
 if(!response.ok) throw new Error(`Auth ${path.split('/')[0]} returned ${response.status}`);
 return data;
}
async function api(token,method,path,body,expected=200){
 const response=await fetch(base+'/functions/v1/api'+path,{method,headers:{apikey:anon,...(token?{Authorization:`Bearer ${token}`} : {}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
 const data=await response.json().catch(()=>null);
 if(response.status!==expected) throw new Error(`${method} ${path.replace(tripID,'[smoke-trip]')} returned ${response.status}; expected ${expected}`);
 return data;
}
function check(label,condition){if(!condition)throw new Error(label);report.checks.push(label);console.log(label);}
try {
 const keys=JSON.parse(await command(['projects','api-keys','--project-ref',project,'--reveal','--output','json']));
 service=keys.find(k=>k.name==='service_role')?.api_key;anon=keys.find(k=>k.name==='anon')?.api_key;
 if(!service||!anon)throw new Error('Required project credentials unavailable');
 await api(null,'GET','/v1/trips',undefined,401);check('Anonymous request denied',true);
 for(const suffix of ['a','b']){
  const email=`trips-deployment-${tag}-${suffix}@example.invalid`,password=randomUUID()+randomUUID();
  const user=await auth('admin/users','POST',{email,password,email_confirm:true,user_metadata:{display_name:'Trips deployment smoke test'}},service);
  if(!user?.id)throw new Error('Test account ID missing');accounts.push({id:user.id,email});
  const session=await auth('token?grant_type=password','POST',{email,password},anon);
  accounts.at(-1).token=session.access_token;
  const profile=await api(session.access_token,'POST','/v1/auth/bootstrap',{displayName:'Trips deployment smoke test'});
  accounts.at(-1).appID=profile.currentUser.id;accounts.at(-1).username=profile.currentUser.username;
 }
 const [a,b]=accounts;actorID=a.appID;
 check('Existing Auth/bootstrap contract works',!!a.appID&&!!b.appID);
 const day=new Date().toISOString().slice(0,10);
 const trip=await api(a.token,'POST','/v1/trips',{id:tripID,name:'Deployment smoke test',destinationAirport:'LAX',startDate:day,endDate:day});
 check('Trip created with signed-in owner',trip.my_role==='owner'&&trip.participants[0].user_id===a.appID);
 await api(b.token,'GET',`/v1/trips/${tripID}`,undefined,403);
 const invite=await api(a.token,'POST',`/v1/trips/${tripID}/invitations`,{username:b.username});
 await api(b.token,'GET',`/v1/trips/${tripID}`,undefined,403);
 await api(a.token,'POST',`/v1/trip-invitations/${invite.id}/accept`,{},403);
 const joined=await api(b.token,'POST',`/v1/trip-invitations/${invite.id}/accept`,{});
 check('Only intended recipient can accept; pending invite grants no trip access',joined.my_role==='member');
 const flight={id:`smoke-flight-${tag}`,flightNumber:'UA353',date:day,direction:'outbound'};
 const added=await api(b.token,'POST',`/v1/trips/${tripID}/flights`,flight);
 check('Flight binds to submitting member',added.flights[0].participant_id===joined.participants.find(p=>p.user_id===b.appID).id);
 await api(a.token,'DELETE',`/v1/trips/${tripID}/flights/${flight.id}`,undefined,403);
 await api(a.token,'PATCH',`/v1/trips/${tripID}/flights/${flight.id}`,{flightNumber:'DL12',date:day,direction:'outbound'},403);
 await api(b.token,'POST',`/v1/trips/${tripID}/flights`,{...flight,id:flight.id+'x',participantID:trip.participants[0].id},400);
 check('Owner cannot edit/delete another member; traveler spoofing denied',true);
 const lookup=await api(a.token,'POST',`/v1/trips/${tripID}/flight-lookup`,{flightNumber:'UA353',date:day});
 check('Hosted AeroDataBox lookup returns real routes and scheduled times',lookup.source==='aerodatabox'&&lookup.flights.length>0&&!!lookup.flights[0].departure.scheduledTime.local);
 const cached=await api(b.token,'POST',`/v1/trips/${tripID}/flight-lookup`,{flightNumber:'UA353',date:day});
 check('Second member reuses cached provider result',cached.fetchedAt===lookup.fetchedAt);
 report.lookup={source:lookup.source,routeCount:lookup.flights.length,fetchedAt:lookup.fetchedAt};
 await api(b.token,'DELETE',`/v1/trips/${tripID}/flights/${flight.id}`);
 const done=await api(a.token,'PUT',`/v1/trips/${tripID}/completion`,{completed:true});
 check('Self delete and owner completion work',!!done.completed_at);
 report.passed=true;
} catch(error){report.passed=false;report.error=error.message;console.error(report.error);process.exitCode=1;}
finally {
 if(service){
  // UUID-derived exact targets only. Never delete an existing user's trip or account.
  try {
   const ids=accounts.map(a=>a.appID).filter(id=>/^[0-9a-f-]{36}$/i.test(id));
   const sql=`delete from public.trips where id='${tripID}' and name='Deployment smoke test';`+
    (ids.length?` delete from public.trip_flight_lookup_limits where bucket in (${ids.map(id=>`'${id}'`).join(',')});`:'');
   await command(['db','query','--linked','--project-ref',project,'--output','json',sql]);report.cleanup.push('Exact smoke trip removed');
  }catch{report.cleanup.push('Smoke trip cleanup needs attention');process.exitCode=1;}
  for(const account of accounts){try{await auth('admin/users/'+account.id,'DELETE',undefined,service);report.cleanup.push('Temporary Auth account removed');}
   catch{report.cleanup.push('Temporary Auth account cleanup needs attention');process.exitCode=1;}}
 }
 report.finishedAt=new Date().toISOString();
 await writeFile(resolve('.migration-backups/app-predeploy-FMkxfv/hosted-smoke-'+tag+'.json'),JSON.stringify(report,null,2),{flag:'wx',mode:0o600});
 console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,cleanup:report.cleanup},null,2));
}

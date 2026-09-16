// Live API validation with two temporary accounts. Fake-device queue checks are
// entirely rolled back: the scheduled worker cannot see them or send test pushes.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
import {writeFile,mkdtemp} from 'node:fs/promises';
const project='cdhpaujazbuppbxyhjxq',base=`https://${project}.supabase.co`,tag=randomUUID(),tripID='invite-smoke-'+tag;
const accounts=[],report={checks:[],cleanup:[]};let service,anon;
const command=async args=>(await promisify(execFile)(resolve('node_modules/.bin/supabase'),args,{timeout:60000,maxBuffer:1024*1024})).stdout;
const query=sql=>command(['db','query','--linked','--project-ref',project,'--output','json',sql]);
async function request(path,method,body,key,expected=200){
 const response=await fetch(base+path,{method,headers:{apikey:anon??key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
 const data=await response.json();
 if(response.status!==expected)throw new Error(`HTTP ${response.status} on ${method} ${path.split('?')[0]}: ${String(data.message??'Unexpected status').slice(0,250)}`);
 return data;
}
const api=(account,method,path,body,expected)=>request('/functions/v1/api'+path,method,body,account.token,expected);
function check(label,ok=true){if(!ok)throw new Error(label);report.checks.push(label);}
try{
 const keys=JSON.parse(await command(['projects','api-keys','--project-ref',project,'--reveal','--output','json']));
 service=keys.find(k=>k.name==='service_role')?.api_key;anon=keys.find(k=>k.name==='anon')?.api_key;
 if(!service||!anon)throw new Error('Missing credentials');
 for(const suffix of ['a','b']){
  const email=`invite-smoke-${tag}-${suffix}@example.invalid`,password=randomUUID()+randomUUID();
  const user=await request('/auth/v1/admin/users','POST',{email,password,email_confirm:true},service);
  accounts.push({id:user.id});
  const session=await request('/auth/v1/token?grant_type=password','POST',{email,password},anon);
  Object.assign(accounts.at(-1),{token:session.access_token});
  const profile=await api(accounts.at(-1),'POST','/v1/auth/bootstrap',{displayName:'Invitation smoke test'});
  Object.assign(accounts.at(-1),{appID:profile.currentUser.id,username:profile.currentUser.username});
 }
 const [a,b]=accounts,day=n=>new Date(Date.now()+n*86400000).toISOString().slice(0,10);
 await api(a,'POST','/v1/trips',{id:tripID,name:'Invitation smoke test',destinationAirport:'LAX',startDate:day(2),endDate:day(5)});
 const invite=await api(a,'POST',`/v1/trips/${tripID}/invitations`,{username:b.username});
 const duplicate=await api(a,'POST',`/v1/trips/${tripID}/invitations`,{username:b.username});
 check('Repeated invitations return the same ID',invite.id===duplicate.id);
 const inbox=await api(b,'GET','/v1/trip-invitations');
 check('Recipient sees invitation without notification permission',inbox.invitations.some(i=>i.id===invite.id));
 for(const id of [a.appID,b.appID,invite.id])if(!/^[a-f0-9-]{36}$/i.test(id))throw new Error('Invalid probe ID');
 const token=randomUUID();
 await query(`begin; set local lock_timeout='3s'; set local statement_timeout='15s';
 do $$ declare d uuid; j uuid; p jsonb; begin
  if not exists(select 1 from trip_invitation_alerts where invitation_id='${invite.id}' and recipient_id='${b.appID}') then raise exception 'Alert missing'; end if;
  d:=wif_register_push_device('${b.appID}','${randomUUID()}','${randomUUID().replaceAll('-','').repeat(2)}','v1:abc:def','production','com.yangwy30.whereismyfriend','whereismyfriend');
  perform wif_trip_invitation_claim('${token}');
  select id into j from trip_invitation_deliveries where invitation_id='${invite.id}' and device_id=d;
  p:=wif_trip_invitation_prepare(j,'${token}');
  if p is null or p->>'deep_link'<>'whereismyfriend://trips/join/${invite.id}' then raise exception 'Prepare failed'; end if;
  perform wif_trip_dismiss_invitation('${a.appID}','${invite.id}',true);
  if wif_trip_invitation_prepare(j,'${token}') is not null then raise exception 'Revoked invitation still sendable'; end if;
 end $$; rollback; select true as rolled_back_probe_passed;`);
 check('Live outbox, per-device payload and revoke revalidation passed in rollback-only transaction');
 await api(a,'POST',`/v1/trip-invitations/${invite.id}/revoke`,{});
 check('Revocation removes recipient inbox entry',!(await api(b,'GET','/v1/trip-invitations')).invitations.some(i=>i.id===invite.id));
 const next=await api(a,'POST',`/v1/trips/${tripID}/invitations`,{username:b.username});
 check('Re-inviting rotates a revoked link',next.id!==invite.id);
 await api(a,'POST',`/v1/trip-invitations/${next.id}/accept`,{},403);
 await api(b,'POST',`/v1/trip-invitations/${next.id}/accept`,{});
 check('Only intended recipient can accept, and accepted invite leaves inbox',!(await api(b,'GET','/v1/trip-invitations')).invitations.some(i=>i.id===next.id));
 report.passed=true;
}catch(error){report.passed=false;report.error=error.message;process.exitCode=1;}
finally{
 if(service){
  try{await query(`delete from public.trips where id='${tripID}' and name='Invitation smoke test';`);report.cleanup.push('Exact temporary trip and invitation queue data removed');}catch{report.cleanup.push('Temporary trip cleanup required: '+tripID);process.exitCode=1;}
  for(const account of accounts)try{await request('/auth/v1/admin/users/'+account.id,'DELETE',undefined,service);report.cleanup.push('Temporary Auth account and cascading data removed');}catch{report.cleanup.push('Account cleanup required: '+account.id);process.exitCode=1;}
 }
 const directory=await mkdtemp(resolve('.migration-backups/invite-smoke-'));await writeFile(resolve(directory,'report.json'),JSON.stringify(report,null,2),{mode:0o600,flag:'wx'});
 console.log(JSON.stringify({directory,...report}));
}

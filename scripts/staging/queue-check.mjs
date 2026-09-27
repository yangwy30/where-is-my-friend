// Hosted queue correctness only: fake devices and simulated acknowledgements, no APNs.
import {readFile,writeFile,mkdir} from 'node:fs/promises';import {randomUUID} from 'node:crypto';
import {loadTarget,validatePrivateSession,requestJSON} from './target.mjs';import {assertIsolation,keys,query} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');await assertIsolation(target);
const session=validatePrivateSession(JSON.parse(await readFile('.staging-private/sessions.json','utf8')),target);
if(session.accounts.length!==20||!/^[a-f0-9-]{36}$/.test(session.runID??''))throw Error('Queue calibration expects the 20-user synthetic fixture');
const {anon,service}=await keys(target),tag=randomUUID(),tripPrefix='staging-'+session.runID+'-',fakeToken='v1:staging-queue:'+tag;
const values=session.accounts.map((a,n)=>`(${n+1},'${a.appID}'::uuid)`).join(',');
const ids=session.accounts.map(a=>`'${a.appID}'::uuid`).join(',');
async function rpc(name,body){const r=await requestJSON(target.origin+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:anon,Authorization:'Bearer '+service},body});if(r.status!==200)throw Error(`${name} returned ${r.status}`);return r.data;}
const report={projectRef:target.projectRef,startedAt:new Date().toISOString(),scope:'Real hosted SQL/PostgREST queue claim, consent recheck and acknowledgement; no worker/APNs transport',realAPNs:false};
try{
 await query(target,`begin;
 create temporary table actors(n integer,id uuid) on commit drop;insert into actors values ${values};
 insert into devices(user_id,apns_token_hash,encrypted_apns_token,environment,installation_id,platform,bundle_id,url_scheme)
 select a.id,md5(a.id::text||':'||d||':${tag}')||md5('${tag}'||a.id::text||':'||d),'${fakeToken}','sandbox',gen_random_uuid(),'ios','com.yangwy30.whereismyfriend.staging','whereismyfriend-staging' from actors a cross join generate_series(1,5)d;
 insert into trip_booking_reminders(trip_id,recipient_id,sender_id,kind,scheduled_day,expires_at)
 select '${tripPrefix}'||((a.n-1)/5),a.id,b.id,'manual',current_date,now()+interval '1 day' from actors a join actors b on b.n=((a.n-1)/5)*5+((a.n-1)%5+1)%5+1;
 commit;`);
 const batches=await Promise.all(Array.from({length:5},async()=>{const token=randomUUID();const rows=await rpc('wif_trip_booking_claim',{p_token:token});return rows.map(row=>({...row,token}));}));
 const claimed=batches.flat();report.initialConcurrentBatchSizes=batches.map(b=>b.length);report.followUpBatchSizes=[];
 // SKIP LOCKED can legitimately return an empty concurrent batch. Drain again
 // after those transactions finish before deciding that a row was lost.
 for(let round=0;round<10&&claimed.length<100;round++){
  const token=randomUUID(),rows=await rpc('wif_trip_booking_claim',{p_token:token});
  report.followUpBatchSizes.push(rows.length);claimed.push(...rows.map(row=>({...row,token})));
  if(!rows.length)await new Promise(resolve=>setTimeout(resolve,200));
 }
 const unique=new Set(claimed.map(x=>x.delivery_id));report.claimed=claimed.length;report.uniqueClaims=unique.size;
 if(claimed.length!==100||unique.size!==100)throw Error('Queue drain lost or duplicated rows');
 const first=session.accounts[0];await rpc('wif_trip_planning_preferences',{p_user_id:first.appID,p_trip_id:tripPrefix+'0',p_enabled:false});
 let acknowledged=0,cancelled=0;
 for(let offset=0;offset<claimed.length;offset+=5)await Promise.all(claimed.slice(offset,offset+5).map(async row=>{
  const prepared=await rpc('wif_trip_booking_prepare',{p_id:row.delivery_id,p_token:row.token});
  if(prepared){if(prepared.encrypted_apns_token!==fakeToken||prepared.bundle_id!=='com.yangwy30.whereismyfriend.staging')throw Error('Unexpected device in isolated queue');acknowledged++;}else cancelled++;
  const ok=await rpc('wif_trip_booking_complete',{p_id:row.delivery_id,p_token:row.token,p_outcome:prepared?'delivered':'failed'});if(prepared&&!ok)throw Error('Claim acknowledgement rejected');
 }));
 report.simulatedAcknowledgements=acknowledged;report.cancelledAfterOptOut=cancelled;
 if(acknowledged!==95||cancelled!==5)throw Error('Recipient opt-out was not rechecked for all fake devices');
 report.passed=true;
}catch(error){report.passed=false;report.error=error.message;process.exitCode=1;}
finally{
 try{
  await query(target,`begin;delete from trip_booking_reminders where trip_id like '${tripPrefix}%' and recipient_id in (${ids});delete from devices where encrypted_apns_token='${fakeToken}' and user_id in (${ids});update trip_members set planning_reminders_enabled=true where trip_id='${tripPrefix}0' and user_id='${session.accounts[0].appID}';commit;`);
  report.cleaned=true;
 }catch{report.cleaned=false;report.passed=false;process.exitCode=1;}
 report.finishedAt=new Date().toISOString();await mkdir('.staging-private/results',{recursive:true,mode:0o700});await writeFile('.staging-private/results/queue.json',JSON.stringify(report,null,2),{mode:0o600});console.log(JSON.stringify(report));
}

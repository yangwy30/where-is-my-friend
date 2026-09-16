// Approved, bounded A/B/A experiment. Only active flags on two exact cron jobs
// change. A DB-side self-removing watchdog and finally block both restore them.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {randomUUID} from 'node:crypto';
import {mkdtemp,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
const project='cdhpaujazbuppbxyhjxq',cli=resolve('node_modules/.bin/supabase');
const directory=await mkdtemp(resolve('.migration-backups/worker-comparison-'));
const guard='wif-diagnostic-restore-'+randomUUID().slice(0,8);
const names=['wif-push-worker-every-minute','wif-trip-worker-every-five-minutes'];
const report={directory,guard,started:new Date().toISOString(),phases:[],events:[]};
let jobs,anon,restoreSQL,pauseAttempted=false,pauseDeadline=Infinity;
async function command(args){return (await promisify(execFile)(cli,args,{timeout:45000,maxBuffer:1024*1024})).stdout;}
async function query(sql){return JSON.parse(await command(['db','query','--linked','--project-ref',project,'--output','json',sql])).rows;}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function save(){await writeFile(join(directory,'report.json'),JSON.stringify(report,null,2),{mode:0o600});}
async function event(type,extra={}){const item={type,at:new Date().toISOString(),...extra};report.events.push(item);console.log(JSON.stringify(item));await save();}
const stateSQL="select jobid,jobname,schedule,active,md5(command) command_hash from cron.job where jobname in ('wif-push-worker-every-minute','wif-trip-worker-every-five-minutes') order by jobid";
async function phase(name){
 const rows=await query(stateSQL),expected=name!=='B_paused';
 if(rows.length!==2||rows.some(j=>j.active!==expected))throw new Error('Unexpected job state before '+name);
 const phase={name,start:new Date().toISOString(),jobState:rows,windows:[],samples:[]};report.phases.push(phase);
 await event('phase_start',{name});
 for(let window=0;window<2;window++){
  const nextBoundary=Date.now()+60000-Date.now()%60000;
  const begin=Math.max(Date.now(),nextBoundary-2000);
  await event('window_wait',{name,window,begins:new Date(begin).toISOString()});
  await wait(Math.max(0,begin-Date.now()));
  phase.windows.push({window,start:new Date().toISOString()});
  for(let round=0;round<12;round++){
   if(name==='B_paused'&&Date.now()>pauseDeadline)throw new Error('Paused test exceeded its safety deadline');
   await Promise.all(['us-east-1','us-east-2'].map(async region=>{
    const at=new Date().toISOString(),began=performance.now();
    try{
     const response=await fetch(`https://${project}.supabase.co/functions/v1/api/v1/bootstrap`,{
      headers:{apikey:anon,Authorization:'Bearer '+anon,'x-region':region,'x-client-info':'wif-worker-aba-diagnostic'},
      signal:AbortSignal.timeout(20000)});
     await response.arrayBuffer();
     phase.samples.push({at,window,round,region,actualRegion:response.headers.get('x-sb-edge-region'),
      status:response.status,ms:Math.round(performance.now()-began),requestID:response.headers.get('sb-request-id')});
    }catch{phase.samples.push({at,window,round,region,status:'transport_error',ms:Math.round(performance.now()-began)});}
   }));
   await save();await wait(1000);
  }
  phase.windows.at(-1).end=new Date().toISOString();
  await event('window_done',{name,window,samples:phase.samples.length});
 }
 phase.end=new Date().toISOString();
 phase.endJobState=await query(stateSQL);
 if(phase.endJobState.length!==2||phase.endJobState.some(j=>j.active!==expected))throw new Error('Job state changed during '+name);
 phase.summary=['us-east-1','us-east-2'].map(region=>{
  const samples=phase.samples.filter(r=>r.region===region),times=samples.map(r=>r.ms).sort((a,b)=>a-b);
  return {region,n:samples.length,expected401:samples.filter(r=>r.status===401).length,over2s:samples.filter(r=>r.ms>2000).length,
   medianMs:times[Math.floor(times.length/2)],p95Ms:times[Math.ceil(times.length*.95)-1],maxMs:times.at(-1)};
 });
 await event('phase_done',{name,summary:phase.summary});
}
async function restore(){
 if(!restoreSQL)return;
 let failure;
 for(let attempt=0;attempt<3;attempt++){
  try{report.restored=await query(restoreSQL);await event('restored',{jobs:report.restored});pauseAttempted=false;return;}
  catch(error){failure=error;await wait(1000);}
 }
 throw failure;
}
try{
 jobs=await query(stateSQL);report.originalJobs=jobs;
 if(jobs.length!==2||jobs.some(j=>!names.includes(j.jobname)||!j.active||!Number.isInteger(j.jobid)))throw new Error('Unexpected original schedules');
 const keys=JSON.parse(await command(['projects','api-keys','--project-ref',project,'--reveal','--output','json']));
 anon=keys.find(k=>k.name==='anon')?.api_key;if(!anon)throw new Error('Anonymous key unavailable');
 const fn=JSON.parse(await command(['functions','list','--project-ref',project,'--output','json'])).find(f=>f.slug==='api');
 report.apiBefore={version:fn.version,verifyJWT:fn.verify_jwt};
 const verify=jobs.map(j=>`if not exists(select 1 from cron.job where jobid=${j.jobid} and jobname='${j.jobname}' and md5(command)='${j.command_hash}' and schedule='${j.schedule}') then raise exception 'Target job changed'; end if;`).join('\n');
 const enable=jobs.map(j=>`perform cron.alter_job(${j.jobid},active:=true);`).join('\n');
 restoreSQL=`begin; do $do$ begin ${verify} ${enable}
 if exists(select 1 from cron.job where jobname='${guard}') then perform cron.unschedule('${guard}'); end if;
 end $do$; commit; ${stateSQL};`;
 await writeFile(join(directory,'restore.sql'),restoreSQL,{mode:0o600,flag:'wx'});
 await event('prepared',{directory});
 await phase('A1_running');
 // The server computes the deadline; local clock skew cannot extend the pause.
 const pauseSQL=`begin; set local lock_timeout='5s'; do $do$ declare deadline timestamptz:=now()+interval '6 minutes'; recovery text; begin
 ${verify}
 if exists(select 1 from cron.job where jobname in ('${names.join("','")}') and not active) then raise exception 'Job was paused concurrently'; end if;
 recovery:=format($body$do $restore$ begin if now()>=%L::timestamptz then ${verify} ${enable} perform cron.unschedule('${guard}'); end if; end $restore$;$body$,deadline);
 perform cron.schedule('${guard}','* * * * *',recovery);
 ${jobs.map(j=>`perform cron.alter_job(${j.jobid},active:=false);`).join('\n')}
 end $do$; commit; ${stateSQL};`;
 pauseAttempted=true;
 report.paused=await query(pauseSQL);pauseDeadline=Date.now()+5*60000;
 await event('paused',{jobs:report.paused,watchdogAfterMinutes:6});
 await event('draining',{seconds:90});await wait(90000);
 await phase('B_paused');
 await restore();
 await phase('A2_restored');
 const after=JSON.parse(await command(['functions','list','--project-ref',project,'--output','json'])).find(f=>f.slug==='api');
 report.apiAfter={version:after.version,verifyJWT:after.verify_jwt};
 report.sameAPIVersion=after.version===report.apiBefore.version;
 report.completed=true;
}catch(error){report.error=String(error.message).slice(0,250);process.exitCode=1;}
finally{
 if(pauseAttempted)try{await restore();}catch{report.restoreRequiresAttention=true;process.exitCode=1;}
 report.finished=new Date().toISOString();await save();
 console.log(JSON.stringify({directory,completed:report.completed??false,error:report.error,restoreRequiresAttention:report.restoreRequiresAttention??false}));
}

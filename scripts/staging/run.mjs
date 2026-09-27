import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {loadTarget,validatePrivateSession,validateLoadStages,requestJSON,shouldStop} from './target.mjs';
import {assertIsolation} from './management.mjs';
export async function runStages(target,session,{levels=[1,5,10,20],lanes=1,edgeRegion=null,pauseMs=1000,fetcher=fetch,onStage=()=>{}}={}){
 validateLoadStages(levels);validatePrivateSession(session,target);
 if(edgeRegion!==null&&!['us-east-1','us-west-1'].includes(edgeRegion))throw Error('Unsupported comparison region');
 if(!Number.isInteger(lanes)||lanes<1||lanes>5)throw Error('Use 1–5 parallel journeys per test account, at most 100 requests in flight');
 if(!session.expected||session.expected.friends!==session.accounts.length-1||session.expected.friendPlans!==3*(session.accounts.length-1)||session.expected.overlaps!==3*(session.accounts.length-1)||session.expected.trips!==1)throw Error('Seeded fixture expectations required');
 if(levels.at(-1)>session.accounts.length)throw Error('Each virtual user requires a distinct authenticated test account');
 const stages=[];let active=0,peak=0;
 const routes=['/v2/travel-plans','/v2/friend-plans','/v1/trips'];
 const percentile=(items,p)=>[...items].sort((a,b)=>a-b)[Math.min(items.length-1,Math.floor(items.length*p))]??0;
 async function request(actor,path,method='GET',body){
  const start=performance.now();let status=0,bytes=0,valid=false,responseRegion=null;active++;peak=Math.max(peak,active);
  try{
   const result=await requestJSON(target.origin+'/functions/v1/api'+path,{method,headers:{apikey:session.anon,Authorization:'Bearer '+actor.token,...(edgeRegion?{'x-region':edgeRegion}:{})},body,fetcher});
   status=result.status;bytes=result.bytes;responseRegion=result.edgeRegion;const j=result.data;
   valid=path==='/v1/auth/bootstrap'?j?.currentUser?.id===actor.appID&&j.friends?.length===session.expected.friends:
    path==='/v2/travel-plans'?Array.isArray(j?.overlaps)&&Number.isInteger(j?.overlapCount)&&j.overlaps.length===Math.min(3,j.overlapCount)&&j.overlapCount===session.expected.overlaps&&j.friendPlanSummaries?.reduce((n,x)=>n+x.count,0)===session.expected.friendPlans:
    path==='/v2/friend-plans'?Array.isArray(j?.items)&&j.items.length===Math.min(50,session.expected.friendPlans):Array.isArray(j?.trips)&&j.trips.length===session.expected.trips;
  }catch{}finally{active--;}
  return {path,status,bytes,edgeRegion:responseRegion,ok:status===200&&valid,ms:performance.now()-start};
 }
 for(const users of levels){
  const start=performance.now(),rows=[];let stop=false;peak=0;
  await Promise.all(session.accounts.slice(0,users).flatMap(actor=>Array.from({length:lanes},async()=>{
   // Each lane runs one request at a time; account count and concurrency are reported separately.
   for(let round=0;round<3&&!stop;round++){
    for(const [path,method,body] of [['/v1/auth/bootstrap','POST',{}],...routes.map(p=>[p,'GET',undefined])]){
     if(stop)break;const row=await request(actor,path,method,body);rows.push(row);
     if(!row.ok){stop=true;break;}
    }
   }
  })));
  const summary={users,requestedEdgeRegion:edgeRegion,parallelJourneysPerAccount:lanes,peakInFlight:peak,edgeRegions:[...new Set(rows.map(x=>x.edgeRegion).filter(Boolean))],requests:rows.length,failures:rows.filter(r=>!r.ok).length,elapsedMs:performance.now()-start,
   latencyMs:{p50:percentile(rows.map(x=>x.ms),.5),p95:percentile(rows.map(x=>x.ms),.95),max:Math.max(0,...rows.map(x=>x.ms))},
   statuses:rows.reduce((a,r)=>(a[r.status]=(a[r.status]??0)+1,a),{}),
   endpoints:Object.fromEntries([...new Set(rows.map(x=>x.path))].map(path=>{const r=rows.filter(x=>x.path===path);return [path,{requests:r.length,p95Ms:percentile(r.map(x=>x.ms),.95),p95Bytes:percentile(r.map(x=>x.bytes),.95)}];}))};
  stages.push(summary);await onStage(summary);
  if(stop||shouldStop(rows))return {stages,stoppedEarly:true};
  if(pauseMs)await new Promise(resolve=>setTimeout(resolve,pauseMs));
 }
 return {stages,stoppedEarly:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const target=await loadTarget(process.argv[2]??'.staging-private/target.json');await assertIsolation(target);
 const sessions=validatePrivateSession(JSON.parse(await readFile('.staging-private/sessions.json','utf8')),target);
 const directory='.staging-private/results';await mkdir(directory,{recursive:true,mode:0o700});
 const report={projectRef:target.projectRef,region:target.region,startedAt:new Date().toISOString(),sourceAPIHash:createHash('sha256').update(await readFile('supabase/functions/api/index.ts')).digest('hex'),
  scope:'Dedicated hosted Supabase Auth + gateway + Edge + PostgREST + SQL, synthetic accounts; password sign-in, no Apple sign-in or APNs delivery; initial calibration, not certified production capacity',stages:[]};
 const lanes=Number(process.argv[3]??1),edgeRegion=process.argv[4]??null;
 const result=await runStages(target,sessions,{lanes,edgeRegion,onStage:async stage=>{report.stages.push(stage);await writeFile(directory+'/latest.json',JSON.stringify(report,null,2));console.log(JSON.stringify(stage));}});
 report.stoppedEarly=result.stoppedEarly;report.finishedAt=new Date().toISOString();await writeFile(directory+'/latest.json',JSON.stringify(report,null,2));
 if(result.stoppedEarly)process.exitCode=1;
}

// Read-only post-change probes at both the original minute boundary and the
// shifted flight start. No user account, write, push or paid lookup is invoked.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {mkdtemp,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
const directory=await mkdtemp(resolve('.migration-backups/worker-load-verification-'));
const cli=resolve('node_modules/.bin/supabase'),project='cdhpaujazbuppbxyhjxq';
const command=async args=>(await promisify(execFile)(cli,args,{timeout:45000})).stdout;
const keys=JSON.parse(await command(['projects','api-keys','--project-ref',project,'--reveal','--output','json']));
const anon=keys.find(k=>k.name==='anon')?.api_key;if(!anon)throw new Error('Anonymous key unavailable');
const minute=Math.ceil((Date.now()+2000)/60000)*60000,flight=Math.ceil(minute/300000)*300000;
const report={started:new Date().toISOString(),directory,windows:[{label:'minute_a',target:minute-2000},
 {label:'minute_b',target:minute+60000-2000},...(process.argv.includes('--baseline-only')?[]:[{label:'flight_offset',target:flight+18000}])].sort((a,b)=>a.target-b.target),samples:[]};
const save=()=>writeFile(join(directory,'report.json'),JSON.stringify(report,null,2),{mode:0o600});
const wait=ms=>new Promise(r=>setTimeout(r,ms));
console.log(JSON.stringify({directory,windows:report.windows.map(w=>({...w,at:new Date(w.target).toISOString()}))}));
for(const window of report.windows){
 console.log(JSON.stringify({waitingFor:window.label,at:new Date(window.target).toISOString()}));
 await wait(Math.max(0,window.target-Date.now()));window.start=new Date().toISOString();
 for(let round=0;round<12;round++){
  await Promise.all(['us-east-1','us-east-2'].map(async region=>{
   const start=performance.now(),at=new Date().toISOString();
   try{
    const response=await fetch(`https://${project}.supabase.co/functions/v1/api/v1/bootstrap`,{
     headers:{apikey:anon,Authorization:'Bearer '+anon,'x-region':region,'x-client-info':'wif-worker-load-verification'},signal:AbortSignal.timeout(20000)});
    await response.arrayBuffer();report.samples.push({window:window.label,round,at,region,actualRegion:response.headers.get('x-sb-edge-region'),
     status:response.status,ms:Math.round(performance.now()-start),requestID:response.headers.get('sb-request-id')});
   }catch{report.samples.push({window:window.label,round,at,region,status:'transport_error',ms:Math.round(performance.now()-start)});}
  }));await save();await wait(1000);
 }
 window.end=new Date().toISOString();const rows=report.samples.filter(s=>s.window===window.label);
 console.log(JSON.stringify({window:window.label,n:rows.length,over2s:rows.filter(r=>r.ms>2000).length,unexpected:rows.filter(r=>r.status!==401).length,maxMs:Math.max(...rows.map(r=>r.ms))}));
}
report.finished=new Date().toISOString();await save();
console.log(JSON.stringify({directory,completed:true,total:report.samples.length}));

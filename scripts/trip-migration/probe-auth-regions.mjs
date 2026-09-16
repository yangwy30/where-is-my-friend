// Read-only, bounded A/B probe. Uses the anonymous project JWT, not a user's
// session. getUser must reject it; GET cannot initialize or modify any account.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve} from 'node:path';
const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),['projects','api-keys','--project-ref','cdhpaujazbuppbxyhjxq','--reveal','--output','json'],{timeout:60000});
const anon=JSON.parse(stdout).find(k=>k.name==='anon')?.api_key;
if(!anon)throw new Error('Existing anonymous key unavailable');
if(process.argv.includes('--boundary')){
 const waitMs=Math.max(0,60000-Date.now()%60000-2000);
 console.log(JSON.stringify({waitingForMinuteBoundaryMs:waitMs}));
 await new Promise(r=>setTimeout(r,waitMs));
}
const start=new Date().toISOString(),results=[];
for(let round=0;round<12;round++){
 await Promise.all(['us-east-1','us-east-2'].map(async region=>{
  const began=performance.now();
  try{
   const r=await fetch('https://cdhpaujazbuppbxyhjxq.supabase.co/functions/v1/api/v1/bootstrap',{
    headers:{apikey:anon,Authorization:'Bearer '+anon,'x-region':region,'x-client-info':'wif-readonly-region-diagnostic'},signal:AbortSignal.timeout(20000)});
   await r.arrayBuffer();
   const row={round,region,actualRegion:r.headers.get('x-sb-edge-region'),status:r.status,ms:Math.round(performance.now()-began),requestID:r.headers.get('sb-request-id')};
   results.push(row);console.log(JSON.stringify(row));
  }catch{results.push({round,region,status:'transport_error',ms:Math.round(performance.now()-began)});}
 }));
 await new Promise(r=>setTimeout(r,1000));
}
console.log(JSON.stringify({start,end:new Date().toISOString(),summary:['us-east-1','us-east-2'].map(region=>{
 const rows=results.filter(r=>r.region===region),times=rows.map(r=>r.ms).sort((a,b)=>a-b);
 return {region,total:rows.length,rejectedAsExpected:rows.filter(r=>r.status===401).length,over2seconds:rows.filter(r=>r.ms>2000).length,medianMs:times[Math.floor(times.length/2)],maxMs:times.at(-1)};
})}));

import {readFile,writeFile} from 'node:fs/promises';import {execFile} from 'node:child_process';import {promisify} from 'node:util';import {resolve} from 'node:path';
const project='cdhpaujazbuppbxyhjxq',cli=resolve('node_modules/.bin/supabase'),monitor=JSON.parse(await readFile('.ops-private/production-monitor.json','utf8'));
if(monitor.projectRef!==project||new URL(monitor.url).origin!==`https://${project}.supabase.co`)throw Error('Unexpected monitor target');
async function run(args){try{return (await promisify(execFile)(cli,args,{timeout:60000,maxBuffer:4*1024*1024})).stdout;}catch{throw Error('Readiness check failed; private output withheld');}}
const probe=await fetch(monitor.url,{redirect:'error',signal:AbortSignal.timeout(20000)});const page=await probe.text();
const wrong=await fetch(`https://${project}.supabase.co/functions/v1/ops-monitor/status/invalid`,{redirect:'error'});
const unauth=await fetch(`https://${project}.supabase.co/functions/v1/ops-monitor/client-events`,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',redirect:'error'});
const health=JSON.parse(await run(['db','query','--linked','--project-ref',project,'--output','json','select wif_ops_health() as health;'])).rows[0].health;
const functions=JSON.parse(await run(['functions','list','--project-ref',project,'--output','json'])).map(({name,version,status,verify_jwt})=>({name,version,status,verify_jwt}));
const report={at:new Date().toISOString(),project,probeStatus:probe.status,expectedStatusPage:page.includes('Across Us'),invalidProbeStatus:wrong.status,unauthenticatedCollectorStatus:unauth.status,health,functions};
await writeFile('.ops-private/production-verification.json',JSON.stringify(report,null,2),{mode:0o600});
console.log(JSON.stringify(report));if(probe.status!==200||wrong.status!==404||unauth.status!==401)process.exitCode=1;

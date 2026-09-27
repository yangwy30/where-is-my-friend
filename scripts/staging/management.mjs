// Uses the existing CLI login. Secrets stay in process memory.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve} from 'node:path';
import {verifyProject,assertMarker} from './target.mjs';
const exec=promisify(execFile),cli=resolve('node_modules/.bin/supabase');
export async function command(args){
 try{return (await exec(cli,args,{timeout:90000,maxBuffer:16*1024*1024})).stdout;}
 catch{throw Error(`Supabase command failed: ${args.slice(0,2).join(' ')}; sensitive output withheld`);}
}
export async function verifyCloud(target){
 const projects=JSON.parse(await command(['projects','list','--output','json']));
 return verifyProject(target,projects);
}
export async function query(target,sql){
 return JSON.parse(await command(['db','query','--linked','--project-ref',target.projectRef,'--output','json',sql])).rows;
}
export async function assertIsolation(target,{markerRequired=true}={}){
 await verifyCloud(target);
 const secretNames=JSON.parse(await command(['secrets','list','--project-ref',target.projectRef,'--output','json'])).map(x=>x.name);
 if(secretNames.some(n=>/^(APNS_|AERODATABOX_|FLIGHT_PROVIDER_|RAPIDAPI_)/.test(n)))throw Error('Provider secrets found in test project; refusing test writes');
 const cron=await query(target,"select to_regclass('cron.job') is not null as exists");
 if(cron[0]?.exists){const jobs=await query(target,'select count(*)::integer as active from cron.job where active');if(jobs[0].active!==0)throw Error('Active cron jobs found in staging');}
 if(markerRequired){const rows=await query(target,'select project_ref,environment,real_push_enabled,flight_provider_enabled from public.wif_test_environment');if(rows.length!==1)throw Error('Expected one environment marker');assertMarker(rows[0],target);}
}
export async function keys(target){
 const rows=JSON.parse(await command(['projects','api-keys','--project-ref',target.projectRef,'--reveal','--output','json']));
 const anon=rows.find(x=>x.name==='anon')?.api_key,service=rows.find(x=>x.name==='service_role')?.api_key;
 if(!anon||!service)throw Error('Required staging API keys unavailable');return {anon,service};
}

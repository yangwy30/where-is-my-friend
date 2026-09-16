import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {writeFile,mkdtemp} from 'node:fs/promises';
import {resolve} from 'node:path';
const cli=resolve('node_modules/.bin/supabase'),project='cdhpaujazbuppbxyhjxq';
async function query(sql){return JSON.parse((await promisify(execFile)(cli,['db','query','--linked','--project-ref',project,'--output','json',sql],{timeout:60000})).stdout).rows;}
const jobs=await query("select jobid,command,md5(command) as hash from cron.job where jobname='wif-push-worker-every-minute'");
if(jobs.length!==1)throw new Error('Expected exactly one existing push schedule');
const job=jobs[0];
if(!job.command.includes('vault.decrypted_secrets')||!job.command.includes('/functions/v1/push-worker')||job.command.includes('timeout_milliseconds'))throw new Error('Unexpected schedule; inspect manually');
const updated=job.command.replace(/body\s*:=\s*jsonb_build_object\('scheduledAt',\s*now\(\)\)/,"body := jsonb_build_object('scheduledAt', now()), timeout_milliseconds := 120000");
if(updated===job.command||updated.includes('$job$'))throw new Error('Unexpected schedule syntax');
const backup=await mkdtemp(resolve('.migration-backups/push-schedule-'));
await writeFile(resolve(backup,'previous-command.sql'),job.command,{mode:0o600,flag:'wx'});
await query(`do $$ begin
 if not exists(select 1 from cron.job where jobid=${job.jobid} and md5(command)='${job.hash}') then raise exception 'Schedule changed concurrently'; end if;
 perform cron.alter_job(${job.jobid},command:=$job$${updated}$job$);
end $$; select jobid,schedule,active,position('120000' in command)>0 as timeout_updated from cron.job where jobid=${job.jobid};`);
console.log(JSON.stringify({backup,jobID:job.jobid,timeoutMilliseconds:120000,scheduleUnchanged:true}));

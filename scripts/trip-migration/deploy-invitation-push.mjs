// Backs up deployed worker + invite RPC and applies only this reviewed migration.
import {readFile,writeFile,mkdtemp,mkdir} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join} from 'node:path';
const project='cdhpaujazbuppbxyhjxq',version='20260912010000',cli=resolve('node_modules/.bin/supabase');
const backup=await mkdtemp(resolve('.migration-backups/invite-push-'));
await mkdir(join(backup,'supabase'));
async function command(args){return (await promisify(execFile)(cli,args,{timeout:90000,maxBuffer:4*1024*1024})).stdout;}
const query=sql=>command(['db','query','--linked','--project-ref',project,'--output','json',sql]);
try {
 const state=JSON.parse(await query("select pg_get_functiondef('public.wif_trip_invite(uuid,text,text)'::regprocedure) as definition, md5(pg_get_functiondef('public.wif_trip_invite(uuid,text,text)'::regprocedure)) as hash;"));
 const previous=state.rows[0];await writeFile(join(backup,'previous-invite-rpc.sql'),previous.definition,{mode:0o600,flag:'wx'});
 await command(['functions','download','push-worker','--project-ref',project,'--use-api','--workdir',backup]);
 await writeFile(join(backup,'functions-before.json'),await command(['functions','list','--project-ref',project,'--output','json']),{mode:0o600,flag:'wx'});
 const source=await readFile(resolve(`supabase/migrations/${version}_trip_invitation_notifications.sql`),'utf8');
 const sql=`begin; set local lock_timeout='5s'; set local statement_timeout='45s';
select pg_advisory_xact_lock(9120100);
do $$ begin
 if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Already applied; verify before retry.'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260911010000') then raise exception 'Unexpected migration baseline.'; end if;
 if md5(pg_get_functiondef('public.wif_trip_invite(uuid,text,text)'::regprocedure))<>'${previous.hash}' then raise exception 'Concurrent schema change; stop.'; end if;
end $$;
${source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'')}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','trip_invitation_notifications',ARRAY[$migration_source$${source}$migration_source$]);
commit; select version from supabase_migrations.schema_migrations where version='${version}';`;
 const file=join(backup,'apply.sql');await writeFile(file,sql,{mode:0o600,flag:'wx'});
 if(!process.argv.includes('--apply'))console.log(JSON.stringify({backup,prepared:true,applied:false}));
 else {
   console.log(await command(['db','query','--linked','--project-ref',project,'--output','json','--file',file]));
   console.log(await command(['functions','deploy','push-worker','--project-ref',project,'--use-api','--no-verify-jwt']));
   console.log(JSON.stringify({backup,applied:true,workerDeployed:true}));
 }
}catch(error){console.error(JSON.stringify({backup,error:'Deployment not fully confirmed; inspect ledger/function version before retry.'}));process.exitCode=1;}

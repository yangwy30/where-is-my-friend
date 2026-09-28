// Narrow observability rollout only. Does not apply the pending pagination migrations.
import {readFile,writeFile,mkdir} from 'node:fs/promises';import {execFile} from 'node:child_process';import {promisify} from 'node:util';import {resolve,join} from 'node:path';import {createHash,randomBytes} from 'node:crypto';
const project='cdhpaujazbuppbxyhjxq',version='20260927040000',name='operational_monitoring',root=resolve('.ops-private/production'),cli=resolve('node_modules/.bin/supabase');
const run=async args=>{try{return (await promisify(execFile)(cli,args,{timeout:90000,maxBuffer:16*1024*1024})).stdout;}catch{throw Error('Deployment step failed; inspect protected artifacts, not raw credential output.');}};
const query=async sql=>JSON.parse(await run(['db','query','--linked','--project-ref',project,'--output','json',sql])).rows;
const proof=JSON.parse(await readFile(join(root,'patch-proof.json'),'utf8'));if(proof.project!==project||proof.includesUnreleasedPlanPagination!==false)throw Error('Reviewed narrow patch required');
const smoke=JSON.parse(await readFile('.ops-private/staging-smoke-report.json','utf8'));if(smoke.passed!==true||smoke.projectRef!=='tyeeulfevixeuttmrzeq')throw Error('Passing isolated cloud verification required');
const current=JSON.parse(await run(['functions','list','--project-ref',project,'--output','json']));
for(const p of proof.proofs){
 if(current.find(f=>f.slug===p.name||f.name===p.name)?.version!==p.version)throw Error('Live function version changed; rebuild reviewed patch');
 const source=await readFile(join(root,'release',p.name,'supabase/functions',p.name,'index.ts'));
 if(createHash('sha256').update(source).digest('hex')!==p.afterHash)throw Error('Prepared function changed');
}
const source=await readFile(`supabase/migrations/${version}_${name}.sql`,'utf8');if(source.includes('$ops_migration$'))throw Error('Unexpected SQL delimiter');
const sql=`begin;set local lock_timeout='5s';set local statement_timeout='45s';select pg_advisory_xact_lock(9270400);
do $$ begin
 if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Already applied; verify instead of replaying';end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260927010000') then raise exception 'Required baseline missing';end if;
 if to_regclass('public.wif_ops_events') is not null then raise exception 'Unexpected existing monitor tables';end if;
end $$;
${source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'')}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','${name}',ARRAY[$ops_migration$${source}$ops_migration$]);
commit;notify pgrst,'reload schema';`;
const sqlFile=join(root,'apply.sql');await writeFile(sqlFile,sql,{mode:0o600});
console.log(JSON.stringify({prepared:true,project,migration:version,functions:['api','push-worker','trip-worker','ops-monitor'],businessCodePreserved:true}));
if(!process.argv.includes('--apply'))process.exit(0);
const token=randomBytes(32).toString('hex');await mkdir('.ops-private',{recursive:true,mode:0o700});
const {recipient}=JSON.parse(await readFile('.ops-private/operator.json','utf8'));
if(typeof recipient!=='string'||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient))throw Error('Valid operator email required');
const config={projectRef:project,probeToken:token,url:`https://${project}.supabase.co/functions/v1/ops-monitor/status/${token}`,recipient};
await writeFile('.ops-private/production-monitor.json',JSON.stringify(config,null,2),{mode:0o600});
await run(['db','query','--linked','--project-ref',project,'--file',sqlFile,'--output','json']);
// Enable only after the additive schema exists. Existing worker secrets are untouched.
const envFile=join(root,'monitor.env');await writeFile(envFile,'WIF_OBSERVABILITY_ENABLED=true\nOPS_PROBE_TOKEN='+token+'\n',{mode:0o600});
await run(['secrets','set','--project-ref',project,'--env-file',envFile]);
for(const fn of ['api','push-worker','trip-worker','ops-monitor']){
 await run(['functions','deploy',fn,'--project-ref',project,'--use-api','--workdir',join(root,'release',fn)]);
 console.log(JSON.stringify({deployed:fn,project}));
}
await query("update public.wif_ops_settings set expect_push=true,expect_trip=true,enabled_at=now() where id=true;");
const checks=await query("select exists(select 1 from supabase_migrations.schema_migrations where version='20260927040000') migrated,has_function_privilege('anon','public.wif_ops_health()','execute') anonymous_health,has_function_privilege('authenticated','public.wif_ops_record_event(text,uuid,text,text,integer,integer,text,uuid)','execute') client_direct_insert;");
if(!checks[0].migrated||checks[0].anonymous_health||checks[0].client_direct_insert)throw Error('Operational boundaries failed');
await writeFile(join(root,'deployed.json'),JSON.stringify({project,deployedAt:new Date().toISOString(),proofs:proof.proofs,checks},null,2),{mode:0o600});
console.log(JSON.stringify({deployed:true,project,monitorURLStoredPrivately:true,emailNotYetActivated:true}));

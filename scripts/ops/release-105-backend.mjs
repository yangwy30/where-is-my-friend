// One-time 1.0.5 rollout after the separately guarded pagination migration.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
const project='cdhpaujazbuppbxyhjxq',cli=resolve('node_modules/.bin/supabase'),dir='.ops-private/release-105';
async function run(args){try{return (await promisify(execFile)(cli,args,{timeout:120000,maxBuffer:8*1024*1024})).stdout;}catch{throw Error('Release operation failed; private command output withheld.');}}
const query=async sql=>JSON.parse(await run(['db','query','--linked','--project-ref',project,'--output','json',sql])).rows;
await mkdir(dir,{recursive:true,mode:0o700});
const ledger=await query('select version from supabase_migrations.schema_migrations order by version');
for(const v of ['20260927010000','20260927020000','20260927040000'])if(!ledger.some(r=>r.version===v))throw Error('Required migration missing: '+v);
if(ledger.some(r=>r.version==='20260927030000'))throw Error('Already applied; verify rather than replay');
const functions=JSON.parse(await run(['functions','list','--project-ref',project,'--output','json']));
if(functions.find(f=>f.name==='api'||f.slug==='api')?.version!==26)throw Error('Production API drift; review before deploying');
const rows=await query("select pg_get_functiondef(oid) definition,md5(prosrc) hash from pg_proc where oid='public.wif_travel_overview(uuid)'::regprocedure");
const earlier=await readFile('supabase/migrations/20260927020000_plan_pagination_and_bootstrap.sql','utf8');
const body=earlier.match(/create function public\.wif_travel_overview\(p_user_id uuid\)[\s\S]*?as \$\$([\s\S]*?)\$\$/)?.[1];
if(!body||createHash('md5').update(body).digest('hex')!==rows[0]?.hash)throw Error('Overview definition differs from tested pagination migration');
await writeFile(dir+'/overview-before.sql',rows[0].definition+';\n',{mode:0o600});
await writeFile(dir+'/baseline.json',JSON.stringify({ledger,functions,at:new Date().toISOString()},null,2),{mode:0o600});
await mkdir(dir+'/api-before/supabase',{recursive:true,mode:0o700});
await writeFile(dir+'/api-before/supabase/config.toml',await readFile('supabase/config.toml'));
await run(['functions','download','api','--project-ref',project,'--use-api','--workdir',resolve(dir+'/api-before')]);
const source=await readFile('supabase/migrations/20260927030000_home_overlap_summary.sql','utf8');
const sql=`begin;set local lock_timeout='5s';set local statement_timeout='45s';select pg_advisory_xact_lock(9270100);
do $$ begin
if exists(select 1 from supabase_migrations.schema_migrations where version='20260927030000') then raise exception 'Already applied';end if;
if (select md5(prosrc) from pg_proc where oid='public.wif_travel_overview(uuid)'::regprocedure) is distinct from '${rows[0].hash}' then raise exception 'Concurrent schema change';end if;
end $$;
${source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'')}
insert into supabase_migrations.schema_migrations(version,name,statements) values('20260927030000','home_overlap_summary',ARRAY[$release105$${source}$release105$]);
commit;notify pgrst,'reload schema';`;
await writeFile(dir+'/summary-apply.sql',sql,{mode:0o600});
console.log(JSON.stringify({prepared:true,project,migration:'20260927030000',apiBefore:26}));
if(!process.argv.includes('--apply'))process.exit(0);
await run(['db','query','--linked','--project-ref',project,'--file',resolve(dir+'/summary-apply.sql'),'--output','json']);
await run(['functions','deploy','api','--project-ref',project,'--use-api']);
const released=JSON.parse(await run(['functions','list','--project-ref',project,'--output','json'])).find(f=>f.name==='api'||f.slug==='api');
await writeFile(dir+'/deployed.json',JSON.stringify({at:new Date().toISOString(),project,apiVersion:released?.version,apiSHA256:createHash('sha256').update(await readFile('supabase/functions/api/index.ts')).digest('hex')},null,2),{mode:0o600});
console.log(JSON.stringify({deployed:true,apiVersion:released?.version,legacyV1Retained:true}));

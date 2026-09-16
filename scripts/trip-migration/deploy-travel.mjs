// Applies only the personal-plan migration, never unrelated pending migrations.
import {readFile,writeFile,mkdtemp} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
const project='cdhpaujazbuppbxyhjxq',version='20260911010000';
const source=await readFile(resolve(`supabase/migrations/${version}_personal_travel_plans.sql`),'utf8');
if(source.includes('$migration_source$')) throw new Error('Unexpected delimiter');
const sql=`begin;
set local lock_timeout='5s'; set local statement_timeout='45s';
select pg_advisory_xact_lock(9110100);
do $$ begin
 if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Already applied; inspect before retry.'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260909010000') then raise exception 'Expected live baseline missing.'; end if;
 if to_regclass('public.travel_plans') is not null then raise exception 'Unexpected schema drift.'; end if;
end $$;
${source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'')}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','personal_travel_plans',ARRAY[$migration_source$${source}$migration_source$]);
commit;
select version from supabase_migrations.schema_migrations where version='${version}';`;
const directory=await mkdtemp(join(tmpdir(),'wif-travel-deploy-'));
const file=join(directory,'migration.sql');
await writeFile(file,sql,{mode:0o600,flag:'wx'});
if(!process.argv.includes('--apply')) console.log(JSON.stringify({prepared:file,project,version,applied:false}));
else {
 try {
  const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),['db','query','--linked','--project-ref',project,'--output','json','--file',file],{timeout:90000,maxBuffer:1024*1024});
  console.log(stdout);
 } catch {console.error('Deployment not confirmed; inspect ledger before retry.');process.exitCode=1;}
}

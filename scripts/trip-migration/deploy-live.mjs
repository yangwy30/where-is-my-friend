// Add only the reviewed live-update migration; do not deploy unrelated pending migrations.
import {readFile,writeFile,mkdtemp} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
const project='cdhpaujazbuppbxyhjxq',version='20260909010000';
const source=await readFile(resolve(`supabase/migrations/${version}_trip_live_updates.sql`),'utf8');
if(source.includes('$migration_source$')) throw new Error('Unexpected SQL delimiter');
const sql=`begin;
set local lock_timeout='5s'; set local statement_timeout='45s';
select pg_advisory_xact_lock(9090901);
do $$ begin
 if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Migration already applied; inspect rather than replay.'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260907010000') then raise exception 'Cloud collaboration baseline missing.'; end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='flights' and column_name='tracking_state') then raise exception 'Unexpected schema drift.'; end if;
end $$;
${source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'')}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','trip_live_updates',ARRAY[$migration_source$${source}$migration_source$]);
commit;
select version from supabase_migrations.schema_migrations where version='${version}';`;
const directory=await mkdtemp(join(tmpdir(),'wif-trip-live-deploy-'));
const file=join(directory,'migration.sql');
await writeFile(file,sql,{mode:0o600,flag:'wx'});
if(!process.argv.includes('--apply')) console.log(JSON.stringify({prepared:file,project,version,applied:false}));
else {
 try {
  const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),
   ['db','query','--linked','--project-ref',project,'--output','json','--file',file],{timeout:90000,maxBuffer:1024*1024});
  console.log(stdout);
 } catch {console.error('Migration not confirmed. Inspect ledger before retrying; do not run db push.');process.exitCode=1;}
}

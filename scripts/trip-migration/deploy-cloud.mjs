// Deploy only the reviewed cloud-collaboration migration. Never run blanket db push.
import {readFile,writeFile,mkdtemp} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
const project='cdhpaujazbuppbxyhjxq',version='20260907010000';
const source=await readFile(resolve(`supabase/migrations/${version}_trip_cloud_collaboration.sql`),'utf8');
if(source.includes('$migration_source$')) throw new Error('Unexpected SQL delimiter');
const body=source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'');
const sql=`begin;
set local lock_timeout='5s'; set local statement_timeout='45s';
select pg_advisory_xact_lock(7090701);
do $$ begin
 if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Migration already applied; inspect rather than replay.'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260906030000') then raise exception 'Trips flight lookup baseline missing.'; end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='trips' and column_name='revision') then raise exception 'Unexpected schema drift.'; end if;
end $$;
${body}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','trip_cloud_collaboration',ARRAY[$migration_source$${source}$migration_source$]);
commit;
select version from supabase_migrations.schema_migrations where version='${version}';`;
const directory=await mkdtemp(join(tmpdir(),'wif-trip-cloud-deploy-'));
const file=join(directory,'migration.sql');
await writeFile(file,sql,{mode:0o600,flag:'wx'});
if(!process.argv.includes('--apply')) {
 console.log(JSON.stringify({prepared:file,project,version,applied:false}));
} else {
 try {
  const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),
   ['db','query','--linked','--project-ref',project,'--output','json','--file',file],{timeout:90000,maxBuffer:1024*1024});
  console.log(stdout);
 } catch { console.error('Migration was not confirmed. Inspect the ledger before retrying; do not run db push.'); process.exitCode=1; }
}

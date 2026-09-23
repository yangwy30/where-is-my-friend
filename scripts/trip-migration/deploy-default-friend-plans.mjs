// Apply only the reviewed friend-plan default migration. The earlier
// transition-based colocation migration is intentionally absent online.
import {readFile,writeFile,mkdtemp} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';

const project='cdhpaujazbuppbxyhjxq';
const version='20260923010000';
const name='default_friend_plan_browsing';
const source=await readFile(resolve(`supabase/migrations/${version}_${name}.sql`),'utf8');
if(source.includes('$migration_source$')) throw new Error('Unexpected SQL delimiter');
const body=source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'');
const sql=`begin;
set local lock_timeout='5s'; set local statement_timeout='45s';
select pg_advisory_xact_lock(9230100);
do $$ begin
 if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Migration already applied; inspect before retrying.'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260917010000') then raise exception 'Expected trip reminder baseline missing.'; end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='travel_plans' and column_name='allow_friend_browsing') then raise exception 'Friend-plan baseline missing.'; end if;
end $$;
${body}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','${name}',ARRAY[$migration_source$${source}$migration_source$]);
commit;
select version from supabase_migrations.schema_migrations where version='${version}';`;
const directory=await mkdtemp(join(tmpdir(),'wif-friend-plan-default-'));
const file=join(directory,'migration.sql');
await writeFile(file,sql,{flag:'wx',mode:0o600});
if(!process.argv.includes('--apply')) {
    console.log(JSON.stringify({prepared:file,project,version,applied:false}));
} else {
    try {
        const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),
            ['db','query','--linked','--project-ref',project,'--output','json','--file',file],
            {timeout:90000,maxBuffer:1024*1024});
        console.log(stdout);
    } catch {
        console.error('Migration was not confirmed. Inspect the ledger before retrying.');
        process.exitCode=1;
    }
}

// New isolated projects only. Existing live projects are rejected before any write.
import {readFile,readdir,mkdir,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {loadTarget,assertMarker,assertEmptyUnmarkedProject} from './target.mjs';
import {migrationSQL} from './fixtures.mjs';
import {assertIsolation,query,command} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');
await assertIsolation(target,{markerRequired:false});
const [state]=await query(target,"select to_regclass('public.wif_test_environment') is not null as marked,(select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')::integer as public_table_count,(select count(*) from auth.users)::integer as auth_count");
assertEmptyUnmarkedProject(state);
if(state.marked){const rows=await query(target,'select * from public.wif_test_environment');if(rows.length!==1)throw Error('Invalid marker');assertMarker(rows[0],target);}
else await query(target,`begin;
 create table public.wif_test_environment(project_ref text primary key,environment text not null,real_push_enabled boolean not null default false,flight_provider_enabled boolean not null default false);
 alter table public.wif_test_environment enable row level security;
 revoke all on public.wif_test_environment from public,anon,authenticated;
 grant select on public.wif_test_environment to service_role;
 insert into public.wif_test_environment values('${target.projectRef}','isolated-staging',false,false);
 commit;`);
await query(target,'create schema if not exists supabase_migrations;create table if not exists supabase_migrations.schema_migrations(version text primary key,statements text[],name text);');
const applied=new Set((await query(target,'select version from supabase_migrations.schema_migrations')).map(x=>x.version));
const directory=resolve('.staging-private');await mkdir(directory,{recursive:true,mode:0o700});
const appliedNow=[];
for(const name of (await readdir('supabase/migrations')).filter(x=>/^\d{14}_[a-z0-9_]+\.sql$/.test(x)).sort()){
 const version=name.slice(0,14);if(applied.has(version))continue;
 const source=await readFile('supabase/migrations/'+name,'utf8');
 const sql=migrationSQL(name,source);
 const path=resolve(directory,'migration.sql');await writeFile(path,sql,{mode:0o600});
 await command(['db','query','--linked','--project-ref',target.projectRef,'--file',path,'--output','json']);appliedNow.push(version);
 console.log(JSON.stringify({migration:version,applied:true}));
}
await query(target,"notify pgrst,'reload schema';");
await assertIsolation(target);
// No provider keys, scheduled workers, or source data are copied.
await command(['functions','deploy','api','--project-ref',target.projectRef,'--use-api']);
console.log(JSON.stringify({projectRef:target.projectRef,migrations:appliedNow.length,apiDeployed:true,pushWorkerDeployed:false,flightProviderConfigured:false}));

// Apply exactly one migration, with source-drift checks and a private rollback bundle.
import {readFile,writeFile,mkdtemp,mkdir} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createHash} from 'node:crypto';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
const cli=resolve('node_modules/.bin/supabase'), project='cdhpaujazbuppbxyhjxq';
const version='20260927010000', name='capacity_guardrails';
const run=async args=>(await promisify(execFile)(cli,args,{timeout:120000,maxBuffer:8*1024*1024})).stdout;
const query=async sql=>JSON.parse(await run(['db','query','--linked','--project-ref',project,'--output','json',sql])).rows;
const names=['wif_trip_flight_lookup_begin','wif_trip_flight_lookup_cache','wif_trip_claim_refresh','wif_trip_finish_refresh','wif_trip_schedule_booking','wif_trip_booking_claim'];
const rows=await query(`select proname,md5(prosrc) as hash,pg_get_functiondef(oid) as definition from pg_proc where pronamespace='public'::regnamespace and proname in (${names.map(x=>`'${x}'`).join(',')}) order by proname`);
if(rows.length!==names.length)throw Error('Unexpected function set.');
const baseline=(await Promise.all(['20260906030000_trip_flight_lookup','20260909010000_trip_live_updates','20260917010000_trip_booking_reminders'].map(n=>readFile(resolve('supabase/migrations/'+n+'.sql'),'utf8')))).join('\n');
for(const row of rows){
 const start=baseline.indexOf('create function public.'+row.proname+'(');
 if(start<0)throw Error('Missing source baseline.');
 const a=baseline.indexOf('$$',start)+2,b=baseline.indexOf('$$;',a);
 if(createHash('md5').update(baseline.slice(a,b)).digest('hex')!==row.hash)throw Error('Production definition drift: '+row.proname);
}
const directory=await mkdtemp(join(tmpdir(),'across-capacity-rollback-'));
await writeFile(join(directory,'baseline.json'),JSON.stringify(rows,null,2),{mode:0o600});
await writeFile(join(directory,'restore-functions.sql'),'begin;\nset local lock_timeout=\'5s\';\n'+rows.map(r=>r.definition+';').join('\n')+'\ncommit;\n',{mode:0o600});
// Back up each deployed bundle independently: their shared files can have different revisions.
for(const fn of ['api','push-worker','trip-worker']){
 const target=join(directory,fn);await mkdir(join(target,'supabase'),{recursive:true});
 await writeFile(join(target,'supabase/config.toml'),await readFile(resolve('supabase/config.toml')),{mode:0o600});
 await run(['functions','download',fn,'--project-ref',project,'--use-api','--workdir',target]);
}
const source=await readFile(resolve(`supabase/migrations/${version}_${name}.sql`),'utf8');
if(source.includes('$capacity_source$'))throw Error('Unexpected delimiter.');
const guards=rows.map(row=>`if (select md5(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='${row.proname}') is distinct from '${row.hash}' then raise exception 'Function changed during deployment'; end if;`).join('\n');
const sql=`begin;
set local lock_timeout='5s'; set local statement_timeout='45s';
select pg_advisory_xact_lock(9270100);
do $$ begin
 if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Already applied; verify instead of replaying'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260923010000') then raise exception 'Baseline missing'; end if;
 ${guards}
end $$;
${source.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'')}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','${name}',ARRAY[$capacity_source$${source}$capacity_source$]);
commit;
select wif_capacity_health() as health;`;
const file=join(directory,'apply.sql');await writeFile(file,sql,{mode:0o600});
console.log(JSON.stringify({backup:directory,project,version,prepared:true}));
if(process.argv.includes('--apply')){
 console.log(await run(['db','query','--linked','--project-ref',project,'--output','json','--file',file]));
}

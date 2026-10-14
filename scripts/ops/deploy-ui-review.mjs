// Narrow, guarded rollout for the authorized UI-review/TestFlight release.
// Backups and command details stay in the ignored private directory.
import {readFile,writeFile,mkdir,readdir} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createHash} from 'node:crypto';
import {resolve,join,relative} from 'node:path';
const project='cdhpaujazbuppbxyhjxq',version='20260929010000',name='cancel_friend_requests';
const dir=resolve('.ops-private/ui-fixes-20260929'),cli=resolve('node_modules/.bin/supabase');
const sourcePath=`supabase/migrations/${version}_${name}.sql`,apiPath='supabase/functions/api/index.ts';
const sha=s=>createHash('sha256').update(s).digest('hex');
const md5=s=>createHash('md5').update(s).digest('hex');
const mode=process.argv[2]??'prepare';
if(!['prepare','apply','verify'].includes(mode))throw Error('Use prepare, apply or verify.');
await mkdir(dir,{recursive:true,mode:0o700});
async function run(args){
 try{return (await promisify(execFile)(cli,args,{timeout:180000,maxBuffer:16*1024*1024})).stdout;}
 catch(error){await writeFile(join(dir,'last-command-error.log'),`${error.stderr??''}\n${error.stdout??''}`,{mode:0o600});throw Error('Release command failed; details retained privately.');}
}
const query=async sql=>JSON.parse(await run(['db','query','--linked','--project-ref',project,'--output','json',sql])).rows;
const functions=async()=>JSON.parse(await run(['functions','list','--project-ref',project,'--output','json']));
const ledger=async()=>query('select version from supabase_migrations.schema_migrations order by version');
const definitions=async()=>query("select oid::regprocedure::text signature,md5(prosrc) hash,proacl,pg_get_functiondef(oid) definition from pg_proc where pronamespace='public'::regnamespace and prokind='f' order by 1");
async function bundle(folder){
 const target=join(dir,folder);await mkdir(join(target,'supabase'),{recursive:true,mode:0o700});
 await writeFile(join(target,'supabase/config.toml'),await readFile('supabase/config.toml'),{mode:0o600});
 await run(['functions','download','api','--project-ref',project,'--use-api','--workdir',target]);
 return target;
}
async function files(path){let out=[];for(const e of await readdir(path,{withFileTypes:true})){const p=join(path,e.name);out.push(...(e.isDirectory()?await files(p):[p]));}return out;}
async function checkBundle(folder,expectedIndex){
 const deployed=join(folder,'supabase/functions');
 if(sha(await readFile(join(deployed,'api/index.ts')))!==sha(expectedIndex))throw Error('API entrypoint differs from the reviewed baseline.');
 let checked=0;
 for(const file of await files(deployed)){
  const rel=relative(folder,file);
  if(rel===apiPath)continue;
  // Compare every shared module actually present in the deployed bundle.
  if(rel.startsWith('supabase/functions/_shared/')){
   if(sha(await readFile(file))!==sha(await readFile(rel)))throw Error('Shared API dependency drift: '+rel);
   checked++;
  }
 }
 return checked;
}
const migration=await readFile(sourcePath,'utf8'),apiSource=await readFile(apiPath);
if(mode==='prepare'){
 const [remote,versions,defs]=await Promise.all([functions(),ledger(),definitions()]);
 const api=remote.find(f=>f.name==='api'||f.slug==='api');
 if(!api||api.status!=='ACTIVE'||!api.verify_jwt)throw Error('Unexpected API readiness or JWT policy.');
 if(versions.some(v=>v.version===version)||defs.some(d=>d.signature.startsWith('wif_cancel_friend_request(')))throw Error('Migration already present; verify rather than replay.');
 for(const needed of ['20260915030000','20260927020000','20260927030000','20260927040000'])if(!versions.some(v=>v.version===needed))throw Error('Required baseline migration missing.');
 const baseline=(await promisify(execFile)('git',['show','HEAD:'+apiPath],{maxBuffer:4*1024*1024})).stdout;
 const before=await bundle('api-before');
 const sharedModules=await checkBundle(before,baseline);
 const guards=defs.filter(d=>['wif_snapshot(uuid)','wif_send_friend_request(uuid,text)','wif_respond_friend_request(uuid,uuid,text)'].includes(d.signature));
 if(guards.length!==3)throw Error('Missing invitation baseline functions.');
 const checks=guards.map(d=>`if (select md5(prosrc) from pg_proc where oid='public.${d.signature}'::regprocedure) is distinct from '${d.hash}' then raise exception 'Concurrent function change';end if;`).join('\n');
 const sql=`begin;set local lock_timeout='5s';set local statement_timeout='45s';select pg_advisory_xact_lock(9270100);
do $$ begin
if exists(select 1 from supabase_migrations.schema_migrations where version='${version}') then raise exception 'Already applied';end if;
if to_regprocedure('public.wif_cancel_friend_request(uuid,uuid)') is not null then raise exception 'Unexpected existing function';end if;
${checks}
end $$;
${migration.replace(/^begin;\s*/,'').replace(/commit;\s*$/,'')}
insert into supabase_migrations.schema_migrations(version,name,statements) values('${version}','${name}',ARRAY[$ui_review_source$${migration}$ui_review_source$]);
commit;notify pgrst,'reload schema';`;
 await writeFile(join(dir,'apply.sql'),sql,{mode:0o600});
 await writeFile(join(dir,'baseline.json'),JSON.stringify({project,at:new Date().toISOString(),apiVersion:api.version,remote,versions,defs,sharedModules,migrationSHA256:sha(migration),apiSHA256:sha(apiSource),applySHA256:sha(sql)},null,2),{mode:0o600});
 console.log(JSON.stringify({prepared:true,project,apiVersion:api.version,sharedModules,migration:version,backup:dir}));
 process.exit(0);
}
const before=JSON.parse(await readFile(join(dir,'baseline.json'),'utf8'));
if(before.project!==project||before.apiSHA256!==sha(apiSource)||before.migrationSHA256!==sha(migration))throw Error('Prepared release input changed.');
if(mode==='apply'){
 const live=(await functions()).find(f=>f.name==='api'||f.slug==='api');
 if(live.version!==before.apiVersion||!live.verify_jwt)throw Error('API changed after preparation.');
 if(sha(await readFile(join(dir,'apply.sql')))!==before.applySHA256)throw Error('Prepared SQL changed.');
 await run(['db','query','--linked','--project-ref',project,'--file',join(dir,'apply.sql'),'--output','json']);
 await run(['functions','deploy','api','--project-ref',project,'--use-api']);
 console.log(JSON.stringify({deployed:true,project,migration:version}));
}
const [live,versions,defs]=await Promise.all([functions(),ledger(),definitions()]);
const active=live.find(f=>f.name==='api'||f.slug==='api');
if(active.status!=='ACTIVE'||!active.verify_jwt)throw Error('Released API not active or JWT policy changed.');
const current=new Map(defs.map(d=>[d.signature,d]));
const originalFunctionsUnchanged=before.defs.every(d=>current.get(d.signature)?.hash===d.hash&&JSON.stringify(current.get(d.signature)?.proacl)===JSON.stringify(d.proacl));
const newFunction=current.get('wif_cancel_friend_request(uuid,uuid)');
const body=migration.match(/returns jsonb language plpgsql security definer set search_path = public as \$\$([\s\S]*?)\$\$/)?.[1];
if(!originalFunctionsUnchanged||!newFunction||!body||newFunction.hash!==md5(body))throw Error('Function verification failed.');
if(versions.length!==before.versions.length+1||!versions.some(v=>v.version===version))throw Error('Migration ledger differs from expected additive change.');
const permission=(await query("select has_function_privilege('anon','public.wif_cancel_friend_request(uuid,uuid)','EXECUTE') anon,has_function_privilege('authenticated','public.wif_cancel_friend_request(uuid,uuid)','EXECUTE') authenticated,has_function_privilege('service_role','public.wif_cancel_friend_request(uuid,uuid)','EXECUTE') service"))[0];
if(permission.anon||permission.authenticated||!permission.service)throw Error('RPC execution privileges are incorrect.');
const after=await bundle('api-after');const sharedModules=await checkBundle(after,apiSource);
const workersUnchanged=before.remote.filter(f=>f.name!=='api').every(f=>live.some(x=>x.id===f.id&&x.version===f.version&&x.verify_jwt===f.verify_jwt));
if(!workersUnchanged)throw Error('An unrelated function changed.');
const monitor=JSON.parse(await readFile('.ops-private/production-monitor.json','utf8'));
if(monitor.projectRef!==project||new URL(monitor.url).origin!==`https://${project}.supabase.co`)throw Error('Unexpected health target.');
const probe=await fetch(monitor.url,{redirect:'error',signal:AbortSignal.timeout(20000)});
const healthy=probe.status===200&&(await probe.text()).includes('Across Us');
const report={at:new Date().toISOString(),project,migration:version,apiVersion:active.version,apiSHA256:sha(apiSource),migrationSHA256:sha(migration),originalFunctionsUnchanged,workersUnchanged,sharedModules,serviceOnly:!permission.anon&&!permission.authenticated&&permission.service,healthStatus:probe.status,healthy};
await writeFile(join(dir,'verification.json'),JSON.stringify(report,null,2),{mode:0o600});
console.log(JSON.stringify(report));if(!healthy)process.exitCode=1;

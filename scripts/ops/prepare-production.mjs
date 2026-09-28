// Read-only backup + narrow monitoring patch. Never deploys or changes remote state.
import {readFile,writeFile,mkdir,cp} from 'node:fs/promises';import {execFile} from 'node:child_process';import {promisify} from 'node:util';import {resolve,join} from 'node:path';import {createHash} from 'node:crypto';
const cli=resolve('node_modules/.bin/supabase'),project='cdhpaujazbuppbxyhjxq',root=resolve('.ops-private/production');
const run=async args=>{try{return (await promisify(execFile)(cli,args,{timeout:90000,maxBuffer:16*1024*1024})).stdout;}catch{throw Error('Read-only backup command failed; sensitive output withheld.');}};
await mkdir(root,{recursive:true,mode:0o700});
const metadata=JSON.parse(await run(['functions','list','--project-ref',project,'--output','json']));
const query=async sql=>JSON.parse(await run(['db','query','--linked','--project-ref',project,'--output','json',sql])).rows;
const ledger=await query('select version from supabase_migrations.schema_migrations order by version');
await writeFile(join(root,'baseline.json'),JSON.stringify({project,at:new Date().toISOString(),functions:metadata,ledger},null,2),{mode:0o600});
const proofs=[];
for(const name of ['api','push-worker','trip-worker']){
 const before=join(root,'before',name),after=join(root,'release',name);
 await mkdir(join(before,'supabase'),{recursive:true,mode:0o700});await writeFile(join(before,'supabase/config.toml'),await readFile('supabase/config.toml'),{mode:0o600});
 await run(['functions','download',name,'--project-ref',project,'--use-api','--workdir',before]);
 await cp(before,after,{recursive:true});
 const file='supabase/functions/'+name+'/index.ts';const old=await readFile(join(before,file),'utf8'),current=await readFile(file,'utf8');let patched;
 if(name==='api'){
  const baseline=(await promisify(execFile)('git',['show','HEAD:'+file],{maxBuffer:2*1024*1024})).stdout;
  const oldStart=old.lastIndexOf('Deno.serve(async request => {'),expectedStart=baseline.lastIndexOf('Deno.serve(async request => {');
  const newStart=current.indexOf('const diagnosticLimiter = new Map();');
  if(oldStart<0||expectedStart<0||newStart<0||old.slice(oldStart).trim()!==baseline.slice(expectedStart).trim())throw Error('Production API handler drift; manual review required');
  const prefix=old.slice(0,oldStart);
  const updated=prefix.replace('"apikey, authorization, content-type, x-client-info"','"apikey, authorization, content-type, x-client-info, x-wif-request-id, x-wif-app-version"');
  if(prefix===updated)throw Error('Expected CORS anchor missing');
  patched=current.split('\n')[0]+'\n'+updated+current.slice(newStart);
 }else{
  const baseline=(await promisify(execFile)('git',['show','HEAD:'+file],{maxBuffer:2*1024*1024})).stdout;
  if(old!==baseline)throw Error('Deployed '+name+' differs from reviewed baseline');patched=current;
 }
 await writeFile(join(after,file),patched,{mode:0o600});
 await mkdir(join(after,'supabase/functions/_shared'),{recursive:true});await writeFile(join(after,'supabase/functions/_shared/observability.mjs'),await readFile('supabase/functions/_shared/observability.mjs'));
 proofs.push({name,beforeHash:createHash('sha256').update(old).digest('hex'),afterHash:createHash('sha256').update(patched).digest('hex'),version:metadata.find(f=>f.slug===name||f.name===name)?.version});
}
const ops=join(root,'release','ops-monitor');await mkdir(join(ops,'supabase/functions/_shared'),{recursive:true});await mkdir(join(ops,'supabase/functions/ops-monitor'),{recursive:true});
await writeFile(join(ops,'supabase/config.toml'),await readFile('supabase/config.toml'));
await writeFile(join(ops,'supabase/functions/ops-monitor/index.ts'),await readFile('supabase/functions/ops-monitor/index.ts'));
for(const f of ['observability.mjs','ops-health.mjs','upstream-policy.mjs'])await writeFile(join(ops,'supabase/functions/_shared',f),await readFile('supabase/functions/_shared/'+f));
await writeFile(join(root,'patch-proof.json'),JSON.stringify({project,proofs,includesUnreleasedPlanPagination:false,preparedAt:new Date().toISOString()},null,2),{mode:0o600});
console.log(JSON.stringify({prepared:true,project,proofs,includesUnreleasedPlanPagination:false}));

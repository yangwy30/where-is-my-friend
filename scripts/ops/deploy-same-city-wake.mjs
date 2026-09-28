// Deploy only same-city wake changes, preserving each deployed dependency bundle.
import {readFile,writeFile,mkdir,cp} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
const project='cdhpaujazbuppbxyhjxq',root=resolve('.ops-private/same-city-wake'),cli=resolve('node_modules/.bin/supabase');
const expected={api:27,'push-worker':21};
const hash=b=>createHash('sha256').update(b).digest('hex');
async function run(args){try{return (await promisify(execFile)(cli,args,{timeout:120000,maxBuffer:8*1024*1024})).stdout;}catch{throw Error('Deployment operation failed; sensitive output withheld.');}}
const versions=JSON.parse(await run(['functions','list','--project-ref',project,'--output','json']));
await mkdir(root,{recursive:true,mode:0o700});
const proof=[];
for(const fn of ['api','push-worker']){
 if(versions.find(f=>(f.name??f.slug)===fn)?.version!==expected[fn])throw Error('Function version drift: '+fn);
 const before=join(root,'before',fn),release=join(root,'release',fn);
 await mkdir(join(before,'supabase'),{recursive:true,mode:0o700});
 await writeFile(join(before,'supabase/config.toml'),await readFile('supabase/config.toml'));
 await run(['functions','download',fn,'--project-ref',project,'--use-api','--workdir',before]);
 const file=`supabase/functions/${fn}/index.ts`,old=await readFile(join(before,file));
 const baseline=(await promisify(execFile)('git',['show','5020f05:'+file],{maxBuffer:2*1024*1024})).stdout;
 if(!old.equals(Buffer.from(baseline)))throw Error('Source drift: '+fn);
 await cp(before,release,{recursive:true});
 const current=await readFile(file);await writeFile(join(release,file),current);
 if(fn==='api')await writeFile(join(release,'supabase/functions/_shared/invitation-wakeup.mjs'),await readFile('supabase/functions/_shared/invitation-wakeup.mjs'));
 proof.push({function:fn,version:expected[fn],before:hash(old),after:hash(current)});
}
await writeFile(join(root,'proof.json'),JSON.stringify({project,proof,preparedAt:new Date().toISOString()},null,2),{mode:0o600});
console.log(JSON.stringify({prepared:true,project,proof}));
if(!process.argv.includes('--apply'))process.exit(0);
// New worker understands the action before the API begins sending it.
for(const fn of ['push-worker','api']){
 await run(['functions','deploy',fn,'--project-ref',project,'--use-api','--workdir',join(root,'release',fn)]);
 console.log(JSON.stringify({deployed:fn}));
}
console.log(JSON.stringify({deployed:true,configurationUnchanged:true,migrationsApplied:0}));

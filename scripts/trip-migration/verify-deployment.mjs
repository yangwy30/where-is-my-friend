// Read-only verification against the private pre-deployment backup; no record bodies logged.
import {readFile,writeFile} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve} from 'node:path';
const directory=resolve('.migration-backups/app-predeploy-FMkxfv');
try {
 const before=JSON.parse(await readFile(resolve(directory,'snapshot.json'),'utf8'));
 const sql=`select jsonb_build_object(
  'functions',(select jsonb_agg(jsonb_build_object('signature',oid::regprocedure::text,'definition',pg_get_functiondef(oid),'acl',proacl)) from pg_proc where pronamespace='public'::regnamespace and prokind='f'),
  'test_accounts',(select count(*) from auth.users where email like 'trips-deployment-%@example.invalid'),
  'test_trips',(select count(*) from public.trips where id like 'deployment-smoke-%'),
  'trips',(select count(*) from public.trips),
  'versions',(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations)
 ) as verification`;
 const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),['db','query','--linked','--project-ref','cdhpaujazbuppbxyhjxq','--output','json',sql],{timeout:60000,maxBuffer:4*1024*1024});
 const after=JSON.parse(stdout).rows[0].verification;
 const current=new Map(after.functions.map(f=>[f.signature,f]));
 const unchanged=before.functions.every(f=>current.get(f.signature)?.definition===f.definition&&JSON.stringify(current.get(f.signature)?.acl)===JSON.stringify(f.acl));
 const report={verifiedAt:new Date().toISOString(),originalFunctionsUnchanged:unchanged,originalFunctionCount:before.functions.length,
  testAccountsRemaining:after.test_accounts,testTripsRemaining:after.test_trips,totalTrips:after.trips,versions:after.versions};
 await writeFile(resolve(directory,'verification.json'),JSON.stringify(report,null,2),{mode:0o600});
 console.log(JSON.stringify(report,null,2));
 if(!unchanged||after.test_accounts!==0||after.test_trips!==0)process.exitCode=1;
}catch{console.error('Read-only verification failed; no records or credentials logged.');process.exitCode=1;}

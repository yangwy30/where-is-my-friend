// Create at most 20 confirmed synthetic accounts; no emails or Apple credentials.
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
import {loadTarget,requestJSON,validatePrivateSession} from './target.mjs';
import {assertIsolation,keys,query} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');
await assertIsolation(target);
const count=Number(process.argv[3]??20);if(!Number.isInteger(count)||count<2||count>20)throw Error('Choose 2–20 users for the first hosted calibration');
const folder=resolve('.staging-private');await mkdir(folder,{recursive:true,mode:0o700});
const path=resolve(folder,'sessions.json');
try{await readFile(path);throw Error('Sessions already exist; clean up the previous run explicitly before creating more');}catch(e){if(e.code!=='ENOENT')throw e;}
const {anon,service}=await keys(target);
const session={projectRef:target.projectRef,runID:randomUUID(),anon,accounts:[]};
async function save(){await writeFile(path,JSON.stringify(session,null,2),{mode:0o600});}
async function auth(route,body,key){const r=await requestJSON(target.origin+'/auth/v1/'+route,{method:'POST',headers:{apikey:anon,Authorization:'Bearer '+key},body});if(r.status>=300)throw Error(`Auth ${route.split('?')[0]} failed with HTTP ${r.status}`);return r.data;}
try{
 for(let n=0;n<count;n++){
  const email=`staging-${session.runID}-${n}@example.invalid`,password=randomUUID()+randomUUID();
  const user=await auth('admin/users',{email,password,email_confirm:true,app_metadata:{isolated_test_run:session.runID}},service);
  if(!user.id)throw Error('Missing created account ID');
  const row={authID:user.id,email,password};session.accounts.push(row);await save();
  const token=await auth('token?grant_type=password',{email,password},anon);row.token=token.access_token;
  const r=await requestJSON(target.origin+'/functions/v1/api/v1/auth/bootstrap',{method:'POST',headers:{apikey:anon,Authorization:'Bearer '+row.token},body:{displayName:'Staging User '+(n+1)}});
  if(r.status!==200||!r.data.currentUser?.id)throw Error(`App bootstrap failed with HTTP ${r.status}`);
  row.appID=r.data.currentUser.id;await save();
 }
 validatePrivateSession(session,target);
 console.log(JSON.stringify({projectRef:target.projectRef,syntheticAccounts:session.accounts.length,sessionFile:path,credentialsPrinted:false}));
}catch(e){await save();console.error(e.message);console.error('Partial synthetic accounts recorded for cleanup; no automatic retry storm.');process.exitCode=1;}

// Deletes only this recorded synthetic run; preserves the dedicated project/schema.
import {readFile,writeFile} from 'node:fs/promises';
import {loadTarget,requestJSON} from './target.mjs';
import {assertIsolation,keys,query} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');await assertIsolation(target);
const path='.staging-private/sessions.json',session=JSON.parse(await readFile(path,'utf8'));
if(session.projectRef!==target.projectRef||!/^[a-f0-9-]{36}$/.test(session.runID??''))throw Error('Run does not belong to this project');
const {anon,service}=await keys(target),headers={apikey:anon,Authorization:'Bearer '+service};
const removed=[];
for(const a of session.accounts){
 if(!/^[a-f0-9-]{36}$/.test(a.authID??''))throw Error('Invalid recorded account ID');
 const existing=await requestJSON(target.origin+'/auth/v1/admin/users/'+a.authID,{headers});
 if(existing.status===404){removed.push(a.authID);continue;}
 if(existing.status!==200||existing.data.app_metadata?.isolated_test_run!==session.runID||existing.data.email!==a.email)throw Error('Refusing to delete an account without this run’s synthetic marker');
 const result=await requestJSON(target.origin+'/auth/v1/admin/users/'+a.authID,{method:'DELETE',headers});
 if(result.status!==200)throw Error('Synthetic account cleanup failed');removed.push(a.authID);
}
await query(target,`delete from public.trips where id like 'staging-${session.runID}-%' and name='Staging Trip';`);
// Replace the credential file with a receipt; tokens/passwords are no longer needed.
await writeFile(path,JSON.stringify({projectRef:target.projectRef,runID:session.runID,cleanedAt:new Date().toISOString(),removedAccounts:removed.length},null,2),{mode:0o600});
console.log(JSON.stringify({cleaned:true,removedAccounts:removed.length,projectPreserved:true}));

// Isolated Auth account; no real profile/device changes, no notifications.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
const project='cdhpaujazbuppbxyhjxq',base=`https://${project}.supabase.co`;
let service,anon,account;
const report=[];
async function request(path,method,body,key){
 const start=performance.now();
 const response=await fetch(base+path,{method,headers:{apikey:anon??key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
 const result=await response.json();
 report.push({path:path.split('?')[0],method,status:response.status,ms:Math.round(performance.now()-start)});
 if(!response.ok)throw new Error(`Probe ${method} ${path.split('?')[0]} returned ${response.status}`);
 return result;
}
try{
 const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),['projects','api-keys','--project-ref',project,'--reveal','--output','json'],{timeout:60000});
 const keys=JSON.parse(stdout);service=keys.find(k=>k.name==='service_role')?.api_key;anon=keys.find(k=>k.name==='anon')?.api_key;
 if(!service||!anon)throw new Error('Credentials unavailable');
 const email=`profile-probe-${randomUUID()}@example.invalid`,password=randomUUID()+randomUUID();
 account=await request('/auth/v1/admin/users','POST',{email,password,email_confirm:true},service);
 let session=await request('/auth/v1/token?grant_type=password','POST',{email,password},anon);
 const api='/functions/v1/api';
 let snapshot=await request(api+'/v1/auth/bootstrap','POST',{displayName:'Profile probe'},session.access_token);
 const username='probe_'+randomUUID().replaceAll('-','').slice(0,12);
 snapshot=await request(api+'/v1/profile','PATCH',{displayName:'Confirmed profile probe',username,avatarPalette:1},session.access_token);
 if(snapshot.currentUser.username!==username)throw new Error('PATCH returned wrong username');
 const responses=await Promise.all([
   request(api+'/v1/auth/bootstrap','POST',{},session.access_token),
   request(api+'/v1/profile','PATCH',{displayName:'Concurrent profile probe',username,avatarPalette:1},session.access_token),
   request(api+'/v1/travel-plans','GET',undefined,session.access_token),
 ]);
 session=await request('/auth/v1/token?grant_type=refresh_token','POST',{refresh_token:session.refresh_token},anon);
 snapshot=await request(api+'/v1/auth/bootstrap','POST',{},session.access_token);
 if(snapshot.currentUser.displayName!=='Concurrent profile probe')throw new Error('Saved profile reverted after refresh');
 console.log(JSON.stringify({passed:true,steps:report}));
}catch(error){console.error(JSON.stringify({passed:false,error:error.message,steps:report}));process.exitCode=1;}
finally{
 if(account?.id&&service){try{await request('/auth/v1/admin/users/'+account.id,'DELETE',undefined,service);console.log('Temporary Auth account and cascading app data removed.');}
 catch{console.error(`Cleanup required for temporary account ${account.id}`);process.exitCode=1;}}
}

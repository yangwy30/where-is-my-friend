// Read-only Management API log query. Reuse the CLI login without printing it.
import {execFileSync} from 'node:child_process';
const sql=process.argv[2];
if(!sql || (!['--auth-config','--project'].includes(sql) && !/^\s*select\b/i.test(sql))) throw new Error('SELECT required');
let token=process.env.SUPABASE_ACCESS_TOKEN;
if(!token)for(const account of ['access-token','supabase']){
 try {token=execFileSync('/usr/bin/security',['find-generic-password','-s','Supabase CLI','-a',account,'-w'],{encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:10000}).trim();if(token)break;}catch{}
}
if(token?.startsWith('go-keyring-base64:'))token=Buffer.from(token.slice(18),'base64').toString('utf8');
if(!token)throw new Error('Existing CLI login unavailable');
if(sql==='--project'){
 const res=await fetch('https://api.supabase.com/v1/projects/cdhpaujazbuppbxyhjxq',{headers:{Authorization:`Bearer ${token}`},signal:AbortSignal.timeout(45000)});
 const data=await res.json();console.log(JSON.stringify({status:res.status,region:data.region,projectStatus:data.status},null,2));process.exit(res.ok?0:1);
}
if(sql==='--auth-config'){
 const res=await fetch('https://api.supabase.com/v1/projects/cdhpaujazbuppbxyhjxq/config/auth',{headers:{Authorization:`Bearer ${token}`},signal:AbortSignal.timeout(45000)});
 const data=await res.json();
 const keys=['external_apple_enabled','external_apple_client_id','external_apple_skip_nonce_check','external_apple_allow_email_optional','disable_signup'];
 console.log(JSON.stringify({status:res.status,settings:Object.fromEntries(keys.map(k=>[k,data[k]??null]))},null,2));
 process.exit(res.ok?0:1);
}
const end=process.argv[4]??new Date().toISOString(),start=process.argv[3]??new Date(Date.parse(end)-86400000).toISOString();
const url=new URL('https://api.supabase.com/v1/projects/cdhpaujazbuppbxyhjxq/analytics/endpoints/logs');
url.search=new URLSearchParams({sql,iso_timestamp_start:start,iso_timestamp_end:end}).toString();
const res=await fetch(url,{headers:{Authorization:`Bearer ${token}`},signal:AbortSignal.timeout(45000)});
const body=await res.text();
console.log(JSON.stringify({status:res.status,start,end,data:JSON.parse(body)},null,2));

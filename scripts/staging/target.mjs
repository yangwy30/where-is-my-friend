import {readFile} from 'node:fs/promises';
export const protectedProjects=new Set(['cdhpaujazbuppbxyhjxq','zgqjctiuycrhwrstorxw','rjascsekngqbnzgwseyr']);
export const expectedName='across-us-isolated-staging';
export function validateTarget(value){
 if(!value||value.environment!=='isolated-staging'||value.projectName!==expectedName)throw Error('Explicit isolated staging configuration required');
 if(!/^[a-z]{20}$/.test(value.projectRef??'')||protectedProjects.has(value.projectRef))throw Error('Existing/live projects are forbidden test targets');
 if(!/^[a-z0-9-]{3,64}$/.test(value.organizationID??'')||value.region!=='us-east-2')throw Error('Expected organization and region required');
 return Object.freeze({...value,origin:`https://${value.projectRef}.supabase.co`});
}
export function verifyProject(target,projects){
 const project=projects.find(p=>(p.ref??p.id)===target.projectRef);
 if(!project||project.name!==expectedName||project.organization_id!==target.organizationID||project.region!==target.region||project.status!=='ACTIVE_HEALTHY')throw Error('Cloud project identity/status does not match isolated staging configuration');
 return project;
}
export function validatePrivateSession(session,target){
 if(session?.projectRef!==target.projectRef||!Array.isArray(session.accounts)||session.accounts.length<2||session.accounts.length>20)throw Error('2–20 isolated test sessions required');
 for(const account of session.accounts){
  const payload=decodeJWT(account.token);
  if(payload.iss!==`${target.origin}/auth/v1`||payload.role!=='authenticated'||payload.sub!==account.authID||typeof payload.exp!=='number'||!Number.isFinite(payload.exp)||payload.exp*1000<Date.now()+120000)throw Error('Session issuer, role, subject or expiry mismatch');
  if(![account.appID,account.authID].every(id=>/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(id??'')))throw Error('Invalid test account ID');
 }
 if(new Set(session.accounts.map(a=>a.authID)).size!==session.accounts.length||new Set(session.accounts.map(a=>a.appID)).size!==session.accounts.length)throw Error('Distinct test accounts required');
 return session;
}
function decodeJWT(token){try{return JSON.parse(Buffer.from(token.split('.')[1],'base64url'));}catch{throw Error('Invalid test session');}}
export async function loadTarget(path){return validateTarget(JSON.parse(await readFile(path,'utf8')));}
export async function requestJSON(url,{method='GET',headers={},body,timeout=20000,fetcher=fetch}={}){
 const response=await fetcher(url,{method,headers:{...headers,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(timeout),redirect:'error'});
 const text=await response.text();let data;try{data=JSON.parse(text);}catch{data=null;}
 return {status:response.status,data,bytes:Buffer.byteLength(text),edgeRegion:response.headers.get('x-sb-edge-region')};
}
export function assertMarker(marker,target){
 if(marker?.project_ref!==target.projectRef||marker?.environment!=='isolated-staging'||marker?.real_push_enabled!==false||marker?.flight_provider_enabled!==false)throw Error('Missing or unsafe staging environment marker');
}
export function validateLoadStages(stages){
 if(!Array.isArray(stages)||!stages.length||stages.some(n=>!Number.isInteger(n)||n<1||n>20)||stages.some((n,i)=>i>0&&n<=stages[i-1]))throw Error('Use increasing load tiers from 1 to 20 users');
 return stages;
}
export function shouldStop(rows){return rows.some(r=>r.status===401||r.status===403||r.status===429)||rows.filter(r=>!r.ok).length/Math.max(1,rows.length)>.02;}

export function assertEmptyUnmarkedProject(state){
 if(state?.marked===true)return;
 if(state?.marked!==false||state.public_table_count!==0||state.auth_count!==0)throw Error('Only a fresh empty project can be initialized');
}

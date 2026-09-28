// Operational metadata only: never accept raw paths, bodies, tokens or messages.
export const features=new Set(['login','home','plans','trips','notifications']);
export const kinds=new Set(['server_error','decode_error','timeout','slow_request','push_configuration']);
const uuid=/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;
export function featureForPath(path){
 const p=new URL(path,'https://local.invalid').pathname.replace(/^.*\/v[12](?=\/)/,'');
 if(p.startsWith('/auth/'))return 'login';
 if(/^\/(travel-plans|friend-plans|own-plans|travel-overlaps)(\/|$)/.test(p))return 'plans';
 if(/^\/(trips|trip-invitations|trip-reminders)(\/|$)/.test(p))return 'trips';
 if(p==='/bootstrap'||p.startsWith('/friends/')||p==='/profile'||p==='/account')return 'home';
 return null;
}
export function safeVersion(value){return typeof value==='string'&&/^[a-zA-Z0-9._+()-]{1,32}$/.test(value)?value:'unknown';}
export function apiObservation(request,status,elapsed,{id,now=Date.now(),limiter=new Map()}={}){
 const feature=featureForPath(request.url);if(!feature)return null;
 const kind=status>=500||status===408||status===429?'server_error':status>=200&&status<300&&elapsed>=3000?'slow_request':null;
 if(!kind)return null;
 const key=feature+':'+kind,interval=kind==='slow_request'?30000:5000;
 if(limiter.has(key)&&now-limiter.get(key)<interval)return null;limiter.set(key,now);
 const rawID=id??request.headers.get('x-wif-request-id');
 return {eventID:uuid.test(rawID??'')?rawID:crypto.randomUUID(),feature,kind,status,elapsedMs:Math.min(120000,Math.max(0,Math.round(elapsed))),version:safeVersion(request.headers.get('x-wif-app-version'))};
}
export function clientObservation(body){
 const allowed=new Set(['eventID','feature','kind','status','elapsedMs','version']);
 if(!body||Array.isArray(body)||Object.keys(body).some(k=>!allowed.has(k)))throw Error('Invalid diagnostic event');
 if(!uuid.test(body.eventID??'')||!features.has(body.feature)||!['decode_error','timeout','server_error'].includes(body.kind)||!Number.isInteger(body.status)||body.status<0||body.status>599||!Number.isInteger(body.elapsedMs)||body.elapsedMs<0||body.elapsedMs>120000||safeVersion(body.version)!==body.version)throw Error('Invalid diagnostic event');
 if(body.kind==='server_error'&&body.status<500)throw Error('Expected permission/session responses are not incidents');
 return body;
}
export async function postObservation(origin,key,event,{source='server',authID=null,fetcher=fetch,timeoutMs=1200}={}){
 const response=await fetcher(origin+'/rest/v1/rpc/wif_ops_record_event',{method:'POST',redirect:'error',signal:AbortSignal.timeout(timeoutMs),headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({p_source:source,p_event_id:event.eventID,p_feature:event.feature,p_kind:event.kind,p_status:event.status,p_elapsed_ms:event.elapsedMs,p_version:event.version,p_auth_id:authID})});
 if(!response.ok)throw Error('Diagnostic storage unavailable');return response.json();
}
export async function postHeartbeat(origin,key,worker,ok,{fetcher=fetch}={}){
 const r=await fetcher(origin+'/rest/v1/rpc/wif_ops_worker_heartbeat',{method:'POST',redirect:'error',signal:AbortSignal.timeout(1200),headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({p_worker:worker,p_ok:ok})});
 if(!r.ok)throw Error('Heartbeat unavailable');
}
export function backgroundObservation(promise,runtime=globalThis.EdgeRuntime){
 const safe=promise.catch(()=>console.warn(JSON.stringify({event:'diagnostic_write_unavailable'})));
 if(runtime?.waitUntil)runtime.waitUntil(safe);
}
export const pushConfigurationReasons=new Set(['InvalidProviderToken','ExpiredProviderToken','MissingProviderToken','TopicDisallowed','BadCertificate','BadCertificateEnvironment','Forbidden']);

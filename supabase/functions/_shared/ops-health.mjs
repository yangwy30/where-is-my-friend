export function evaluateHealth(snapshot,{now=Date.now(),apiAvailable=true,pushSigningReady=true}={}){
 const issues=[];
 if(!pushSigningReady)issues.push({feature:'notifications',code:'push_configuration'});
 if(!apiAvailable)issues.push({feature:'login',code:'api_unavailable'});
 for(const f of snapshot.features??[]){
  if(Number(f.server_errors)>=5)issues.push({feature:f.feature,code:'repeated_server_errors'});
  if(Number(f.decode_errors)>=3)issues.push({feature:f.feature,code:'client_decode_errors'});
  if(Number(f.timeouts)>=5)issues.push({feature:f.feature,code:'repeated_timeouts'});
  if(Number(f.push_errors)>0)issues.push({feature:'notifications',code:'push_configuration'});
  if(Number(f.slow_reports)>=5&&Number(f.slow_minutes)>=3)issues.push({feature:f.feature,code:'persistent_slow_requests'});
 }
 for(const q of snapshot.queues??[])if(Number(q.overdue)>0)issues.push({feature:'notifications',code:'queue_overdue',queue:q.kind});
 for(const w of snapshot.workers??[]){
  const threshold=w.worker==='push'?10*60000:30*60000;
  const since=Date.parse(w.last_success??w.enabled_at);
  if(w.expected&&Number.isFinite(since)&&now-since>threshold)issues.push({feature:'notifications',code:'worker_stale',worker:w.worker});
 }
 return {status:issues.length?'degraded':'ok',checkedAt:new Date(now).toISOString(),issues};
}
export function healthHTML(result){
 const labels={login:'Sign-in & API',home:'Friends',plans:'Friend plans',trips:'Trips',notifications:'Notifications'};
 const active=new Set(result.issues.map(x=>x.feature));
 const rows=Object.entries(labels).map(([key,name])=>`<li><span>${name}</span><strong class="${active.has(key)?'bad':'good'}">${active.has(key)?'Needs attention':'OK'}</strong></li>`).join('');
 return `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="robots" content="noindex,nofollow"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Across Us · Service status</title><style>body{font:17px system-ui;background:#f6f8ef;color:#15382b;margin:0;padding:40px 24px}main{max-width:540px;margin:40px auto}h1{font-size:32px}ul{padding:0;list-style:none;background:white;border-radius:20px}li{display:flex;justify-content:space-between;padding:20px;border-bottom:1px solid #edf0e6}.good{color:#007c59}.bad{color:#b34229}small{color:#657468}</style><main><small>ACROSS US</small><h1>${result.status==='ok'?'Services are healthy':'A service needs attention'}</h1><ul>${rows}</ul><small>Checked ${result.checkedAt}</small></main></html>`;
}
export function equalSecret(a,b){
 if(typeof a!=='string'||typeof b!=='string'||a.length!==b.length)return false;
 let diff=0;for(let i=0;i<a.length;i++)diff|=a.charCodeAt(i)^b.charCodeAt(i);return diff===0;
}
export async function boundedJSON(request,maxBytes=2048){
 const reader=request.body?.getReader();if(!reader)throw Error('Missing body');let size=0;const chunks=[];
 try{while(true){const {value,done}=await reader.read();if(done)break;size+=value.byteLength;if(size>maxBytes){await reader.cancel();throw Error('Body too large');}chunks.push(value);}}finally{reader.releaseLock();}
 const bytes=new Uint8Array(size);let cursor=0;for(const chunk of chunks){bytes.set(chunk,cursor);cursor+=chunk.byteLength;}return JSON.parse(new TextDecoder().decode(bytes));
}

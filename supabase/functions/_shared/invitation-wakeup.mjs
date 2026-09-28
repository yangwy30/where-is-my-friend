// Business writes must succeed independently of APNs. Durable queues + cron
// remain the fallback when this best-effort, post-commit wake-up fails.
const cityWakeLimiter = new Map();
export function wakeInvitationWorker({baseURL, secret, waitUntil, fetcher=fetch, action="invitations", now=Date.now(), limiter=cityWakeLimiter}) {
    if(!["invitations","trip-reminders","colocation"].includes(action)) return false;
    if(!baseURL || !secret || typeof waitUntil !== 'function') return false;
    let url;
    try { url=new URL('/functions/v1/push-worker',baseURL); } catch { return false; }
    if(action==='colocation'){
        if(limiter.has(url.origin)&&now-limiter.get(url.origin)<5000)return false;
        limiter.set(url.origin,now);
    }
    const task=Promise.resolve().then(()=>fetcher(url,{method:'POST',headers:{Authorization:`Bearer ${secret}`,'Content-Type':'application/json'},
        body:JSON.stringify({action}),redirect:'error',signal:AbortSignal.timeout(8000)})
    )
        .then(async response=>{await response.text(); if(!response.ok) console.warn('Invitation wake-up failed; queued for scheduled retry.');})
        .catch(()=>console.warn('Invitation wake-up unavailable; queued for scheduled retry.'));
    try { waitUntil(task); } catch { return false; }
    return true;
}

import test from 'node:test';
import assert from 'node:assert/strict';
import {resilientSupabaseFetch,temporaryStatus,retryableRead} from '../functions/_shared/upstream-policy.mjs';
const origin='https://example.supabase.co';
const request=(path,method='POST')=>new Request(origin+path,{method,headers:{Authorization:'Bearer never-log-this'},
    ...(method==='POST'?{body:JSON.stringify({p_user_id:'private-id'})}:{})});

test('read retry is exactly bounded and preserves the RPC payload',async()=>{
    const seen=[],logs=[];
    const transport=resilientSupabaseFetch(origin,{delay:async()=>{},log:e=>logs.push(e),fetchImpl:async r=>{
        seen.push(await r.text());return new Response(seen.length===1?'Gateway Timeout':'{"id":1}',{status:seen.length===1?504:200});
    }});
    assert.equal((await transport(request('/rest/v1/rpc/wif_resolve_app_user'))).status,200);
    assert.equal(seen.length,2);assert.equal(seen[0],seen[1]);
    assert.equal(logs[0].status,504);assert.doesNotMatch(JSON.stringify(logs),/never-log-this|private-id/);
    let attempts=0;
    const failing=resilientSupabaseFetch(origin,{delay:async()=>{},log:()=>{},fetchImpl:async()=>{attempts++;return new Response('Gateway Timeout',{status:504});}});
    assert.equal((await failing(request('/auth/v1/user','GET'))).status,504);assert.equal(attempts,2);
});

test('writes, invitations, paid lookup, token exchange and foreign origins never replay',async()=>{
    for(const path of ['/rest/v1/rpc/wif_update_profile','/rest/v1/rpc/wif_trip_invite',
        '/rest/v1/rpc/wif_trip_flight_lookup_begin','/rest/v1/rpc/wif_ensure_app_user','/auth/v1/token']) {
        let attempts=0;
        const transport=resilientSupabaseFetch(origin,{delay:async()=>{},log:()=>{},fetchImpl:async()=>{attempts++;return new Response('Gateway Timeout',{status:504});}});
        assert.equal((await transport(request(path))).status,504);assert.equal(attempts,1,path);
    }
    assert.equal(retryableRead(new Request('https://other.example/auth/v1/user'),origin),false);
});

test('auth rejection and rate limits do not retry',async()=>{
    for(const status of [400,401,403,429]){
        let attempts=0;
        const transport=resilientSupabaseFetch(origin,{delay:async()=>{},log:()=>{},fetchImpl:async()=>{attempts++;return new Response('{}',{status});}});
        assert.equal((await transport(request('/auth/v1/user','GET'))).status,status);assert.equal(attempts,1);
    }
});

test('transport timeout terminates, safe reads retry once, writes never retry',async()=>{
    for(const [path,method,expected] of [['/auth/v1/user','GET',2],['/rest/v1/rpc/wif_update_profile','POST',1]]){
        let attempts=0;
        const transport=resilientSupabaseFetch(origin,{timeoutMs:5,delay:async()=>{},log:()=>{},fetchImpl:async r=>{
            attempts++;return new Promise((_,reject)=>r.signal.addEventListener('abort',()=>reject(new DOMException('Aborted','AbortError')),{once:true}));
        }});
        await assert.rejects(transport(request(path,method)),/timed out/);assert.equal(attempts,expected);
    }
});

test('network failures retry a safe read once and retain temporary classification',async()=>{
    let attempts=0;
    const transport=resilientSupabaseFetch(origin,{delay:async()=>{},log:()=>{},fetchImpl:async()=>{attempts++;throw new TypeError('fetch failed with private data');}});
    await assert.rejects(transport(request('/auth/v1/user','GET')),error=>temporaryStatus(error)===503 && !error.message.includes('private data'));
    assert.equal(attempts,2);
});

test('caller cancellation does not trigger another request',async()=>{
    const controller=new AbortController();let attempts=0;
    const transport=resilientSupabaseFetch(origin,{delay:async()=>{},log:()=>{},fetchImpl:async()=>{attempts++;controller.abort();throw new Error('cancelled');}});
    await assert.rejects(transport(new Request(origin+'/auth/v1/user',{signal:controller.signal})));
    assert.equal(attempts,1);
});

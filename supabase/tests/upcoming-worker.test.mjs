import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';
import {deliverUpcoming,normalizeAPNsPrivateKey} from '../functions/_shared/travel-plans.mjs';
import {classifyAPNsResponse} from '../functions/_shared/push-security.mjs';
import {deliverTripInvitations} from '../functions/_shared/trip-invitations.mjs';
import {deliverFriendInvitations} from '../functions/_shared/friend-invitations.mjs';

test('friend invitation immediate wake-up sends its own APNs payload without claiming unrelated queues',async()=>{
 let handler;const calls=[],sent=[];
 const source=(await readFile(new URL('../functions/push-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
 const requestID='10000000-0000-4000-8000-000000000001';
 const delivery={delivery_id:'friend-delivery',device_id:'device',environment:'production',bundle_id:'com.yangwy30.whereismyfriend',
   event_id:'10000000-0000-4000-8000-000000000002',deep_link:`whereismyfriend://friend-requests/${requestID}`,
   title:'Friend request',body:'A friend wants to connect.',encrypted_apns_token:'encrypted-test-token',expires_at:2000000000};
 class JWT {setProtectedHeader(){return this;}setIssuer(){return this;}setIssuedAt(){return this;}async sign(){return 'test-provider-token';}}
 vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),{
  Request,Response,URL,console,crypto:webcrypto,AbortSignal,deliverUpcoming,deliverTripInvitations,deliverFriendInvitations,normalizeAPNsPrivateKey,classifyAPNsResponse,
  createClient:()=>({rpc:async(name,args)=>{calls.push({name,args});return {data:name==='wif_friend_invitation_claim'?[{delivery_id:delivery.delivery_id}]
   :name==='wif_friend_invitation_prepare'?delivery:name==='wif_friend_invitation_complete'?true:[],error:null};}}),
  importPKCS8:async()=>({}),SignJWT:JWT,decryptAPNSToken:async()=> 'test-token',
  fetch:async(url,init)=>{sent.push({url,init});return new Response('',{status:200});},
  Deno:{env:{get:name=>name==='PUSH_WORKER_SECRET'?'worker-secret':'test-config'},serve:callback=>handler=callback},
 });
 const response=await handler(new Request('https://example.test',{method:'POST',headers:{Authorization:'Bearer worker-secret'},body:JSON.stringify({action:'invitations'})}));
 const summary=await response.json();assert.equal(summary.delivered,1);assert.equal(summary.friendInvitationError,false);
 assert.equal(sent.length,1);assert.equal(sent[0].init.headers['apns-topic'],'com.yangwy30.whereismyfriend');
 assert.equal(sent[0].init.headers['apns-expiration'],'2000000000');
 const payload=JSON.parse(sent[0].init.body);assert.equal(payload.deepLink,delivery.deep_link);assert.equal(payload.aps['thread-id'],'friend-invitations');
 assert.equal(calls.find(c=>c.name==='wif_friend_invitation_complete').args.p_outcome,'delivered');
 assert(!calls.some(c=>c.name==='wif_claim_notification_deliveries'||c.name==='wif_travel_claim'));
});

test('push worker authenticates before signing/claiming, idle queues do not sign, readiness probe never sends',async()=>{
    let handler,signing=0,sends=0;const calls=[];
    const source=(await readFile(new URL('../functions/push-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
    const context={Request,Response,URL,console,crypto:webcrypto,deliverUpcoming,deliverTripInvitations,deliverFriendInvitations,normalizeAPNsPrivateKey,classifyAPNsResponse,
        createClient:()=>({rpc:async(name)=>{calls.push(name);return {data:[],error:null};}}),
        importPKCS8:async()=>{signing++;throw new TypeError('Invalid test key');},
        SignJWT:class {},decryptAPNSToken:async()=>{throw new Error('Must not decrypt without work');},
        fetch:async()=>{sends++;throw new Error('Unexpected APNs request');},
        Deno:{env:{get:name=>name==='PUSH_WORKER_SECRET'?'worker-secret':'test-config'},serve:callback=>{handler=callback;}}
    };
    vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),context);
    const request=(token,body={})=>handler(new Request('https://example.test',{method:'POST',headers:{Authorization:`Bearer ${token}`},body:JSON.stringify(body)}));
    assert.equal((await request('public-key',{action:'check-signing'})).status,401);
    assert.equal(calls.length,0);assert.equal(signing,0);
    const idle=await request('worker-secret');assert.equal(idle.status,200);
    assert.equal((await idle.json()).upcomingError,false);
    assert.equal(signing,0);assert.equal(sends,0);
    const count=calls.length;
    const health=await request('worker-secret',{action:'check-signing'});
    assert.equal(health.status,503);assert.equal((await health.json()).signingReady,false);
    assert.equal(calls.length,count);assert.equal(signing,1);assert.equal(sends,0);
});

test('parallel deliveries share one signing operation instead of minting a token per device',async()=>{
    let handler,signing=0,sends=0;
    const source=(await readFile(new URL('../functions/push-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
    const delivery={delivery_id:'test-delivery',device_id:'test-device',environment:'sandbox',bundle_id:'test.bundle',event_id:'event',deep_link:'test://event',title:'Test',body:'Test',encrypted_apns_token:'test'};
    class JWT { setProtectedHeader(){return this;} setIssuer(){return this;} setIssuedAt(){return this;} async sign(){return 'test-provider-token';} }
    const context={Request,Response,URL,console,crypto:webcrypto,AbortSignal,deliverUpcoming,deliverTripInvitations,deliverFriendInvitations,normalizeAPNsPrivateKey,classifyAPNsResponse,
        createClient:()=>({rpc:async(name)=>({data:name==='wif_claim_notification_deliveries'?[delivery,{...delivery,delivery_id:'second'}]:['wif_travel_claim','wif_trip_invitation_claim'].includes(name)?[]:true,error:null})}),
        importPKCS8:async()=>{signing++;await new Promise(resolve=>setTimeout(resolve,20));return {};},SignJWT:JWT,
        decryptAPNSToken:async()=> 'test-token',fetch:async()=>{sends++;return new Response('{}',{status:200});},
        Deno:{env:{get:name=>name==='PUSH_WORKER_SECRET'?'worker-secret':'test-config'},serve:callback=>{handler=callback;}}
    };
    vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),context);
    const response=await handler(new Request('https://example.test',{method:'POST',headers:{Authorization:'Bearer worker-secret'},body:'{}'}));
    assert.equal((await response.json()).delivered,2);assert.equal(signing,1);assert.equal(sends,2);
});

test('trip invitation reaches APNs with the account-bound join link and correct completion queue',async()=>{
    let handler;const calls=[],requests=[];
    const source=(await readFile(new URL('../functions/push-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
    const delivery={delivery_id:'invite-delivery',device_id:'test-device',environment:'production',bundle_id:'test.bundle',event_id:'11111111-2222-4333-8444-555555555555',deep_link:'whereismyfriend://trips/join/11111111-2222-4333-8444-555555555555',title:'Trip invitation',body:'Open Across Us to review.',encrypted_apns_token:'test',expires_at:2000000000};
    class JWT {setProtectedHeader(){return this;}setIssuer(){return this;}setIssuedAt(){return this;}async sign(){return 'test-provider-token';}}
    const context={Request,Response,URL,console,crypto:webcrypto,AbortSignal,deliverUpcoming,deliverTripInvitations,deliverFriendInvitations,normalizeAPNsPrivateKey,classifyAPNsResponse,
      createClient:()=>({rpc:async(name,args)=>{calls.push({name,args});return {data:name==='wif_trip_invitation_claim'?[{delivery_id:delivery.delivery_id}]:name==='wif_trip_invitation_prepare'?delivery:name.endsWith('_complete')?true:[],error:null};}}),
      importPKCS8:async()=>({}),SignJWT:JWT,decryptAPNSToken:async()=> 'test-token',
      fetch:async(url,options)=>{requests.push({url,options});return new Response('{}',{status:200});},
      Deno:{env:{get:name=>name==='PUSH_WORKER_SECRET'?'worker-secret':'test-config'},serve:callback=>{handler=callback;}}
    };
    vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),context);
    const result=await handler(new Request('https://example.test',{method:'POST',headers:{Authorization:'Bearer worker-secret'},body:'{}'}));
    const summary=await result.json();assert.equal(summary.delivered,1);assert.equal(summary.invitationError,false);
    assert.equal(requests.length,1);assert.equal(requests[0].url,'https://api.push.apple.com/3/device/test-token');
    const payload=JSON.parse(requests[0].options.body);
    assert.equal(payload.aps['thread-id'],'trip-invitations');assert.equal(payload.deepLink,delivery.deep_link);
    assert.equal(requests[0].options.headers['apns-expiration'],'2000000000');
    assert.ok(calls.some(c=>c.name==='wif_trip_invitation_complete'&&c.args.p_outcome==='delivered'));
});

test('environment mismatch ends the failed delivery without retrying it or disabling the device',async()=>{
    let handler,sends=0;const calls=[];
    const source=(await readFile(new URL('../functions/push-worker/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
    const delivery={delivery_id:'existing-failed-delivery',device_id:'valid-device',environment:'sandbox',bundle_id:'test.bundle',event_id:'event',deep_link:'test://event',title:'Test',body:'Test',encrypted_apns_token:'test'};
    class JWT {setProtectedHeader(){return this;}setIssuer(){return this;}setIssuedAt(){return this;}async sign(){return 'test-provider-token';}}
    vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),{
      Request,Response,URL,console,crypto:webcrypto,AbortSignal,deliverUpcoming,deliverTripInvitations,deliverFriendInvitations,normalizeAPNsPrivateKey,classifyAPNsResponse,
      createClient:()=>({rpc:async(name,args)=>{calls.push({name,args});return {data:name==='wif_claim_notification_deliveries'?[delivery]:['wif_complete_notification_delivery','wif_colocation_delivery_allowed'].includes(name)?true:[],error:null};}}),
      importPKCS8:async()=>({}),SignJWT:JWT,decryptAPNSToken:async()=> 'test-token',
      fetch:async()=>{sends++;return Response.json({reason:'BadEnvironmentKeyInToken'},{status:403});},
      Deno:{env:{get:name=>name==='PUSH_WORKER_SECRET'?'worker-secret':'test-config'},serve:callback=>handler=callback},
    });
    const response=await handler(new Request('https://example.test',{method:'POST',headers:{Authorization:'Bearer worker-secret'},body:'{}'}));
    const summary=await response.json();assert.equal(summary.failed,1);assert.equal(summary.retried,0);assert.equal(sends,1);
    const completed=calls.filter(c=>c.name==='wif_complete_notification_delivery');assert.equal(completed.length,1);
    assert.equal(completed[0].args.p_outcome,'failed');assert.equal(completed[0].args.p_disable_device,false);
    assert.equal(completed[0].args.p_error,'APNs 403: BadEnvironmentKeyInToken');
});

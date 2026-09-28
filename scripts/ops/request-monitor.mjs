// Official UptimeRobot agent flow. A 200 response is NOT proof of activation.
import {readFile,writeFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const config=JSON.parse(await readFile('.ops-private/production-monitor.json','utf8'));
const url=new URL(config.url),email=config.recipient?.trim().toLowerCase();
if(config.projectRef!=='cdhpaujazbuppbxyhjxq'||url.origin!=='https://cdhpaujazbuppbxyhjxq.supabase.co'||!/^\/functions\/v1\/ops-monitor\/status\/[a-f0-9]{64}$/.test(url.pathname)||url.search||url.hash||!email||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw Error('Reviewed production monitor and owner email required');
const signature=createHash('sha256').update(email+'\n'+url.href).digest('hex'),path='.ops-private/uptimerobot-request.json';
try{const old=JSON.parse(await readFile(path,'utf8'));if(old.fingerprint===signature)throw Error('An activation request already exists; check the inbox instead of sending a duplicate.');}catch(e){if(e.code!=='ENOENT')throw e;}
const ready=await fetch(url,{redirect:'error',signal:AbortSignal.timeout(15000)});if(ready.status!==200)throw Error('Production monitor must be healthy before requesting activation');
const endpoint=new URL('https://api.uptimerobot.com/agentic/agent-monitor/challenge');endpoint.search=new URLSearchParams({email,url:url.href}).toString();
const response=await fetch(endpoint,{redirect:'error',signal:AbortSignal.timeout(20000)});if(!response.ok)throw Error('Challenge request returned '+response.status);
const challenge=await response.json();
if(typeof challenge.nonce!=='string'||!/^[a-f0-9]+$/i.test(challenge.nonce)||typeof challenge.signature!=='string'||!Number.isFinite(challenge.timestamp)||!Number.isInteger(challenge.difficulty)||challenge.difficulty<1||challenge.difficulty>30)throw Error('Unexpected challenge');
let counter=0;const deadline=Date.now()+120000;
while(true){const hash=createHash('sha256').update(challenge.nonce+'|'+counter).digest();let zeros=0;for(const byte of hash){if(byte===0)zeros+=8;else{zeros+=Math.clz32(byte)-24;break;}}if(zeros>=challenge.difficulty)break;counter++;if(counter%100000===0&&Date.now()>deadline)throw Error('Challenge exceeded bounded solve time; no activation requested');}
const receipt={fingerprint:signature,requestedAt:new Date().toISOString(),provider:'UptimeRobot',recipient:email,monitorURL:url.href,state:'submission_attempted',active:false};
await writeFile(path,JSON.stringify(receipt,null,2),{mode:0o600});
const submitted=await fetch('https://api.uptimerobot.com/agentic/agent-monitor',{method:'POST',redirect:'error',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,url:url.href,nonce:challenge.nonce,timestamp:challenge.timestamp,counter,signature:challenge.signature}),signal:AbortSignal.timeout(20000)});
receipt.httpStatus=submitted.status;receipt.state=submitted.status===200?'owner_confirmation_pending':'provider_error';
await writeFile(path,JSON.stringify(receipt,null,2),{mode:0o600});
if(submitted.status!==200)throw Error('Activation submission returned '+submitted.status+'; inspect before retrying');
console.log(JSON.stringify({requestSubmitted:true,activationConfirmed:false,ownerConfirmationRequired:true,provider:'UptimeRobot',intervalMinutes:5}));

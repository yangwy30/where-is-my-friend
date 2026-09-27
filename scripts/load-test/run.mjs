// LOCAL ONLY. No production credentials, remote targets, live APNs or flight calls.
import {createRequire,stripTypeScriptTypes} from 'node:module';
import {readFile,readdir,writeFile,mkdtemp,mkdir} from 'node:fs/promises';
import {resolve,join,dirname} from 'node:path';
import {tmpdir,cpus,totalmem,freemem,platform,arch} from 'node:os';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {createServer,request as httpRequest,Agent} from 'node:http';
import net from 'node:net';
import vm from 'node:vm';
import {performance,monitorEventLoopDelay} from 'node:perf_hooks';
import {createHarness} from './api-harness.mjs';
import {deliveryGate,drainQueues,workerFetch,settleBatch} from '../../supabase/functions/_shared/queue-drain.mjs';
import {deliverUpcoming,normalizeAPNsPrivateKey} from '../../supabase/functions/_shared/travel-plans.mjs';
import {deliverFriendInvitations} from '../../supabase/functions/_shared/friend-invitations.mjs';
import {deliverTripInvitations} from '../../supabase/functions/_shared/trip-invitations.mjs';
import {deliverTripBookingReminders} from '../../supabase/functions/_shared/trip-booking-reminders.mjs';
import {classifyAPNsResponse} from '../../supabase/functions/_shared/push-security.mjs';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const args=Object.fromEntries(process.argv.slice(2).map(s=>s.replace(/^--/,'').split('=')));
const runtime=resolve(args.runtime??dirname(fileURLToPath(import.meta.url)));
const require=createRequire(join(runtime,'package.json'));
const {default:EmbeddedPostgres}=await import(pathToFileURL(require.resolve('embedded-postgres')));
const {Pool}=require('pg');
const output=resolve(args.output??join(tmpdir(),'across-load-'+Date.now()));
await mkdir(output,{recursive:true});
const work=await mkdtemp(join(tmpdir(),'across-load-db-'));
const port=await new Promise((ok,bad)=>{const s=net.createServer();s.on('error',bad);s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>ok(p));});});
const secret=randomUUID();
const friendCount=args.dense?100:20,planCount=args.dense?10:3;
const cluster=new EmbeddedPostgres({databaseDir:join(work,'db'),user:'postgres',password:secret,authMethod:'scram-sha-256',
 port,persistent:true,createPostgresUser:false,
 postgresFlags:['-c','listen_addresses=127.0.0.1','-c','max_connections=50','-c','shared_buffers=128MB','-c','work_mem=4MB','-c',`unix_socket_directories=${work}`],
 onLog:()=>{},onError:()=>{}});
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const quantile=(values,p)=>values.length?Number([...values].sort((a,b)=>a-b)[Math.min(values.length-1,Math.floor(values.length*p))].toFixed(2)):0;
const timing=values=>({p50:quantile(values,.5),p95:quantile(values,.95),p99:quantile(values,.99),max:values.length?Number(Math.max(...values).toFixed(2)):0});
const rpcMetrics=[],requestMetrics=[],stages=[];
const httpAgent=new Agent({keepAlive:true,maxSockets:1200,maxFreeSockets:1200,timeout:120000});
async function localHTTP(path,{method='GET',headers={},body}={}){
 const url=new URL(base+path);if(url.hostname!=='127.0.0.1')throw Error('Remote load target forbidden');
 return new Promise((resolve,reject)=>{
  const r=httpRequest(url,{method,headers,agent:httpAgent},res=>{
   const chunks=[];res.on('data',c=>chunks.push(c));res.on('error',reject);
   res.on('end',()=>resolve({status:res.statusCode,text:Buffer.concat(chunks).toString()}));
  });
  r.setTimeout(20000,()=>r.destroy(Object.assign(Error('Request timeout'),{code:'LOCAL_HTTP_TIMEOUT'})));
  r.on('error',reject);r.end(body);
 });
}
const report={startedAt:new Date().toISOString(),source:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
 scope:'Local HTTP + actual API handler + actual PostgreSQL RPCs; mocked identity and APNs; no flight calls; not hosted capacity certification',
 machine:{platform:platform(),arch:arch(),cpus:cpus().length,cpu:cpus()[0].model,totalMemoryGB:totalmem()/2**30,freeMemoryGB:freemem()/2**30},
 configuration:{friendCount,planCount,prewarmedHTTPConnections:args.quick?40:1000,poolSize:20,sqlTimeoutMs:6500,poolWaitTimeoutMs:6500,httpTimeoutMs:20000,authSimulatedLatencyMs:25,postgresSharedBuffersMB:128},stages};
let admin,pool,server,base,accounts,tokens=new Map(),handler,database,monitor;
const loop=monitorEventLoopDelay({resolution:20});loop.enable();
const samples=[];
function progress(text){console.log(JSON.stringify({at:new Date().toISOString(),progress:text}));}
function summarise(rows){
 return {requests:rows.length,errors:rows.filter(r=>!r.ok).length,statuses:rows.reduce((a,r)=>(a[r.status]=(a[r.status]??0)+1,a),{}),
 transportErrors:rows.filter(r=>r.status===0).reduce((a,r)=>(a[r.error]=(a[r.error]??0)+1,a),{}),latencyMs:timing(rows.map(r=>r.ms)),responseBytes:timing(rows.map(r=>r.bytes)),validationFailures:rows.filter(r=>!r.valid).length};
}
async function request(actor,method,path,body,validate=()=>true){
 const start=performance.now();let status=0,bytes=0,valid=false,error;
 try{
  const res=await localHTTP(path,{method,headers:{Authorization:'Bearer '+actor.token,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
  status=res.status;const text=res.text;bytes=Buffer.byteLength(text);const json=JSON.parse(text);
  valid=validate(json,status);if(status>=400)error=json.message;
 }catch(e){error=e.code??e.cause?.code??e.name;}
 const result={path,method,status,bytes,valid,ok:status>=200&&status<300&&valid,ms:performance.now()-start,...(error?{error}:{} )};
 requestMetrics.push(result);return result;
}
async function stage(name,users,workload){
 const reqStart=requestMetrics.length,rpcStart=rpcMetrics.length,sampleStart=samples.length,start=performance.now();
 progress(`Starting ${name} (${users} virtual users)`);
 await workload();
 // Keep later stages from inheriting a connection backlog after HTTP timeouts.
 for(let i=0;i<100 && (pool.waitingCount||pool.idleCount<pool.totalCount);i++)await sleep(100);
 const elapsedMs=performance.now()-start,rows=requestMetrics.slice(reqStart),sql=rpcMetrics.slice(rpcStart);
 const paths=[...new Set(rows.map(r=>r.path))];
 const summary={name,users,elapsedMs:Number(elapsedMs.toFixed(2)),...summarise(rows),completedRequestsPerSecond:rows.length/(elapsedMs/1000),
  endpoints:Object.fromEntries(paths.length<10?paths.map(path=>[path,summarise(rows.filter(r=>r.path===path))]):[]),
  rpc:Object.fromEntries([...new Set(sql.map(r=>r.name))].map(name=>{const r=sql.filter(x=>x.name===name);return [name,{calls:r.length,errors:r.filter(x=>!x.ok).length,poolWaitMs:timing(r.map(x=>x.waitMs)),executionMs:timing(r.map(x=>x.sqlMs)),codes:[...new Set(r.map(x=>x.code).filter(Boolean))]}];})),
  peakPoolWaiters:Math.max(0,...samples.slice(sampleStart).map(x=>x.waiting)),peakRssMB:Math.max(0,...samples.slice(sampleStart).map(x=>x.rssMB))};
 stages.push(summary);await writeFile(join(output,'results.json'),JSON.stringify(report,null,2));
 progress(`${name}: ${summary.requests} requests, ${summary.errors} errors, p95 ${summary.latencyMs.p95}ms`);
 return summary;
}
try{
 progress('Initializing isolated PostgreSQL');await cluster.initialise();await cluster.start();
 admin=cluster.getPgClient('postgres','127.0.0.1');await admin.connect();
 report.postgres=(await admin.query('select version() as v')).rows[0].v;
 await admin.query('create schema auth;create table auth.users(id uuid primary key,email text);create role anon;create role authenticated;create role service_role;');
 for(const file of (await readdir(join(root,'supabase/migrations'))).filter(f=>f.endsWith('.sql')).sort())await admin.query(await readFile(join(root,'supabase/migrations',file),'utf8'));
 progress('Seeding 1,000 synthetic accounts and their social/travel data');
 let seed=await readFile(new URL('./seed.sql',import.meta.url),'utf8');
 if(args.dense)seed=seed.replace('generate_series(1,10) d','generate_series(1,50) d').replace('generate_series(0,2) p;','generate_series(0,9) p;');
 await admin.query(seed);
 accounts=(await admin.query('select * from load_accounts order by n')).rows.map(a=>({...a,token:randomUUID()}));
 for(const a of accounts)tokens.set(a.token,a.auth_id);
 report.dataset=(await admin.query(`select jsonb_build_object('users',(select count(*) from app_users),'friendships',(select count(*) from friendships),'plans',(select count(*) from travel_plans),'audienceRows',(select count(*) from travel_plan_audience),'trips',(select count(*) from trips),'flights',(select count(*) from flights),'events',(select count(*) from colocation_events)) as counts`)).rows[0].counts;
 pool=new Pool({host:'127.0.0.1',port,user:'postgres',password:secret,database:'postgres',max:20,connectionTimeoutMillis:6500,
  options:'-c role=service_role -c statement_timeout=6500'});
 ({handler,database}=await createHarness(pool,tokens,rpcMetrics));
 server=createServer(async(req,res)=>{
  try{
   if(req.url==='/__load_ready'){await sleep(2500);res.writeHead(200);res.end('{}');return;}
   const chunks=[];for await(const chunk of req)chunks.push(chunk);
   const data=Buffer.concat(chunks);if(data.length>16384)throw Error('Load body too large');
   const result=await handler(new Request(base+req.url,{method:req.method,headers:req.headers,...(data.length?{body:data}: {})}));
   res.writeHead(result.status,Object.fromEntries(result.headers));res.end(await result.text());
  }catch{res.writeHead(500);res.end('{"message":"Local harness failure"}');}
 });
 server.keepAliveTimeout=180000;server.headersTimeout=185000;
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));base=`http://127.0.0.1:${server.address().port}`;
 progress('Prewarming local HTTP connections to exclude TCP accept-backlog artifacts');
 const warmConnections=[];for(let i=0;i<(args.quick?40:1000);i++){warmConnections.push(localHTTP('/__load_ready'));if(i%25===24)await sleep(35);}
 const ready=await Promise.all(warmConnections);if(ready.some(r=>r.status!==200))throw Error('HTTP connection warmup failed');
 monitor=setInterval(()=>samples.push({waiting:pool.waitingCount,connections:pool.totalCount,rssMB:process.memoryUsage().rss/2**20}),100);
 if(!args['notifications-only']) {
 const warmup=await stage('warmup',10,()=>Promise.all(accounts.slice(0,10).map(a=>request(a,'GET','/v1/bootstrap',null,j=>j.currentUser?.id===a.id&&j.friends?.length===friendCount))));
 if(warmup.errors)throw Error('Warmup validation failed; no load stages run');
 const levels=args.quick?[10]:[100,500,1000];
 for(const n of levels){
  const fresh=Array.from({length:n},()=>({auth_id:randomUUID(),token:randomUUID()}));
  for(const a of fresh){tokens.set(a.token,a.auth_id);await admin.query('insert into auth.users(id,email) values($1,$2)',[a.auth_id,'synthetic@example.invalid']);}
  await stage('bootstrap_burst_'+n,n,()=>Promise.all(fresh.map(a=>request(a,'POST','/v1/auth/bootstrap',{displayName:'Load New User'},j=>j.isAuthenticated===true&&!!j.currentUser?.id))));
 }
 for(const n of levels){
  await stage('refresh_burst_'+n,n,()=>Promise.all(accounts.slice(0,n).map(async a=>{
   await request(a,'GET','/v1/bootstrap',null,j=>j.currentUser?.id===a.id&&j.friends?.length===friendCount);
   await request(a,'GET','/v1/travel-plans',null,j=>j.plans?.length===planCount&&j.friendPlans?.length===friendCount*planCount);
   await request(a,'GET','/v1/trips',null,j=>j.trips?.length===3);
  })));
 }
 if(!args.quick)await stage('steady_refresh_1000_over_60s',1000,()=>Promise.all(accounts.map(async(a,i)=>{
  await sleep(i*60);await request(a,'GET','/v1/bootstrap',null,j=>j.currentUser?.id===a.id);
  await request(a,'GET','/v1/travel-plans',null,j=>j.plans?.length===planCount&&j.friendPlans?.length===friendCount*planCount);
 })));
 // Same-identity initialization must not create multiple profiles under concurrent requests.
 const repeat={auth_id:randomUUID(),token:randomUUID()};tokens.set(repeat.token,repeat.auth_id);
 await admin.query('insert into auth.users(id) values($1)',[repeat.auth_id]);
 await stage('same_account_bootstrap_race',32,()=>Promise.all(Array.from({length:32},()=>request(repeat,'POST','/v1/auth/bootstrap',{displayName:'Same Load User'},j=>j.isAuthenticated===true))));
 report.duplicateProfiles=Number((await admin.query('select count(*) from app_users where auth_user_id=$1',[repeat.auth_id])).rows[0].count);
 report.bootstrapSQLRace={rounds:20,concurrency:20,errors:[],profileCounts:[]};
 for(let trial=0;trial<20;trial++){
  const auth=randomUUID();await admin.query('insert into auth.users(id) values($1)',[auth]);
  const results=await Promise.all(Array.from({length:20},()=>database.rpc('wif_ensure_app_user',{p_auth_user_id:auth,p_display_name:'Concurrent User'})));
  report.bootstrapSQLRace.errors.push(...results.filter(r=>r.error).map(r=>({code:r.error.code,message:r.error.message})));
  report.bootstrapSQLRace.profileCounts.push(Number((await admin.query('select count(*) from app_users where auth_user_id=$1',[auth])).rows[0].count));
 }
 // Candidate remedy is applied ONLY to this temporary cluster, never the repository migrations or production.
 const originalBootstrap=(await admin.query("select pg_get_functiondef('public.wif_ensure_app_user(uuid,text)'::regprocedure) as sql")).rows[0].sql;
 const lockPoint='    select id into v_user_id';
 if(!originalBootstrap.includes(lockPoint))throw Error('Bootstrap experiment source changed');
 const candidateBootstrap=originalBootstrap.replace(lockPoint,"    perform pg_advisory_xact_lock(hashtextextended('wif:bootstrap:'||p_auth_user_id::text,0));\n"+lockPoint);
 await writeFile(join(output,'bootstrap-lock-candidate.sql'),candidateBootstrap);
 await admin.query(candidateBootstrap);
 report.bootstrapSQLRaceAfterLocalLock={rounds:20,concurrency:20,errors:[],profileCounts:[]};
 for(let trial=0;trial<20;trial++){
  const auth=randomUUID();await admin.query('insert into auth.users(id) values($1)',[auth]);
  const results=await Promise.all(Array.from({length:20},()=>database.rpc('wif_ensure_app_user',{p_auth_user_id:auth,p_display_name:'Concurrent User'})));
  report.bootstrapSQLRaceAfterLocalLock.errors.push(...results.filter(r=>r.error).map(r=>({code:r.error.code,message:r.error.message})));
  report.bootstrapSQLRaceAfterLocalLock.profileCounts.push(Number((await admin.query('select count(*) from app_users where auth_user_id=$1',[auth])).rows[0].count));
 }
 await admin.query(originalBootstrap);
 // Two writes with the same revision: exactly one succeeds, others are explicit conflicts.
 const plan=(await admin.query('select * from travel_plans where owner_id=$1 order by start_day limit 1',[accounts[0].id])).rows[0];
 const audience=(await admin.query('select friend_id from travel_plan_audience where plan_id=$1',[plan.id])).rows.map(r=>r.friend_id);
 const day=d=>new Date(d).toISOString().slice(0,10);
 const writeBody={city:plan.city,countryCode:plan.country_code,region:plan.region,timeZone:plan.time_zone,startDay:day(plan.start_day),endDay:day(plan.end_day),audience,alertsEnabled:false,revision:plan.revision,allowFriendBrowsing:true};
 const collision=await stage('same_plan_revision_race',16,()=>Promise.all(Array.from({length:16},()=>request(accounts[0],'PUT','/v1/travel-plans/'+plan.id,writeBody,(_,status)=>[200,409].includes(status)))));
 collision.expectedConflicts=15;collision.correct=collision.statuses[200]===1&&collision.statuses[409]===15;
 report.explains={};
 for(const name of ['wif_snapshot','wif_travel_snapshot','wif_trip_list']){
  const result=await admin.query(`explain (analyze,buffers,format json) select public.${name}($1)`,[accounts[1].id]);report.explains[name]=result.rows[0]['QUERY PLAN'];
 }
 }
 if(!args.quick){
  progress('Testing 1,000 real SQL notification records with a simulated APNs sink');
  await admin.query(`insert into trips(id,name,start_date,end_date,destination_airport) select 'notify-'||g,'Load notification trip',(current_date+7)::text,(current_date+10)::text,'LAX' from generate_series(0,199) g;
   insert into trip_members(trip_id,user_id,role) select 'notify-'||((n-1)/5),id,case when (n-1)%5=0 then 'owner' else 'member' end from load_accounts;
   insert into participants(trip_id,user_id,name) select m.trip_id,m.user_id,'Load person' from trip_members m where m.trip_id like 'notify-%';
   analyze;`);
  const scheduling=[];
  for(let n=0;n<3;n++){const start=performance.now();const r=await admin.query("select wif_trip_schedule_booking((current_date::text||'T09:15:00Z')::timestamptz) as count");scheduling.push({count:r.rows[0].count,ms:performance.now()-start});}
  report.morningScheduling={syntheticLocalTime:'09:15 UTC',runs:scheduling,total:scheduling.reduce((n,r)=>n+r.count,0)};
  if(scheduling.map(r=>r.count).join(',')!=='500,500,0')throw Error('Morning batch cap or deduplication failed');
  await admin.query("delete from trip_booking_reminders where trip_id like 'notify-%' and kind='daily'");
  await admin.query(`insert into trip_booking_reminders(trip_id,recipient_id,sender_id,kind,scheduled_day,expires_at)
    select 'notify-'||((a.n-1)/5),a.id,b.id,'manual',current_date,now()+interval '1 day' from load_accounts a join load_accounts b on b.n=((a.n-1)/5)*5+((a.n-1)%5+1)%5+1;
   analyze;`);
  const sent=new Set();let duplicateSends=0,active=0,peak=0,pushHandler;
  class JWT{setProtectedHeader(){return this;}setIssuer(){return this;}setIssuedAt(){return this;}async sign(){return 'synthetic';}}
  const source=(await readFile(join(root,'supabase/functions/push-worker/index.ts'),'utf8')).replace(/^import .*;\n/gm,'');
  vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),{
   Request,Response,URL,console:{log:()=>{},warn:()=>{}},crypto,AbortSignal,Date,
   deliveryGate,drainQueues,workerFetch,settleBatch,deliverUpcoming,normalizeAPNsPrivateKey,deliverFriendInvitations,deliverTripInvitations,deliverTripBookingReminders,classifyAPNsResponse,
   createClient:()=>database,importPKCS8:async()=>({}),SignJWT:JWT,decryptAPNSToken:async()=> 'local-synthetic-token',
   fetch:async(url,options)=>{if(!url.startsWith('https://api.sandbox.push.apple.com/'))throw Error('Only synthetic sandbox targets allowed');active++;peak=Math.max(peak,active);await sleep(50);active--;
    const event=JSON.parse(options.body).eventID;if(sent.has(event))duplicateSends++;sent.add(event);return new Response('{}',{status:200});},
   Deno:{env:{get:name=>name==='SUPABASE_URL'?'http://127.0.0.1':'synthetic-test-only'},serve:fn=>pushHandler=fn},
  });
  const runs=[];
  for(let i=0;i<10;i++){
   const start=performance.now();const response=await pushHandler(new Request('http://127.0.0.1/worker',{method:'POST',headers:{Authorization:'Bearer synthetic-test-only'},body:'{"action":"trip-reminders"}'}));
   const body=await response.json();runs.push({status:response.status,ms:performance.now()-start,body});
   progress(`Notification batch ${i+1}: ${body.delivered??0} simulated deliveries`);
   if(sent.size>=1000||!(body.delivered>0))break;
  }
  report.notifications={runs,uniqueDelivered:sent.size,duplicateSends,peakSimulatedAPNsConcurrency:peak,sinkLatencyMs:50,
   state:(await admin.query('select status,count(*)::int from trip_booking_deliveries group by status')).rows,
   note:'Runs invoked back-to-back locally. Production cron waits one minute between scheduled runs; APNs latency/signing/decryption are simulated.'};
 }
 report.finishedAt=new Date().toISOString();report.eventLoopDelayMs={p95:loop.percentile(95)/1e6,max:loop.max/1e6};
 report.finalDatabase=(await admin.query('select numbackends,deadlocks,temp_bytes from pg_stat_database where datname=current_database()')).rows[0];
 await writeFile(join(output,'results.json'),JSON.stringify(report,null,2));
 await writeFile(join(output,'requests.json'),JSON.stringify(requestMetrics));
 await writeFile(join(output,'rpc-metrics.json'),JSON.stringify(rpcMetrics));
 progress('Complete: '+output);
}catch(error){
 report.fatal={name:error.name,code:error.code,message:error.message};await writeFile(join(output,'results.json'),JSON.stringify(report,null,2));throw error;
}finally{
 clearInterval(monitor);loop.disable();httpAgent.destroy();if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
 await pool?.end();await admin?.end();await cluster.stop();
 progress('Temporary database stopped; synthetic files retained at '+work);
}

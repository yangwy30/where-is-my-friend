import test from 'node:test';
import assert from 'node:assert/strict';
import {validateTarget,verifyProject,validatePrivateSession,assertMarker,validateLoadStages,shouldStop,requestJSON,protectedProjects,assertEmptyUnmarkedProject} from '../../scripts/staging/target.mjs';
const target={environment:'isolated-staging',projectName:'across-us-isolated-staging',projectRef:'abcdefghijklmnopqrst',organizationID:'isolated-test-org',region:'us-east-2'};
test('cloud tests refuse every known existing project before making requests',()=>{
 for(const projectRef of protectedProjects)assert.throws(()=>validateTarget({...target,projectRef}),/forbidden/);
 for(const projectRef of ['','../../live','https://example.com','abcdefghijklmnopqrst.evil'])assert.throws(()=>validateTarget({...target,projectRef}));
 assert.equal(validateTarget(target).origin,'https://abcdefghijklmnopqrst.supabase.co');
 assert.throws(()=>validateTarget({...target,environment:'production'}));
});
test('project identity and environment marker must match before test writes',()=>{
 const conf=validateTarget(target),project={ref:target.projectRef,name:target.projectName,organization_id:target.organizationID,region:'us-east-2',status:'ACTIVE_HEALTHY'};
 assert.equal(verifyProject(conf,[project]),project);
 for(const change of [{name:'production'},{region:'us-west-2'},{organization_id:'other'},{status:'INACTIVE'}])assert.throws(()=>verifyProject(conf,[{...project,...change}]));
 const marker={project_ref:target.projectRef,environment:'isolated-staging',real_push_enabled:false,flight_provider_enabled:false};assertMarker(marker,conf);
 for(const change of [{project_ref:'other'},{real_push_enabled:true},{flight_provider_enabled:true}])assert.throws(()=>assertMarker({...marker,...change},conf));
});
test('test tokens are scoped to the test issuer and bounded load stops on rate limits or errors',()=>{
 const conf=validateTarget(target),authID='00000000-0000-0000-0000-000000000001';
 const account=claims=>({authID,appID:authID,token:'header.'+Buffer.from(JSON.stringify({iss:conf.origin+'/auth/v1',sub:authID,role:'authenticated',exp:Date.now()/1000+3600,...claims})).toString('base64url')+'.signature'});
 const second=account({sub:'00000000-0000-0000-0000-000000000002'});second.authID='00000000-0000-0000-0000-000000000002';second.appID=second.authID;
 const session={projectRef:conf.projectRef,accounts:[account({}),second]};validatePrivateSession(session,conf);
 for(const claims of [{iss:'https://cdhpaujazbuppbxyhjxq.supabase.co/auth/v1'},{role:'service_role'},{exp:0},{exp:null},{exp:'9999999999'},{exp:undefined},{sub:'other'}])assert.throws(()=>validatePrivateSession({...session,accounts:[account(claims),second]},conf));
 assert.deepEqual(validateLoadStages([1,5,10,20]),[1,5,10,20]);for(const v of [[1000],[5,1],[1,1],[-1]])assert.throws(()=>validateLoadStages(v));
 assert.equal(shouldStop([{ok:true,status:200}]),false);for(const status of [401,403,429,500])assert.equal(shouldStop([{ok:false,status}]),true);
});
test('hosted HTTP requests reject redirects rather than forwarding credentials',async()=>{
 let options;await requestJSON('https://test.invalid',{fetcher:async(_,o)=>{options=o;return new Response('{}',{status:200});}});
 assert.equal(options.redirect,'error');
});

test('hosted runner verifies each actor response and stops at the first failed tier',async()=>{
 const {runStages}=await import('../../scripts/staging/run.mjs');
 const conf=validateTarget(target);
 const accounts=[1,2].map(n=>{const id=`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;return {authID:id,appID:id,token:'h.'+Buffer.from(JSON.stringify({iss:conf.origin+'/auth/v1',role:'authenticated',sub:id,exp:Date.now()/1000+3600})).toString('base64url')+'.s'};});
 const session={projectRef:conf.projectRef,accounts,anon:'synthetic-public-key',expected:{friends:1,friendPlans:3,overlaps:3,trips:1}};
 let requests=0;
 const fetcher=async(url,options)=>{
  assert.equal(new URL(url).origin,conf.origin);assert.equal(options.redirect,'error');requests++;
  const id=JSON.parse(Buffer.from(options.headers.Authorization.split('.')[1],'base64url')).sub;
  const data=url.endsWith('/auth/bootstrap')?{currentUser:{id},friends:[{}]}:url.endsWith('/travel-plans')?{overlaps:[{},{},{}],overlapCount:3,friendPlanSummaries:[{count:3}]}:url.endsWith('/friend-plans')?{items:[{},{},{}]}:{trips:[{}]};
  return new Response(JSON.stringify(data),{status:200});
 };
 const good=await runStages(conf,session,{levels:[1,2],pauseMs:0,fetcher});
 assert.equal(good.stoppedEarly,false);assert.equal(requests,36);assert.deepEqual(good.stages.map(x=>x.users),[1,2]);
 requests=0;const burst=await runStages(conf,session,{levels:[1,2],lanes:2,pauseMs:0,fetcher});
 assert.equal(requests,72);assert.equal(burst.stages.at(-1).users,2);assert.equal(burst.stages.at(-1).parallelJourneysPerAccount,2);assert.ok(burst.stages.at(-1).peakInFlight<=4);
 await assert.rejects(runStages(conf,session,{levels:[1,2],lanes:6,pauseMs:0,fetcher}),/1–5/);
 await runStages(conf,session,{levels:[1],edgeRegion:'us-east-1',pauseMs:0,fetcher:async(url,options)=>{assert.equal(options.headers['x-region'],'us-east-1');return fetcher(url,options);}});
 await assert.rejects(runStages(conf,session,{levels:[1],edgeRegion:'arbitrary',pauseMs:0,fetcher}),/Unsupported comparison region/);
 let failedRequests=0;
 const bad=await runStages(conf,session,{levels:[1,2],pauseMs:0,fetcher:async()=>{failedRequests++;return new Response('{}',{status:429});}});
 assert.equal(bad.stoppedEarly,true);assert.equal(bad.stages.length,1);assert.equal(failedRequests,1);
 const wrong=await runStages(conf,session,{levels:[1,2],pauseMs:0,fetcher:async()=>new Response(JSON.stringify({currentUser:{id:'another-user'},friends:[{}]}),{status:200})});
 assert.equal(wrong.stoppedEarly,true);assert.equal(wrong.stages.length,1);
});

test('hosted migration wrapper and fixture rehearse on a fresh database',async()=>{
 const {PGlite}=await import('@electric-sql/pglite');const {readFile,readdir}=await import('node:fs/promises');const {migrationSQL,seedSQL}=await import('../../scripts/staging/fixtures.mjs');
 const db=new PGlite();try{
  await db.exec('create schema auth;create table auth.users(id uuid primary key,email text);create role anon;create role authenticated;create role service_role;create schema supabase_migrations;create table supabase_migrations.schema_migrations(version text primary key,statements text[],name text)');
  const files=(await readdir(new URL('../migrations/',import.meta.url))).filter(x=>x.endsWith('.sql')).sort();
  for(const file of files)await db.exec(migrationSQL(file,await readFile(new URL('../migrations/'+file,import.meta.url),'utf8')));
  assert.equal((await db.query('select count(*)::integer n from supabase_migrations.schema_migrations')).rows[0].n,files.length);
  const accounts=[];
  for(let n=1;n<=5;n++){
   const authID=`${String(n).padStart(8,'0')}-1111-1111-1111-111111111111`;await db.query('insert into auth.users values($1,$2)',[authID,`synthetic-${n}@example.invalid`]);
   const appID=(await db.query('select wif_ensure_app_user($1,$2) id',[authID,'Staging user '+n])).rows[0].id;accounts.push({authID,appID});
  }
  const sql=seedSQL({runID:'00000000-0000-0000-0000-000000000001',accounts});await db.exec(sql);
  const overview=(await db.query('select wif_travel_overview($1) v',[accounts[0].appID])).rows[0].v;
  assert.equal(overview.overlapCount,12);assert.equal(overview.overlaps.length,3);assert.equal(overview.friendPlanSummaries.reduce((n,x)=>n+x.count,0),12);
  const trips=(await db.query('select wif_trip_list($1) v',[accounts[0].appID])).rows[0].v;assert.equal(trips.length,1);
  assert.equal((await db.query('select count(*)::integer n from devices')).rows[0].n,0);
  await assert.rejects(db.exec(sql),/empty test dataset/);
 }finally{await db.close();}
});

test('initialization refuses unrelated public tables even when no App profile exists',()=>{
 assertEmptyUnmarkedProject({marked:false,public_table_count:0,auth_count:0});
 for(const state of [{marked:false,public_table_count:1,auth_count:0},{marked:false,public_table_count:0,auth_count:1},{}])assert.throws(()=>assertEmptyUnmarkedProject(state),/empty project/);
});

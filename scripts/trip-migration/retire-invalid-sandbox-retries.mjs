// Narrow repair for long-running, already-failed sandbox environment retries.
// Retains delivery records and devices. Uses existing completion RPC semantics.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {randomUUID} from 'node:crypto';
import {mkdtemp,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
const cli=resolve('node_modules/.bin/supabase'),project='cdhpaujazbuppbxyhjxq';
const query=async sql=>JSON.parse((await promisify(execFile)(cli,['db','query','--linked','--project-ref',project,'--output','json',sql],{timeout:45000})).stdout).rows;
const condition="nd.status='pending' and nd.claim_token is null and nd.attempts>=8 and nd.last_error='APNs 403: BadEnvironmentKeyInToken' and d.environment='sandbox'";
const rows=await query(`select nd.* from notification_deliveries nd join devices d on d.id=nd.device_id where ${condition} order by nd.id`);
if(rows.length>50)throw new Error('Unexpected scope; review before repair');
for(const row of rows)if(!/^[a-f0-9-]{36}$/i.test(row.id)||!Number.isInteger(row.attempts))throw new Error('Unexpected row format');
const directory=await mkdtemp(resolve('.migration-backups/sandbox-retry-repair-'));
await writeFile(join(directory,'before.json'),JSON.stringify(rows,null,2),{mode:0o600,flag:'wx'});
if(!process.argv.includes('--apply')){console.log(JSON.stringify({directory,candidates:rows.length,applied:false}));process.exit(0);}
if(!rows.length){console.log(JSON.stringify({directory,candidates:0,applied:false}));process.exit(0);}
const token=randomUUID(),targets=rows.map(r=>`(nd.id='${r.id}' and nd.attempts=${r.attempts})`).join(' or ');
const result=await query(`begin; set local lock_timeout='3s'; set local statement_timeout='20s';
create temporary table repaired_deliveries(id uuid) on commit drop;
do $$ declare item record; begin
 for item in select nd.id,nd.last_error from notification_deliveries nd join devices d on d.id=nd.device_id
 where ${condition} and (${targets}) for update of nd skip locked loop
  update notification_deliveries set claim_token='${token}',claimed_at=now() where id=item.id;
  if wif_complete_notification_delivery(item.id,'${token}','failed',item.last_error,null,null,false)
  then insert into repaired_deliveries values(item.id); end if;
 end loop;
end $$;
select count(*) as repaired from repaired_deliveries;
commit;
select count(*) as remaining_unclaimed from notification_deliveries nd join devices d on d.id=nd.device_id where ${condition};`);
await writeFile(join(directory,'result.json'),JSON.stringify(result,null,2),{mode:0o600});
console.log(JSON.stringify({directory,candidates:rows.length,applied:true,result}));

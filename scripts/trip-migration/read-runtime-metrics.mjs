// One read-only scrape; never display the API key or SQL/query labels.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve} from 'node:path';
const {stdout}=await promisify(execFile)(resolve('node_modules/.bin/supabase'),['projects','api-keys','--project-ref','cdhpaujazbuppbxyhjxq','--reveal','--output','json'],{timeout:60000});
const keys=JSON.parse(stdout),key=keys.find(k=>k.api_key?.startsWith('sb_secret_'))?.api_key??keys.find(k=>k.name==='service_role')?.api_key;
if(!key)throw new Error('Existing metrics credential unavailable');
const response=await fetch('https://cdhpaujazbuppbxyhjxq.supabase.co/customer/v1/privileged/metrics',{
 headers:{Authorization:'Basic '+Buffer.from('service_role:'+key).toString('base64')},signal:AbortSignal.timeout(30000)});
if(!response.ok){console.log(JSON.stringify({status:response.status}));process.exit(1);}
const body=await response.text();
const metrics=body.split('\n').filter(l=>/^(pgrst_|node_load|node_cpu_seconds_total|node_memory_(MemTotal|MemAvailable|SwapTotal|SwapFree)|node_disk_io_time_seconds_total|node_filesystem_(avail|size)_bytes|pg_settings_max_connections|pg_up|pg_stat_database_deadlocks)/.test(l));
console.log(JSON.stringify({at:new Date().toISOString(),status:response.status,metrics,otherMetricNames:[...new Set(body.split('\n').filter(l=>/^[a-z]/.test(l)).map(l=>l.split(/[ {]/)[0]))].filter(n=>/pool|timeout|cpu|memory|load/.test(n))},null,2));

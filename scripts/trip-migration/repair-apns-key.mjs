// Repair a malformed secret only when the existing key ID matches this local
// Apple-issued key. Never print credentials or replace a different key identity.
import {readFile,writeFile,mkdtemp,unlink} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createHash,createPrivateKey} from 'node:crypto';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
const project='cdhpaujazbuppbxyhjxq',keyID='6T7D9UR8K6';
const pem=await readFile(`/Users/wangyang/Desktop/AuthKey_${keyID}_Staging.p8`,'utf8');
const key=createPrivateKey(pem);
if(key.asymmetricKeyType!=='ec'||key.asymmetricKeyDetails.namedCurve!=='prime256v1')throw new Error('Not an APNs P-256 key');
const run=promisify(execFile),cli=resolve('node_modules/.bin/supabase');
const list=JSON.parse((await run(cli,['secrets','list','--project-ref',project,'--output','json'])).stdout);
const digest=value=>createHash('sha256').update(value).digest('hex');
if(list.find(x=>x.name==='APNS_KEY_ID')?.value!==digest(keyID))throw new Error('Existing key ID does not match; no changes made');
if(!process.argv.includes('--apply')) { console.log('Local APNs key validated and key ID matches; no changes made.'); }
else {
 const directory=await mkdtemp(join(tmpdir(),'wif-apns-repair-')),file=join(directory,'secrets.env');
 try {
  await writeFile(file,`APNS_PRIVATE_KEY=${JSON.stringify(pem.trim())}\n`,{flag:'wx',mode:0o600});
  await run(cli,['secrets','set','--project-ref',project,'--env-file',file],{timeout:60000});
  console.log('Existing APNs private key format repaired; key ID, team ID and encryption key unchanged.');
 } catch { console.error('Secret update not confirmed; inspect the protected signing health check.');process.exitCode=1; }
 finally { await unlink(file); }
}

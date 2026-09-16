// Explicit, single-secret migration to the App project. No Auth/APNs/old-project changes.
import {readFile,writeFile,mkdtemp,unlink,rmdir} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve} from 'node:path';
let directory, file;
try {
    const env=await readFile('/Users/wangyang/.gemini/antigravity/scratch/tripflights/.env','utf8');
    const raw=env.match(/^\s*VITE_RAPIDAPI_KEY\s*=\s*(.+)$/m)?.[1]?.trim();
    const key=raw?.replace(/^(['"])(.*)\1$/,'$2');
    if(!key||!/^[A-Za-z0-9_-]{20,200}$/.test(key)) throw new Error('Invalid key');
    directory=await mkdtemp('/private/tmp/wif-flight-secret-');
    file=resolve(directory,'provider.env');
    await writeFile(file,`RAPIDAPI_KEY=${key}\n`,{flag:'wx',mode:0o600});
    await promisify(execFile)(resolve('node_modules/.bin/supabase'),['secrets','set','--project-ref','cdhpaujazbuppbxyhjxq','--env-file',file],{timeout:60000});
    console.log('Configured RAPIDAPI_KEY in the App project; no other secrets changed.');
} catch {console.error('Flight-provider configuration failed. Credential values not logged.');process.exitCode=1;}
finally {
    if(file) await unlink(file).catch(()=>{});
    if(directory) await rmdir(directory).catch(()=>{});
}

// One public-flight request. Existing credential stays in memory; never print request headers/body errors.
import {readFile} from 'node:fs/promises';
import {fetchFlightLookup,flightLookupInput} from '../../supabase/functions/_shared/flight-lookup.mjs';
try {
    const env=await readFile('/Users/wangyang/.gemini/antigravity/scratch/tripflights/.env','utf8');
    const raw=env.match(/^\s*VITE_RAPIDAPI_KEY\s*=\s*(.+)$/m)?.[1]?.trim();
    const key=raw?.replace(/^(['"])(.*)\1$/,'$2');
    if(!key) throw new Error('missing');
    let upstreamStatus=null;
    const result=await fetchFlightLookup(flightLookupInput('UA353',new Date().toISOString().slice(0,10)),key,async(url,options)=>{
        const response=await fetch(url,options);upstreamStatus=response.status;return response;
    }).catch(error=>({errorStatus:error.status??null,message:error.status?error.message:'Provider check failed.'}));
    console.log(JSON.stringify({upstreamStatus,...result},null,2));
} catch {console.error('Provider check could not run. No credentials logged.');process.exitCode=1;}

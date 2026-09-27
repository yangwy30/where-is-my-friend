import {writeFile} from 'node:fs/promises';
import {loadTarget} from './target.mjs';
import {assertIsolation,keys} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');await assertIsolation(target);
const {anon}=await keys(target);
// $() keeps xcconfig from treating the second slash as a comment.
const origin=`https:/$()/${target.projectRef}.supabase.co`;
await writeFile('Config/Staging.local.xcconfig',`// Generated for the dedicated isolated test project only.\nWIF_STAGING_API_BASE_URL = ${origin}/functions/v1/api\nWIF_STAGING_SUPABASE_URL = ${origin}\nWIF_STAGING_PUBLISHABLE_KEY = ${anon}\n`,{mode:0o600});
console.log(JSON.stringify({configured:true,projectRef:target.projectRef,releaseChanged:false}));

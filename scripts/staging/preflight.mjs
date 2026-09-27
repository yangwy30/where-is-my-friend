import {loadTarget} from './target.mjs';
import {assertIsolation} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');
await assertIsolation(target);
console.log(JSON.stringify({projectRef:target.projectRef,region:target.region,isolated:true,productionTouched:false}));

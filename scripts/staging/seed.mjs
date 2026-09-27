// Small first-pass hosted fixture. Nothing is copied from a live project.
import {readFile,writeFile} from 'node:fs/promises';
import {loadTarget,validatePrivateSession} from './target.mjs';
import {seedSQL} from './fixtures.mjs';
import {assertIsolation,query} from './management.mjs';
const target=await loadTarget(process.argv[2]??'.staging-private/target.json');await assertIsolation(target);
const file='.staging-private/sessions.json',session=validatePrivateSession(JSON.parse(await readFile(file,'utf8')),target);
await query(target,seedSQL(session));
session.expected={friends:session.accounts.length-1,friendPlans:(session.accounts.length-1)*3,overlaps:(session.accounts.length-1)*3,trips:1};
await writeFile(file,JSON.stringify(session,null,2),{mode:0o600});
console.log(JSON.stringify({seeded:true,accounts:session.accounts.length,plans:session.accounts.length*3,expectedPerActor:session.expected,devices:0,realNotifications:0}));

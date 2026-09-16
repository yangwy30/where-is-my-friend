// Private read-only pre-deployment snapshot. Never log row values or function bodies.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdir, mkdtemp, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
const project = 'cdhpaujazbuppbxyhjxq';
async function query(sql) {
    const { stdout } = await promisify(execFile)(resolve('node_modules/.bin/supabase'),
        ['db','query','--linked','--project-ref',project,'--output','json',sql],
        { maxBuffer: 64 * 1024 * 1024, timeout: 90000 });
    return JSON.parse(stdout).rows;
}
try {
    const names=(await query("select tablename from pg_tables where schemaname='public' order by tablename")).map(r=>r.tablename);
    if (names.some(n=>!/^[a-z_][a-z0-9_]*$/.test(n))) throw new Error('Unexpected table');
    const tables=names.map(n=>`'${n}',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.${n} t)`).join(',');
    const rows=await query(`select jsonb_build_object(
        'exported_at',transaction_timestamp(), 'data',jsonb_build_object(${tables}),
        'migrations',(select jsonb_agg(to_jsonb(m) order by version) from supabase_migrations.schema_migrations m),
        'columns',(select jsonb_agg(to_jsonb(c)) from information_schema.columns c where table_schema='public'),
        'constraints',(select jsonb_agg(jsonb_build_object('table',conrelid::regclass::text,'name',conname,'definition',pg_get_constraintdef(oid))) from pg_constraint where connamespace='public'::regnamespace),
        'functions',(select jsonb_agg(jsonb_build_object('signature',oid::regprocedure::text,'definition',pg_get_functiondef(oid),'acl',proacl)) from pg_proc where pronamespace='public'::regnamespace and prokind='f'),
        'policies',(select jsonb_agg(to_jsonb(p)) from pg_policies p where schemaname='public'),
        'indexes',(select jsonb_agg(to_jsonb(i)) from pg_indexes i where schemaname='public'),
        'grants',(select jsonb_agg(to_jsonb(g)) from information_schema.role_table_grants g where table_schema='public')
    ) as snapshot`);
    const snapshot=rows[0].snapshot;
    const payload=JSON.stringify(snapshot,null,2)+'\n';
    const parent=resolve('.migration-backups');
    await mkdir(parent,{recursive:true,mode:0o700});
    const directory=await mkdtemp(resolve(parent,'app-predeploy-'));
    await writeFile(resolve(directory,'snapshot.json'),payload,{flag:'wx',mode:0o600});
    const manifest={project,exportedAt:snapshot.exported_at,sha256:createHash('sha256').update(payload).digest('hex'),
        counts:Object.fromEntries(Object.entries(snapshot.data).map(([table,data])=>[table,data.length])),
        migrations:snapshot.migrations.map(m=>m.version),scope:'Public data/schema metadata and migration ledger; excludes Auth, Storage, secrets and hosted code. Not a full DR backup.'};
    await writeFile(resolve(directory,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx',mode:0o600});
    console.log(JSON.stringify({directory,...manifest},null,2));
} catch {
    console.error('Destination backup failed. No remote writes performed; raw data not logged.');
    process.exitCode=1;
}

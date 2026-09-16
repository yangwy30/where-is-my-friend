// Read-only, single-statement snapshot. Never print trip records, PINs, or subscriptions.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve } from "node:path";

const project = process.argv[2];
if (!/^[a-z]{20}$/.test(project ?? "")) {
    console.error("Usage: node scripts/trip-migration/export.mjs <source-project-ref>");
    process.exit(1);
}
const sql = `select jsonb_build_object(
    'formatVersion', 1, 'exportedAt', transaction_timestamp(),
    'trips', (select coalesce(jsonb_agg(to_jsonb(t) order by id), '[]'::jsonb) from public.trips t),
    'participants', (select coalesce(jsonb_agg(to_jsonb(t) order by id), '[]'::jsonb) from public.participants t),
    'flights', (select coalesce(jsonb_agg(to_jsonb(t) order by id), '[]'::jsonb) from public.flights t),
    'notes', (select coalesce(jsonb_agg(to_jsonb(t) order by id), '[]'::jsonb) from public.notes t),
    'push_subscriptions', (select coalesce(jsonb_agg(to_jsonb(t) order by id), '[]'::jsonb) from public.push_subscriptions t),
    'columns', (select jsonb_agg(to_jsonb(c)) from information_schema.columns c where table_schema='public'),
    'constraints', (select jsonb_agg(jsonb_build_object('table',conrelid::regclass::text,'name',conname,'definition',pg_get_constraintdef(oid))) from pg_constraint where connamespace='public'::regnamespace),
    'policies', (select jsonb_agg(to_jsonb(p)) from pg_policies p where schemaname='public')
) as snapshot`;

try {
    const { stdout } = await promisify(execFile)(resolve("node_modules/.bin/supabase"),
        ["db", "query", "--linked", "--project-ref", project, "--output", "json", sql],
        { maxBuffer: 32 * 1024 * 1024, timeout: 90_000 });
    const response = JSON.parse(stdout);
    const snapshot = response.rows?.[0]?.snapshot;
    if (!snapshot || snapshot.formatVersion !== 1) throw new Error("Unexpected export format");
    snapshot.sourceProject = project;
    const payload = JSON.stringify(snapshot, null, 2) + "\n";
    const sha256 = createHash("sha256").update(payload).digest("hex");
    const parent = resolve(".migration-backups");
    await mkdir(parent, { recursive: true, mode: 0o700 });
    const directory = await mkdtemp(resolve(parent, "tripflights-"));
    await writeFile(resolve(directory, "snapshot.json"), payload, { flag: "wx", mode: 0o600 });
    const counts = Object.fromEntries(["trips", "participants", "flights", "notes", "push_subscriptions"]
        .map(table => [table, snapshot[table].length]));
    const manifest = { sourceProject: project, exportedAt: snapshot.exportedAt, sha256, counts,
        scope: "TripFlights public data only; not a full project/disaster-recovery backup" };
    await writeFile(resolve(directory, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n", { flag: "wx", mode: 0o600 });
    console.log(JSON.stringify({ directory, ...manifest }, null, 2));
} catch {
    // Child-process errors can contain stdout with sensitive data. Do not log them.
    console.error("Read-only export failed. No database changes were made; no raw records were logged.");
    process.exitCode = 1;
}

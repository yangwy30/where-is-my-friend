// Imports into ephemeral local PGlite only. No network or remote write capability.
import { readFile, readdir, writeFile } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { createHash } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import { PGlite } from "@electric-sql/pglite";
import { importIntoLocalDatabase, transformSnapshot } from "./transform.mjs";

const path = process.argv[2];
if (!path) { console.error("Usage: node scripts/trip-migration/rehearse.mjs <private-snapshot.json>"); process.exit(1); }
const database = new PGlite();
try {
    const raw = await readFile(resolve(path), "utf8");
    const manifest = JSON.parse(await readFile(resolve(dirname(path), "manifest.json"), "utf8"));
    if (manifest.sha256 !== createHash("sha256").update(raw).digest("hex")) throw new Error("Checksum mismatch");
    const snapshot = JSON.parse(raw);
    await database.exec("create schema auth; create table auth.users(id uuid primary key,email text)");
    for (const file of (await readdir("supabase/migrations")).filter(f => f.endsWith(".sql")).sort()) {
        await database.exec(await readFile(resolve("supabase/migrations", file), "utf8"));
    }
    const report = await importIntoLocalDatabase(database, snapshot, raw);
    let fieldsVerified = 0;
    for (const [table, rows] of Object.entries(transformSnapshot(snapshot).rows)) {
        for (const expected of rows) {
            const actual = (await database.query(`select * from public.${table} where id=$1`, [expected.id])).rows[0];
            for (const [key, value] of Object.entries(expected)) {
                const matches = key.endsWith("_at") && value != null
                    ? new Date(actual[key]).getTime() === new Date(value).getTime()
                    : isDeepStrictEqual(actual[key], value);
                if (!matches) throw new Error("Field verification failed");
                fieldsVerified++;
            }
        }
    }
    for (const [table, count] of Object.entries(report.counts)) {
        const result = await database.query(`select count(*)::int as count from public.${table}`);
        if (result.rows[0].count !== count) throw new Error("Count mismatch");
    }
    const result = { sourceProject: snapshot.sourceProject, snapshotSHA256: manifest.sha256,
        verifiedAt: new Date().toISOString(), localOnly: true, fieldsVerified, ...report };
    await writeFile(resolve(dirname(path), `rehearsal-${Date.now()}.json`), JSON.stringify(result, null, 2) + "\n", { flag: "wx", mode: 0o600 });
    console.log(JSON.stringify(result, null, 2));
} catch {
    // Database errors may echo row values. Keep logs free of private itinerary content.
    console.error("Local rehearsal failed; no remote data was changed. Inspect the private snapshot and schema locally.");
    process.exitCode = 1;
} finally {
    await database.close();
}

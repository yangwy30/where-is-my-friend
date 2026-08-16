import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

test("hosted API requires Supabase user JWTs and contains no debug login", async () => {
    const config = await readFile(new URL("../config.toml", import.meta.url), "utf8");
    const api = await readFile(new URL("../functions/api/index.ts", import.meta.url), "utf8");
    const worker = await readFile(new URL("../functions/push-worker/index.ts", import.meta.url), "utf8");
    const pushMigration = await readFile(
        new URL("../migrations/20260812234500_push_delivery_pipeline.sql", import.meta.url),
        "utf8",
    );
    const pushSchedule = await readFile(new URL("../snippets/schedule_push_worker.sql", import.meta.url), "utf8");
    const authResolutionMigration = await readFile(
        new URL("../migrations/20260816100000_service_role_auth_resolution.sql", import.meta.url),
        "utf8",
    );

    assert.match(config, /\[functions\.api\][\s\S]*?verify_jwt\s*=\s*true/);
    assert.match(api, /database\.auth\.getUser\(/);
    assert.match(api, /wif_resolve_app_user/);
    assert.doesNotMatch(api, /\.from\("app_users"\)/);
    assert.match(api, /\/v1\/auth\/bootstrap/);
    assert.doesNotMatch(api, /\/v1\/auth\/debug/);
    assert.doesNotMatch(api, /WIF_ENABLE_DEBUG_AUTH/);
    assert.match(api, /encryptAPNSToken/);
    assert.match(api, /wif_register_push_device/);
    assert.doesNotMatch(api, /APNs token storage is not configured yet/);
    assert.match(api, /database\.auth\.admin\.deleteUser\(/);
    assert.match(api, /\.from\("deletion_requests"\)/);
    assert.doesNotMatch(api, /Account deletion requires Apple token revocation first/);

    assert.match(config, /\[functions\.push-worker\][\s\S]*?verify_jwt\s*=\s*false/);
    assert.match(worker, /PUSH_WORKER_SECRET/);
    assert.match(worker, /"apns-topic"/);
    assert.match(worker, /"apns-push-type": "alert"/);
    assert.match(worker, /decryptAPNSToken/);
    assert.match(pushMigration, /revoke all on function %s from public/i);
    assert.match(pushMigration, /for update skip locked/i);
    assert.match(pushSchedule, /vault\.decrypted_secrets/);
    assert.match(pushSchedule, /PUSH_WORKER_SECRET/);
    assert.doesNotMatch(pushSchedule, /sb_secret_/);
    assert.match(authResolutionMigration, /security definer/i);
    assert.match(authResolutionMigration, /grant execute[\s\S]*service_role/i);
    assert.doesNotMatch(authResolutionMigration, /grant select[\s\S]*app_users/i);
});

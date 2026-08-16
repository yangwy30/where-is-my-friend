import test from "node:test";
import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";

const aliceID = "10000000-0000-0000-0000-000000000001";
const bobID = "10000000-0000-0000-0000-000000000002";

async function scalar(database, sql, params = []) {
    const result = await database.query(sql, params);
    return Object.values(result.rows[0])[0];
}

async function migrate(database) {
    await database.exec(`
        create schema if not exists auth;
        create table if not exists auth.users (
            id uuid primary key,
            email text
        );
    `);
    const migrationsURL = new URL("../migrations/", import.meta.url);
    const migrationFiles = (await readdir(migrationsURL))
        .filter(file => file.endsWith(".sql"))
        .sort();
    for (const file of migrationFiles) {
        await database.exec(await readFile(new URL(file, migrationsURL), "utf8"));
    }
}

test("migration supports the complete two-user same-city vertical slice", async () => {
    const database = new PGlite();
    try {
        const seed = await readFile(new URL("../seed.sql", import.meta.url), "utf8");
        await migrate(database);
        await database.exec(seed);

        const initial = await scalar(
            database,
            "select public.wif_snapshot($1::uuid) as snapshot",
            [aliceID],
        );
        assert.equal(initial.isAuthenticated, true);
        assert.equal(initial.currentUser.username, "alice");
        assert.deepEqual(initial.friends, []);

        await scalar(
            database,
            "select public.wif_send_friend_request($1::uuid, $2::text)",
            [aliceID, "@Bob"],
        );
        const bobWithRequest = await scalar(
            database,
            "select public.wif_snapshot($1::uuid)",
            [bobID],
        );
        assert.equal(bobWithRequest.friendRequests.length, 1);
        assert.equal(bobWithRequest.friendRequests[0].direction, "incoming");

        await scalar(
            database,
            "select public.wif_respond_friend_request($1::uuid, $2::uuid, 'accept')",
            [bobID, bobWithRequest.friendRequests[0].id],
        );
        const accepted = await scalar(database, "select public.wif_snapshot($1::uuid)", [aliceID]);
        assert.equal(accepted.friends.length, 1);
        assert.equal(accepted.friends[0].username, "bob");

        const timestamp = new Date().toISOString();
        await scalar(
            database,
            "select public.wif_update_presence($1::uuid, 'New York', 'US', 'manual', $2::timestamptz)",
            [aliceID, timestamp],
        );
        await scalar(
            database,
            "select public.wif_update_presence($1::uuid, 'New York', 'US', 'manual', $2::timestamptz)",
            [bobID, timestamp],
        );

        assert.equal(await scalar(database, "select count(*)::int from public.colocation_events"), 2);
        assert.equal(await scalar(database, "select count(*)::int from public.notification_outbox"), 2);
        assert.equal(
            await scalar(database, "select count(*)::int from public.colocation_sessions where left_at is null"),
            2,
        );

        await scalar(
            database,
            "select public.wif_update_presence($1::uuid, 'New York', 'US', 'manual', $2::timestamptz)",
            [aliceID, timestamp],
        );
        assert.equal(await scalar(database, "select count(*)::int from public.colocation_events"), 2);

        await scalar(
            database,
            "select public.wif_set_sharing_preferences($1::uuid, false, false, true)",
            [aliceID],
        );
        assert.equal(
            await scalar(database, "select count(*)::int from public.colocation_sessions where left_at is null"),
            0,
        );
    } finally {
        await database.close();
    }
});

test("Supabase Auth bootstrap creates one stable app profile", async () => {
    const database = new PGlite();
    const authUserID = "20000000-0000-0000-0000-000000000001";
    try {
        await migrate(database);
        await database.query("insert into auth.users(id, email) values ($1::uuid, $2)", [
            authUserID,
            "friend@example.com",
        ]);

        assert.equal(
            await scalar(database, "select public.wif_resolve_app_user($1::uuid)", [authUserID]),
            null,
        );

        const firstID = await scalar(
            database,
            "select public.wif_ensure_app_user($1::uuid, $2::text)",
            [authUserID, "Taylor Friend"],
        );
        const secondID = await scalar(
            database,
            "select public.wif_ensure_app_user($1::uuid, null::text)",
            [authUserID],
        );

        assert.equal(secondID, firstID);
        assert.equal(
            await scalar(database, "select public.wif_resolve_app_user($1::uuid)", [authUserID]),
            firstID,
        );
        assert.equal(
            await scalar(database, "select count(*)::int from public.app_users where auth_user_id = $1", [authUserID]),
            1,
        );
        assert.equal(
            await scalar(database, "select display_name from public.app_users where id = $1", [firstID]),
            "Taylor Friend",
        );
        assert.equal(
            await scalar(database, "select count(*)::int from public.user_sharing_settings where user_id = $1", [firstID]),
            1,
        );
    } finally {
        await database.close();
    }
});

test("deleting a Supabase Auth user cascades account data without breaking an in-flight deletion request", async () => {
    const database = new PGlite();
    const authUserID = "20000000-0000-0000-0000-000000000002";
    try {
        await migrate(database);
        await database.query("insert into auth.users(id, email) values ($1::uuid, $2)", [
            authUserID,
            "delete-me@example.com",
        ]);
        const userID = await scalar(
            database,
            "select public.wif_ensure_app_user($1::uuid, 'Delete Me')",
            [authUserID],
        );
        await database.query(
            "insert into public.deletion_requests(user_id) values ($1::uuid)",
            [userID],
        );

        await database.query("delete from auth.users where id = $1::uuid", [authUserID]);

        assert.equal(await scalar(database, "select count(*)::int from public.app_users where id = $1", [userID]), 0);
        assert.equal(await scalar(database, "select count(*)::int from public.user_sharing_settings where user_id = $1", [userID]), 0);
        assert.equal(await scalar(database, "select count(*)::int from public.deletion_requests where user_id = $1", [userID]), 1);
    } finally {
        await database.close();
    }
});

test("push registration is idempotent per installation and transfers ownership safely", async () => {
    const database = new PGlite();
    const installationID = "30000000-0000-0000-0000-000000000001";
    const replacementInstallationID = "30000000-0000-0000-0000-000000000002";
    try {
        await migrate(database);
        await database.exec(await readFile(new URL("../seed.sql", import.meta.url), "utf8"));

        const firstID = await scalar(database, `
            select public.wif_register_push_device(
                $1::uuid, $2::uuid, $3::text, $4::text,
                'sandbox', 'com.yangwy30.whereismyfriend.staging', 'whereismyfriend-staging'
            )
        `, [aliceID, installationID, "a".repeat(64), "v1:nonce:ciphertext"]);
        const secondID = await scalar(database, `
            select public.wif_register_push_device(
                $1::uuid, $2::uuid, $3::text, $4::text,
                'sandbox', 'com.yangwy30.whereismyfriend.staging', 'whereismyfriend-staging'
            )
        `, [aliceID, installationID, "b".repeat(64), "v1:newnonce:newciphertext"]);
        assert.equal(secondID, firstID);
        assert.equal(await scalar(database, "select count(*)::int from public.devices"), 1);

        await scalar(database, `
            select public.wif_register_push_device(
                $1::uuid, $2::uuid, $3::text, $4::text,
                'sandbox', 'com.yangwy30.whereismyfriend.staging', 'whereismyfriend-staging'
            )
        `, [bobID, installationID, "c".repeat(64), "v1:bobnonce:bobciphertext"]);
        assert.equal(await scalar(database, "select user_id from public.devices"), bobID);
        assert.equal(await scalar(database, "select count(*)::int from public.devices"), 1);
        assert.equal(
            await scalar(database, "select public.wif_disable_push_device($1::uuid, $2::uuid, 'sandbox')", [aliceID, installationID]),
            false,
        );
        assert.equal(
            await scalar(database, "select public.wif_disable_push_device($1::uuid, $2::uuid, 'sandbox')", [bobID, installationID]),
            true,
        );

        await scalar(database, `
            select public.wif_register_push_device(
                $1::uuid, $2::uuid, $3::text, $4::text,
                'sandbox', 'com.yangwy30.whereismyfriend.staging', 'whereismyfriend-staging'
            )
        `, [bobID, replacementInstallationID, "c".repeat(64), "v1:movednonce:movedciphertext"]);
        assert.equal(await scalar(database, "select count(*)::int from public.devices"), 1);
        assert.equal(await scalar(database, "select installation_id from public.devices"), replacementInstallationID);
    } finally {
        await database.close();
    }
});

test("notification deliveries are claimed once and completed per device", async () => {
    const database = new PGlite();
    const claimToken = "40000000-0000-0000-0000-000000000001";
    try {
        await migrate(database);
        await database.exec(await readFile(new URL("../seed.sql", import.meta.url), "utf8"));

        for (const [userID, installationID, tokenCharacter] of [
            [aliceID, "30000000-0000-0000-0000-000000000011", "d"],
            [bobID, "30000000-0000-0000-0000-000000000012", "e"],
        ]) {
            await scalar(database, `
                select public.wif_register_push_device(
                    $1::uuid, $2::uuid, $3::text, $4::text,
                    'sandbox', 'com.yangwy30.whereismyfriend.staging', 'whereismyfriend-staging'
                )
            `, [userID, installationID, tokenCharacter.repeat(64), `v1:${tokenCharacter}nonce:${tokenCharacter}ciphertext`]);
        }

        await scalar(database, "select public.wif_send_friend_request($1::uuid, '@bob')", [aliceID]);
        const requestID = await scalar(database, "select id from public.friendships where status = 'pending'");
        await scalar(database, "select public.wif_respond_friend_request($1::uuid, $2::uuid, 'accept')", [bobID, requestID]);
        const timestamp = new Date().toISOString();
        await scalar(database, "select public.wif_update_presence($1::uuid, 'New York', 'US', 'manual', $2::timestamptz)", [aliceID, timestamp]);
        await scalar(database, "select public.wif_update_presence($1::uuid, 'New York', 'US', 'manual', $2::timestamptz)", [bobID, timestamp]);

        const claimed = await database.query(
            "select * from public.wif_claim_notification_deliveries(20, $1::uuid)",
            [claimToken],
        );
        assert.equal(claimed.rows.length, 2);
        assert.equal(claimed.rows.every(row => row.title.includes("New York")), true);
        assert.equal(claimed.rows.every(row => row.deep_link.startsWith("whereismyfriend-staging://events/")), true);
        assert.equal(
            (await database.query("select * from public.wif_claim_notification_deliveries(20, $1::uuid)", [claimToken])).rows.length,
            0,
        );

        await scalar(database, `
            select public.wif_complete_notification_delivery(
                $1::uuid, $2::uuid, 'delivered', null::text, null::uuid, null::integer, false
            )
        `, [claimed.rows[0].delivery_id, claimToken]);
        await scalar(database, `
            select public.wif_complete_notification_delivery(
                $1::uuid, $2::uuid, 'failed', 'APNs 410: Unregistered', null::uuid, null::integer, true
            )
        `, [claimed.rows[1].delivery_id, claimToken]);

        assert.equal(await scalar(database, "select count(*)::int from public.notification_outbox where delivered_at is not null"), 2);
        assert.equal(await scalar(database, "select count(*)::int from public.colocation_events where delivered_at is not null"), 1);
        assert.equal(await scalar(database, "select count(*)::int from public.devices where disabled_at is not null"), 1);
    } finally {
        await database.close();
    }
});

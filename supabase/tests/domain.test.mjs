import test from "node:test";
import assert from "node:assert/strict";
import { isFresh, isUUID, normalizeAPIPath, normalizeDebugUsername } from "../functions/_shared/domain.mjs";

test("API route normalization preserves the v1 contract behind an Edge Function prefix", () => {
    assert.equal(
        normalizeAPIPath("http://127.0.0.1:54321/functions/v1/api/v1/friends/requests"),
        "/v1/friends/requests",
    );
    assert.equal(normalizeAPIPath("/v1/bootstrap/"), "/v1/bootstrap");
    assert.equal(normalizeAPIPath("/health"), "/");
});

test("debug usernames are normalized and strictly validated", () => {
    assert.equal(normalizeDebugUsername(" @Alice "), "alice");
    assert.equal(normalizeDebugUsername("bad-name"), null);
    assert.equal(normalizeDebugUsername("ab"), null);
});

test("identifiers and location freshness reject malformed or future input", () => {
    assert.equal(isUUID("10000000-0000-0000-0000-000000000001"), true);
    assert.equal(isUUID("not-a-uuid"), false);
    const now = Date.parse("2026-08-12T12:00:00Z");
    assert.equal(isFresh("2026-08-12T11:00:00Z", now), true);
    assert.equal(isFresh("2026-08-12T09:00:00Z", now), false);
    assert.equal(isFresh("2026-08-12T13:00:00Z", now), false);
});

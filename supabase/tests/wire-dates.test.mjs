import test from "node:test";
import assert from "node:assert/strict";
import { wholeSecondTimestamps } from "../functions/_shared/wire-dates.mjs";

test("responses send timestamps in whole seconds so iOS 18 can decode them", () => {
    const body = JSON.parse(JSON.stringify({
        lastSyncedAt: "2026-10-16T23:34:29.852301+00:00",
        generatedAt: "2026-10-16T23:34:29.852Z",
        currentPresence: { updatedAt: "2026-10-16T23:34:29.5-07:00", city: "Milpitas" },
        friends: [{ updatedAt: "2026-10-16T23:34:29+00:00" }],
    }, wholeSecondTimestamps));
    assert.deepEqual(body, {
        lastSyncedAt: "2026-10-16T23:34:29+00:00",
        generatedAt: "2026-10-16T23:34:29Z",
        currentPresence: { updatedAt: "2026-10-16T23:34:29-07:00", city: "Milpitas" },
        friends: [{ updatedAt: "2026-10-16T23:34:29+00:00" }],
    });
});

test("only whole timestamp strings change", () => {
    for (const value of ["2026-10-16", "Flight 12:30:45.5 delayed", "v1.0.8", "2026-10-16T23:34:29.852Z and more", '{"startDay":"2026-10-16"}']) {
        assert.equal(wholeSecondTimestamps("k", value), value);
    }
    assert.equal(wholeSecondTimestamps("k", 3.5), 3.5);
    assert.equal(wholeSecondTimestamps("k", null), null);
});

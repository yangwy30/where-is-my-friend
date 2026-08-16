import test from "node:test";
import assert from "node:assert/strict";
import {
    classifyAPNsResponse,
    decryptAPNSToken,
    encryptAPNSToken,
    hashAPNSToken,
    normalizeAPNSToken,
} from "../functions/_shared/push-security.mjs";

const token = "a1".repeat(32);
const encryptionKey = Buffer.alloc(32, 7).toString("base64");

test("APNs token helpers validate, hash, and encrypt without deterministic ciphertext", async () => {
    assert.equal(normalizeAPNSToken(token.toUpperCase()), token);
    assert.equal(normalizeAPNSToken("A1B2"), "a1b2");
    assert.throws(() => normalizeAPNSToken("not-a-device-token"));
    assert.throws(() => normalizeAPNSToken("abc"));

    const hash = await hashAPNSToken(token);
    assert.match(hash, /^[0-9a-f]{64}$/);
    assert.notEqual(hash, token);

    const first = await encryptAPNSToken(token, encryptionKey);
    const second = await encryptAPNSToken(token, encryptionKey);
    assert.match(first, /^v1:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$/);
    assert.notEqual(first, second);
    assert.equal(first.includes(token), false);
    assert.equal(await decryptAPNSToken(first, encryptionKey), token);
    await assert.rejects(() => decryptAPNSToken(first, Buffer.alloc(32, 8).toString("base64")));
});

test("APNs response policy disables only invalid devices and backs off transient failures", () => {
    assert.deepEqual(classifyAPNsResponse(200), {
        outcome: "delivered", disableDevice: false, retryAfterSeconds: null,
    });
    assert.deepEqual(classifyAPNsResponse(410, "Unregistered"), {
        outcome: "failed", disableDevice: true, retryAfterSeconds: null,
    });
    assert.deepEqual(classifyAPNsResponse(400, "BadDeviceToken"), {
        outcome: "failed", disableDevice: true, retryAfterSeconds: null,
    });
    assert.deepEqual(classifyAPNsResponse(429, "TooManyRequests"), {
        outcome: "retry", disableDevice: false, retryAfterSeconds: 60,
    });
    assert.deepEqual(classifyAPNsResponse(503, "ServiceUnavailable"), {
        outcome: "retry", disableDevice: false, retryAfterSeconds: 900,
    });
    assert.deepEqual(classifyAPNsResponse(400, "BadTopic"), {
        outcome: "failed", disableDevice: false, retryAfterSeconds: null,
    });
});

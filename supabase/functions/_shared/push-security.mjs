// APNs tokens are opaque and Apple does not guarantee a fixed byte length.
// Keep a defensive upper bound while accepting any non-empty byte sequence.
const TOKEN_PATTERN = /^(?:[0-9a-f]{2}){1,200}$/;
const ENVELOPE_PATTERN = /^v1:([A-Za-z0-9_-]+):([A-Za-z0-9_-]+)$/;

export function normalizeAPNSToken(value) {
    if (typeof value !== "string") throw new TypeError("The APNs token must be a string.");
    const token = value.trim().toLowerCase();
    if (!TOKEN_PATTERN.test(token)) {
        throw new TypeError("The APNs token must contain an even number of hexadecimal characters.");
    }
    return token;
}

function encodeBase64URL(bytes) {
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/u, "");
}

function decodeBase64URL(value) {
    const standard = value.replaceAll("-", "+").replaceAll("_", "/");
    const padded = standard.padEnd(Math.ceil(standard.length / 4) * 4, "=");
    const binary = atob(padded);
    return Uint8Array.from(binary, character => character.charCodeAt(0));
}

function encryptionKeyBytes(encodedKey) {
    if (typeof encodedKey !== "string" || encodedKey.trim() === "") {
        throw new TypeError("The APNs device-token encryption key is missing.");
    }
    const bytes = decodeBase64URL(encodedKey.trim());
    if (bytes.byteLength !== 32) throw new TypeError("The APNs device-token encryption key must be 32 bytes.");
    return bytes;
}

export async function hashAPNSToken(token, cryptoAPI = globalThis.crypto) {
    const normalized = normalizeAPNSToken(token);
    const digest = new Uint8Array(await cryptoAPI.subtle.digest("SHA-256", new TextEncoder().encode(normalized)));
    return Array.from(digest, byte => byte.toString(16).padStart(2, "0")).join("");
}

export async function encryptAPNSToken(token, encodedKey, cryptoAPI = globalThis.crypto) {
    const normalized = normalizeAPNSToken(token);
    const nonce = cryptoAPI.getRandomValues(new Uint8Array(12));
    const key = await cryptoAPI.subtle.importKey(
        "raw",
        encryptionKeyBytes(encodedKey),
        { name: "AES-GCM" },
        false,
        ["encrypt"],
    );
    const ciphertext = new Uint8Array(await cryptoAPI.subtle.encrypt(
        { name: "AES-GCM", iv: nonce },
        key,
        new TextEncoder().encode(normalized),
    ));
    return `v1:${encodeBase64URL(nonce)}:${encodeBase64URL(ciphertext)}`;
}

export async function decryptAPNSToken(envelope, encodedKey, cryptoAPI = globalThis.crypto) {
    const match = typeof envelope === "string" ? ENVELOPE_PATTERN.exec(envelope) : null;
    if (!match) throw new TypeError("The encrypted APNs token envelope is invalid.");
    const key = await cryptoAPI.subtle.importKey(
        "raw",
        encryptionKeyBytes(encodedKey),
        { name: "AES-GCM" },
        false,
        ["decrypt"],
    );
    const plaintext = await cryptoAPI.subtle.decrypt(
        { name: "AES-GCM", iv: decodeBase64URL(match[1]) },
        key,
        decodeBase64URL(match[2]),
    );
    return normalizeAPNSToken(new TextDecoder().decode(plaintext));
}

const invalidDeviceReasons = new Set([
    "BadDeviceToken",
    "DeviceTokenNotForTopic",
    "ExpiredToken",
    "Unregistered",
]);

export function classifyAPNsResponse(status, reason = "") {
    if (status === 200) return { outcome: "delivered", disableDevice: false, retryAfterSeconds: null };
    if (status === 410 || invalidDeviceReasons.has(reason)) {
        return { outcome: "failed", disableDevice: true, retryAfterSeconds: null };
    }
    if (status === 429) return { outcome: "retry", disableDevice: false, retryAfterSeconds: 60 };
    if (status === 403 || status >= 500) {
        return { outcome: "retry", disableDevice: false, retryAfterSeconds: 900 };
    }
    return { outcome: "failed", disableDevice: false, retryAfterSeconds: null };
}

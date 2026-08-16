const usernamePattern = /^[a-z0-9_]{3,20}$/;

export function normalizeAPIPath(input) {
    const pathname = input.includes("://") ? new URL(input).pathname : input;
    const markerIndex = pathname.lastIndexOf("/v1");
    if (markerIndex < 0) return "/";
    const route = pathname.slice(markerIndex).replace(/\/+$/, "");
    return route || "/";
}

export function normalizeDebugUsername(value) {
    if (typeof value !== "string") return null;
    const username = value.trim().replace(/^@+/, "").toLowerCase();
    return usernamePattern.test(username) ? username : null;
}

export function isUUID(value) {
    return typeof value === "string"
        && /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value);
}

export function isFresh(isoDate, now = Date.now(), maxAgeMilliseconds = 2 * 60 * 60 * 1000) {
    const timestamp = Date.parse(isoDate);
    return Number.isFinite(timestamp)
        && timestamp <= now + 5 * 60 * 1000
        && timestamp >= now - maxAgeMilliseconds;
}
